import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
HELPER = ROOT / ".claude" / "skills" / "manage-swarm" / "scripts" / "landing_blocker.sh"


FAKE_BD = r"""#!/usr/bin/env python3
import fcntl
import json
import os
import sys
from pathlib import Path

store_path = Path(os.environ["FAKE_BD_STORE"])
lock_path = store_path.with_suffix(store_path.suffix + ".lock")


# Each fake-bd invocation holds an exclusive lock on the store for its
# lifetime. Two concurrent invocations therefore serialize on this lock —
# i.e. each `bd list`/`bd create`/`bd close` is atomic. This mirrors the
# real bd backend, which serializes individual operations but not the
# lookup→create window the helper guards against with race-recheck.
lock_fh = open(lock_path, "a+")
fcntl.flock(lock_fh, fcntl.LOCK_EX)


def load():
    if store_path.exists():
        return json.loads(store_path.read_text())
    return []


def save(items):
    store_path.write_text(json.dumps(items, sort_keys=True))


args = sys.argv[1:]
items = load()

def maybe_inject_after_list():
    inject_path = os.environ.get("FAKE_BD_INJECT_AFTER_LIST")
    if not inject_path:
        return
    p = Path(inject_path)
    if not p.exists():
        return
    extra = json.loads(p.read_text())
    fresh = load() + extra
    save(fresh)
    p.unlink()


if args[:1] == ["list"]:
    print(json.dumps(items))
    maybe_inject_after_list()
    raise SystemExit(0)

if args[:1] == ["create"]:
    title = None
    if len(args) > 1 and not args[1].startswith("--"):
        title = args[1]
        rest = args[2:]
    else:
        rest = args[1:]
    rec = {
        "id": f"xc-new-{len(items) + 1}",
        "title": title,
        "description": "",
        "status": "open",
        "priority": 1,
        "issue_type": "bug",
        "created_at": f"2026-04-27T00:00:{len(items):02d}Z",
        "labels": [],
        "comments": [],
    }
    i = 0
    while i < len(rest):
        arg = rest[i]
        if arg == "--description":
            rec["description"] = rest[i + 1]
            i += 2
        elif arg == "--external-ref":
            rec["external_ref"] = rest[i + 1]
            i += 2
        elif arg == "--labels":
            rec["labels"] = [x for x in rest[i + 1].split(",") if x]
            i += 2
        elif arg == "--metadata":
            rec["metadata"] = json.loads(rest[i + 1])
            i += 2
        elif arg == "--priority":
            rec["priority"] = int(rest[i + 1])
            i += 2
        elif arg in {"--type", "--json"}:
            i += 2 if arg == "--type" else 1
        else:
            i += 1
    items.append(rec)
    save(items)
    print(json.dumps(rec))
    raise SystemExit(0)

if args[:2] == ["comments", "add"]:
    bead_id = args[2]
    text = args[3]
    for item in items:
        if item["id"] == bead_id:
            item.setdefault("comments", []).append({"text": text})
            save(items)
            print("ok")
            raise SystemExit(0)
    print(f"unknown bead {bead_id}", file=sys.stderr)
    raise SystemExit(1)

if args[:1] == ["close"]:
    rest = args[1:]
    bead_ids = []
    reason = None
    i = 0
    while i < len(rest):
        if rest[i] in ("-r", "--reason"):
            reason = rest[i + 1]
            i += 2
        elif rest[i].startswith("--"):
            i += 2
        else:
            bead_ids.append(rest[i])
            i += 1
    for bead_id in bead_ids:
        for item in items:
            if item["id"] == bead_id:
                item["status"] = "closed"
                if reason:
                    item.setdefault("close_reason", reason)
    save(items)
    print("ok")
    raise SystemExit(0)

print(f"unexpected bd args: {args}", file=sys.stderr)
raise SystemExit(1)
"""


class LandingBlockerHelperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.tmp_path = Path(self.tmp.name)
        self.store = self.tmp_path / "beads.json"
        self.store.write_text("[]")
        fake_bin = self.tmp_path / "bin"
        fake_bin.mkdir()
        bd = fake_bin / "bd"
        bd.write_text(FAKE_BD)
        bd.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{fake_bin}:{os.environ['PATH']}",
            "FAKE_BD_STORE": str(self.store),
        }

    def tearDown(self):
        self.tmp.cleanup()

    def seed(self, records):
        self.store.write_text(json.dumps(records, sort_keys=True))

    def records(self):
        return json.loads(self.store.read_text())

    def file_blocker(
        self,
        repo="xenota-collective/xenota",
        pr="229",
        producer="producer-a",
        source="source-a",
        reason="conflict",
        observed_at="2026-04-27T01:00:00Z",
    ):
        cmd = [
            str(HELPER),
            "file",
            "--repo",
            repo,
            "--pr",
            str(pr),
            "--branch",
            "feature-branch",
            "--producer",
            producer,
            "--signal-source",
            source,
            "--reason",
            reason,
            "--observed-at",
            observed_at,
        ]
        completed = subprocess.run(
            cmd, env=self.env, text=True, capture_output=True, check=True
        )
        return json.loads(completed.stdout)

    def test_simultaneous_producers_share_one_blocker(self):
        first = self.file_blocker(
            producer="landing_poll", source="gh_pr_merge_rebase_conflict"
        )
        second = self.file_blocker(producer="landing_patrol", source="mergeStateStatus=DIRTY")

        self.assertEqual(first["action"], "created")
        self.assertEqual(second["action"], "deduplicated")
        self.assertEqual(first["bead_id"], second["bead_id"])
        records = self.records()
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["labels"], ["landing-dirty", "landing-blocker"])
        comments = "\n".join(c["text"] for c in records[0]["comments"])
        self.assertIn("producer: landing_poll", comments)
        self.assertIn("producer: landing_patrol", comments)
        # Audit-trail labels must reflect helper action; regression for
        # bash positional-argument parsing where action="$10" becomes
        # ${1}0 instead of the 10th positional arg.
        self.assertIn("Landing-blocker evidence (created):", comments)
        self.assertIn("Landing-blocker evidence (deduplicated):", comments)

    def test_delayed_second_producer_appends_evidence(self):
        first = self.file_blocker(producer="producer-a", observed_at="2026-04-27T01:00:00Z")
        second = self.file_blocker(
            producer="producer-b",
            source="one-hour-later",
            observed_at="2026-04-27T02:00:00Z",
        )

        self.assertEqual(first["bead_id"], second["bead_id"])
        self.assertEqual(second["action"], "deduplicated")
        comments = "\n".join(c["text"] for c in self.records()[0]["comments"])
        self.assertIn("observed_at: 2026-04-27T02:00:00Z", comments)
        self.assertIn("signal_source: one-hour-later", comments)

    def test_closed_obsolete_then_newly_dirty_creates_new_blocker(self):
        self.seed(
            [
                {
                    "id": "xc-old",
                    "title": "Resolve dirty landing PR xenota#229",
                    "status": "closed",
                    "created_at": "2026-04-26T00:00:00Z",
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-dirty"],
                    "comments": [],
                }
            ]
        )

        result = self.file_blocker(producer="producer-b")

        self.assertEqual(result["action"], "created")
        self.assertNotEqual(result["bead_id"], "xc-old")
        self.assertEqual(len(self.records()), 2)

    def test_xenota_229_fixture_dedupes_across_historical_labels(self):
        self.seed(
            [
                {
                    "id": "xc-wh3i",
                    "title": "Resolve dirty landing PR xenota-collective/xenota#229",
                    "status": "in_progress",
                    "created_at": "2026-04-26T11:05:55Z",
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-dirty"],
                    "comments": [],
                },
                {
                    "id": "xc-td8i",
                    "title": "Landing blocker: xenota PR #229 merge conflicts",
                    "status": "closed",
                    "created_at": "2026-04-26T18:28:27Z",
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-blocker"],
                    "comments": [],
                },
            ]
        )

        result = self.file_blocker(producer="landing-blocker-producer", source="producer-b")

        self.assertEqual(result["action"], "deduplicated")
        self.assertEqual(result["bead_id"], "xc-wh3i")
        records = self.records()
        self.assertEqual(len(records), 2)
        self.assertEqual(len(records[0]["comments"]), 1)
        self.assertIn("producer: landing-blocker-producer", records[0]["comments"][0]["text"])

    def test_non_blocker_bead_with_same_external_ref_is_ignored(self):
        # Non-blocker beads (feature beads, audit beads, etc.) often carry the
        # PR external_ref. They MUST NOT be treated as existing landing
        # blockers — otherwise filing a real blocker silently mutates an
        # unrelated bead and the dirty PR has no canonical blocker record.
        self.seed(
            [
                {
                    "id": "xc-feature",
                    "title": "Constrain tracked worker-state metadata in xenota pointer PRs",
                    "status": "in_progress",
                    "created_at": "2026-04-25T00:00:00Z",
                    "external_ref": "gh:xenota-collective/xenota#216",
                    "labels": ["landing", "pointer-pr", "retro", "worker-state"],
                    "comments": [],
                }
            ]
        )

        result = self.file_blocker(repo="xenota-collective/xenota", pr="216")

        self.assertEqual(result["action"], "created")
        self.assertNotEqual(result["bead_id"], "xc-feature")
        records = self.records()
        # The original feature bead is untouched; a fresh blocker bead exists.
        feature = next(r for r in records if r["id"] == "xc-feature")
        self.assertEqual(feature["comments"], [])
        self.assertEqual(feature["status"], "in_progress")
        new = next(r for r in records if r["id"] != "xc-feature")
        self.assertIn("landing-dirty", new["labels"])

    def test_concurrent_producers_converge_on_one_open_blocker(self):
        # Two helper invocations launched concurrently. Whether or not the
        # lookup→create window actually races on this run, only one open
        # blocker bead must remain afterwards and both helpers must report
        # the same final winner.
        cmds = [
            (
                str(HELPER),
                "file",
                "--repo",
                "xenota-collective/xenota",
                "--pr",
                "229",
                "--branch",
                "feature-branch",
                "--producer",
                f"producer-{i}",
                "--signal-source",
                f"source-{i}",
                "--reason",
                "concurrent",
                "--observed-at",
                f"2026-04-27T01:00:0{i}Z",
            )
            for i in range(2)
        ]
        procs = [
            subprocess.Popen(cmd, env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            for cmd in cmds
        ]
        outputs = []
        for p in procs:
            stdout, stderr = p.communicate(timeout=20)
            self.assertEqual(p.returncode, 0, msg=f"helper failed: {stderr}")
            outputs.append(json.loads(stdout))

        winner_ids = {o["bead_id"] for o in outputs}
        self.assertEqual(len(winner_ids), 1, msg=f"helpers disagreed on winner: {outputs}")
        records = self.records()
        open_records = [r for r in records if r.get("status") != "closed"]
        self.assertEqual(len(open_records), 1, msg=f"expected one open bead, got: {records}")
        self.assertEqual(open_records[0]["id"], next(iter(winner_ids)))

    def test_race_recheck_closes_loser_when_competing_bead_appears(self):
        # Inject a competing landing-blocker bead between the helper's
        # initial lookup and bd create. The helper's race-recheck must find
        # that competing bead as winner (older created_at wins) and close
        # the bead it just created as a duplicate.
        injected_id = "xc-race-winner"
        inject_path = self.tmp_path / "inject.json"
        inject_path.write_text(
            json.dumps(
                [
                    {
                        "id": injected_id,
                        "title": "Resolve dirty landing PR xenota#229",
                        "status": "open",
                        "created_at": "2026-04-26T00:00:00Z",
                        "external_ref": "gh:xenota-collective/xenota#229",
                        "labels": ["landing-dirty"],
                        "comments": [],
                    }
                ]
            )
        )
        env = {**self.env, "FAKE_BD_INJECT_AFTER_LIST": str(inject_path)}
        cmd = [
            str(HELPER),
            "file",
            "--repo",
            "xenota-collective/xenota",
            "--pr",
            "229",
            "--branch",
            "feature-branch",
            "--producer",
            "loser-producer",
            "--signal-source",
            "loser-signal",
            "--reason",
            "race",
            "--observed-at",
            "2026-04-27T01:00:00Z",
        ]
        completed = subprocess.run(cmd, env=env, text=True, capture_output=True, check=True)
        result = json.loads(completed.stdout)

        self.assertEqual(result["action"], "deduplicated")
        self.assertEqual(result["bead_id"], injected_id)
        records = self.records()
        open_records = [r for r in records if r["status"] != "closed"]
        self.assertEqual(len(open_records), 1)
        self.assertEqual(open_records[0]["id"], injected_id)
        # The loser bead was closed with a duplicate-of-winner reason.
        losers = [r for r in records if r["id"] != injected_id]
        self.assertEqual(len(losers), 1)
        self.assertEqual(losers[0]["status"], "closed")
        self.assertIn("duplicate of " + injected_id, losers[0].get("close_reason", ""))


    def test_same_created_at_winner_is_deterministic_by_id(self):
        # Regression for race-ordering: when two open blockers share the same
        # created_at the winner must be deterministic on ID, not on bd list
        # input order. Seeded in reverse-id order — sort_by(created_at, id)
        # must still pick xc-aaaa as winner.
        same_ts = "2026-04-26T10:00:00Z"
        self.seed(
            [
                {
                    "id": "xc-zzzz",
                    "title": "Resolve dirty landing PR xenota#229",
                    "status": "open",
                    "created_at": same_ts,
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-dirty"],
                    "comments": [],
                },
                {
                    "id": "xc-aaaa",
                    "title": "Landing blocker: xenota PR #229",
                    "status": "open",
                    "created_at": same_ts,
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-blocker"],
                    "comments": [],
                },
            ]
        )

        result = self.file_blocker(producer="producer-c")

        self.assertEqual(result["action"], "deduplicated")
        self.assertEqual(result["bead_id"], "xc-aaaa")
        records = self.records()
        winner = next(r for r in records if r["id"] == "xc-aaaa")
        loser = next(r for r in records if r["id"] == "xc-zzzz")
        self.assertEqual(winner["status"], "open")
        self.assertEqual(loser["status"], "closed")
        self.assertIn("duplicate of xc-aaaa", loser.get("close_reason", ""))

    def test_stale_open_duplicates_get_reconciled_on_next_file(self):
        # Regression for missing post-create cleanup: a prior race left two
        # open blockers (e.g. bd close failed after bd create succeeded). The
        # next helper invocation must reconcile — close the non-winner — so
        # the invariant "at most one open blocker per ref" is restored.
        self.seed(
            [
                {
                    "id": "xc-old-winner",
                    "title": "Resolve dirty landing PR xenota#229",
                    "status": "open",
                    "created_at": "2026-04-26T10:00:00Z",
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-dirty"],
                    "comments": [],
                },
                {
                    "id": "xc-stale-loser",
                    "title": "Landing blocker: xenota PR #229",
                    "status": "open",
                    "created_at": "2026-04-26T11:00:00Z",
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-blocker"],
                    "comments": [],
                },
            ]
        )

        result = self.file_blocker(producer="producer-late")

        self.assertEqual(result["action"], "deduplicated")
        self.assertEqual(result["bead_id"], "xc-old-winner")
        records = self.records()
        winner = next(r for r in records if r["id"] == "xc-old-winner")
        loser = next(r for r in records if r["id"] == "xc-stale-loser")
        self.assertEqual(winner["status"], "open")
        self.assertEqual(loser["status"], "closed")
        self.assertIn("duplicate of xc-old-winner", loser.get("close_reason", ""))
        self.assertIn("stale open blocker reconcile", loser.get("close_reason", ""))
        # Evidence comment was appended to the surviving winner only.
        self.assertEqual(len(winner["comments"]), 1)
        self.assertIn("producer: producer-late", winner["comments"][0]["text"])


    def test_find_reconciles_stale_open_duplicates(self):
        # Regression: cmd_find is the pre-check used by landing_poll.sh
        # (`blocker_exists`). If a prior race left two open blockers, the
        # poll loop's `find` must repair the duplicate state — not return
        # one bead and leave the other open forever.
        self.seed(
            [
                {
                    "id": "xc-old-winner",
                    "title": "Resolve dirty landing PR xenota#229",
                    "status": "open",
                    "created_at": "2026-04-26T10:00:00Z",
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-dirty"],
                    "comments": [],
                },
                {
                    "id": "xc-stale-loser",
                    "title": "Landing blocker: xenota PR #229",
                    "status": "open",
                    "created_at": "2026-04-26T11:00:00Z",
                    "external_ref": "gh:xenota-collective/xenota#229",
                    "labels": ["landing-blocker"],
                    "comments": [],
                },
            ]
        )

        completed = subprocess.run(
            [str(HELPER), "find", "--external-ref", "gh:xenota-collective/xenota#229"],
            env=self.env,
            text=True,
            capture_output=True,
            check=True,
        )
        result = json.loads(completed.stdout)

        self.assertEqual(result["bead_id"], "xc-old-winner")
        records = self.records()
        winner = next(r for r in records if r["id"] == "xc-old-winner")
        loser = next(r for r in records if r["id"] == "xc-stale-loser")
        self.assertEqual(winner["status"], "open")
        self.assertEqual(loser["status"], "closed")
        self.assertIn("duplicate of xc-old-winner", loser.get("close_reason", ""))
        self.assertIn("stale open blocker reconcile", loser.get("close_reason", ""))


if __name__ == "__main__":
    unittest.main()
