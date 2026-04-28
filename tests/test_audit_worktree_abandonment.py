from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "audit-worktree-abandonment.py"
spec = importlib.util.spec_from_file_location("audit_worktrees", SCRIPT)
audit = importlib.util.module_from_spec(spec)
assert spec and spec.loader
sys.modules[spec.name] = audit
spec.loader.exec_module(audit)


def record(handle: str, branch: str = "codex/xc-demo", head: str = "abc") -> audit.WorktreeRecord:
    return audit.WorktreeRecord(
        path=Path("/repo/.worktrees") / handle,
        head=head,
        branch=f"refs/heads/{branch}",
    )


def facts(
    handle: str,
    *,
    dirty: bool = False,
    age_days: int | None = 30,
    remote_exists: bool | None = True,
    merged: bool | None = False,
    bead_status: str | None = None,
    submodules: dict[str, str] | None = None,
) -> audit.WorktreeFacts:
    return audit.WorktreeFacts(
        record=record(handle),
        dirty=dirty,
        age_days=age_days,
        remote_exists=remote_exists,
        merged_to_origin_main=merged,
        bead_id="xc-demo",
        bead_status=bead_status,
        submodule_layout=submodules or {"xenon": "worktree submodule"},
    )


class WorktreeAbandonmentAuditTests(unittest.TestCase):
    def test_parse_git_worktree_porcelain_multiple_entries(self):
        output = """worktree /repo
HEAD abc
branch refs/heads/main

worktree /repo/.worktrees/worker-codex-1-xc-demo
HEAD def
branch refs/heads/codex/xc-demo

"""
        records = audit.parse_worktree_porcelain(output)
        self.assertEqual([item.handle for item in records], ["repo", "worker-codex-1-xc-demo"])
        self.assertEqual(records[1].branch, "refs/heads/codex/xc-demo")

    def test_live_tmx_handle_is_active_even_when_other_signals_are_stale(self):
        item = facts("worker-codex-1-xc-demo", bead_status="closed")
        runtime = audit.RuntimeSignals(live_handles=frozenset({"worker-codex-1-xc-demo"}))
        classification = audit.classify_worktree(item, runtime)
        self.assertEqual(classification.state, "active")
        self.assertIn("live tmux/workmux handle", classification.reasons)
        self.assertFalse(classification.confirmation_required)

    def test_reserved_swarm_lane_is_active_without_live_window(self):
        item = facts("worker-codex-1", age_days=60, remote_exists=False)
        classification = audit.classify_worktree(item, audit.RuntimeSignals())
        self.assertEqual(classification.state, "active")
        self.assertIn("reserved swarm lane handle", classification.reasons)

    def test_clean_legacy_per_bead_tree_is_abandoned_but_requires_confirmation(self):
        item = facts(
            "worker-codex-1-xc-demo",
            bead_status="closed",
            submodules={"xenon": "missing .git marker"},
        )
        classification = audit.classify_worktree(item, audit.RuntimeSignals())
        self.assertEqual(classification.state, "abandoned")
        self.assertTrue(classification.confirmation_required)
        self.assertIn("legacy per-bead worker handle", classification.reasons)
        self.assertIn("non-standard submodule layout", classification.reasons)

    def test_dirty_legacy_tree_is_unsure_not_abandoned(self):
        item = facts("worker-codex-1-xc-demo", dirty=True, bead_status="closed")
        classification = audit.classify_worktree(item, audit.RuntimeSignals())
        self.assertEqual(classification.state, "unsure")
        self.assertIn("has uncommitted changes", classification.reasons)

    def test_stale_missing_remote_non_legacy_tree_is_abandoned(self):
        item = facts("one-off-old-tree", remote_exists=False, age_days=45)
        classification = audit.classify_worktree(item, audit.RuntimeSignals())
        self.assertEqual(classification.state, "abandoned")
        self.assertIn("remote branch missing", classification.reasons)

    def test_clean_one_off_tree_without_decisive_signal_is_unsure(self):
        item = facts("landing-xc-fkr2-1777379574", remote_exists=True, age_days=1)
        classification = audit.classify_worktree(item, audit.RuntimeSignals())
        self.assertEqual(classification.state, "unsure")
        self.assertIn("no decisive abandonment rule matched", classification.reasons)


if __name__ == "__main__":
    unittest.main()
