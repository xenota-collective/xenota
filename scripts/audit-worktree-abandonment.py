#!/usr/bin/env python3
"""Read-only audit for abandoned xenota worktrees."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Sequence


LEGACY_PER_BEAD_RE = re.compile(r"^worker-[a-z]+-\d+-xc-.+")
RESERVED_HANDLE_RE = re.compile(
    r"^(auditor|product-owner|retro|supervisor|watcher|watcher-xenota|wrangler|"
    r"landing(-\d+)?|worker-(claude|codex|gemini)-\d+)$"
)
BEAD_ID_RE = re.compile(r"\bxc-[A-Za-z0-9]+(?:\.[A-Za-z0-9]+)?\b")


@dataclass(frozen=True)
class WorktreeRecord:
    path: Path
    head: str = ""
    branch: str = ""
    detached: bool = False
    bare: bool = False

    @property
    def handle(self) -> str:
        return self.path.name


@dataclass(frozen=True)
class RuntimeSignals:
    live_handles: frozenset[str] = frozenset()
    live_paths: frozenset[Path] = frozenset()
    workmux_open_handles: frozenset[str] = frozenset()


@dataclass
class WorktreeFacts:
    record: WorktreeRecord
    is_main: bool = False
    dirty: bool = False
    age_days: int | None = None
    remote_exists: bool | None = None
    merged_to_origin_main: bool | None = None
    bead_id: str | None = None
    bead_status: str | None = None
    submodule_layout: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class Classification:
    state: str
    reasons: tuple[str, ...]
    confirmation_required: bool = True


def run(
    args: Sequence[str],
    cwd: Path | None = None,
    check: bool = False,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def parse_worktree_porcelain(output: str) -> list[WorktreeRecord]:
    records: list[WorktreeRecord] = []
    current: dict[str, str | bool] = {}

    def flush() -> None:
        if not current:
            return
        path = current.get("worktree")
        if not isinstance(path, str):
            raise ValueError("git worktree porcelain entry without worktree path")
        records.append(
            WorktreeRecord(
                path=Path(path),
                head=str(current.get("HEAD", "")),
                branch=str(current.get("branch", "")),
                detached=bool(current.get("detached", False)),
                bare=bool(current.get("bare", False)),
            )
        )

    for line in output.splitlines():
        if not line:
            flush()
            current = {}
            continue
        if " " in line:
            key, value = line.split(" ", 1)
            current[key] = value
        else:
            current[line] = True
    flush()
    return records


def branch_name(ref: str) -> str:
    return ref.removeprefix("refs/heads/")


def extract_bead_id(*parts: str) -> str | None:
    for part in parts:
        match = BEAD_ID_RE.search(part)
        if match:
            return match.group(0)
    return None


def classify_worktree(
    facts: WorktreeFacts,
    runtime: RuntimeSignals,
    stale_days: int = 14,
) -> Classification:
    handle = facts.record.handle
    path = facts.record.path
    reasons: list[str] = []

    live = (
        handle in runtime.live_handles
        or handle in runtime.workmux_open_handles
        or path in runtime.live_paths
    )
    reserved = bool(RESERVED_HANDLE_RE.match(handle))
    legacy_per_bead = bool(LEGACY_PER_BEAD_RE.match(handle))
    stale = facts.age_days is not None and facts.age_days >= stale_days
    bad_submodule_layout = any(
        value.startswith("missing") or value.startswith("unexpected")
        for value in facts.submodule_layout.values()
    )

    if facts.is_main:
        return Classification("active", ("main worktree",), False)
    if live:
        reasons.append("live tmux/workmux handle")
    if reserved:
        reasons.append("reserved swarm lane handle")
    if facts.dirty:
        reasons.append("has uncommitted changes")
    if live or reserved:
        return Classification("active", tuple(reasons), False)

    if legacy_per_bead and not facts.dirty:
        reasons.append("legacy per-bead worker handle")
        if stale:
            reasons.append(f"HEAD age {facts.age_days}d >= {stale_days}d")
        if facts.remote_exists is False:
            reasons.append("remote branch missing")
        if facts.merged_to_origin_main is True:
            reasons.append("HEAD reachable from origin/main")
        if facts.bead_status in {"closed", "landed"}:
            reasons.append(f"bead {facts.bead_id} is {facts.bead_status}")
        elif facts.bead_status:
            reasons.append(f"bead {facts.bead_id} is {facts.bead_status}")
        if bad_submodule_layout:
            reasons.append("non-standard submodule layout")
        return Classification("abandoned", tuple(reasons), True)

    if facts.dirty:
        return Classification("unsure", tuple(reasons), True)

    if facts.remote_exists is False and stale:
        return Classification(
            "abandoned",
            ("remote branch missing", f"HEAD age {facts.age_days}d >= {stale_days}d"),
            True,
        )

    if facts.merged_to_origin_main is True and stale:
        return Classification(
            "abandoned",
            ("HEAD reachable from origin/main", f"HEAD age {facts.age_days}d >= {stale_days}d"),
            True,
        )

    reasons.append("no decisive abandonment rule matched")
    if stale:
        reasons.append(f"HEAD age {facts.age_days}d >= {stale_days}d")
    if bad_submodule_layout:
        reasons.append("non-standard submodule layout")
    return Classification("unsure", tuple(reasons), True)


def discover_worktrees(repo: Path) -> list[WorktreeRecord]:
    result = run(["git", "worktree", "list", "--porcelain"], cwd=repo, check=True)
    return parse_worktree_porcelain(result.stdout)


def discover_submodule_paths(repo: Path) -> list[str]:
    gitmodules = repo / ".gitmodules"
    if not gitmodules.exists():
        return []
    result = run(
        ["git", "config", "--file", str(gitmodules), "--get-regexp", r"^submodule\..*\.path$"],
        cwd=repo,
    )
    if result.returncode != 0:
        return []
    paths: list[str] = []
    for line in result.stdout.splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            paths.append(parts[1])
    return paths


def git_dir(repo: Path) -> Path:
    result = run(["git", "rev-parse", "--git-common-dir"], cwd=repo, check=True)
    common = Path(result.stdout.strip())
    if not common.is_absolute():
        common = repo / common
    return common.resolve()


def detect_submodule_layout(path: Path, handle: str, submodule_paths: Iterable[str]) -> dict[str, str]:
    layout: dict[str, str] = {}
    for submodule in submodule_paths:
        git_marker = path / submodule / ".git"
        if not git_marker.exists():
            layout[submodule] = "missing .git marker"
            continue
        if git_marker.is_dir():
            layout[submodule] = "directory .git marker"
            continue
        try:
            text = git_marker.read_text(encoding="utf-8").strip()
        except OSError as exc:
            layout[submodule] = f"unreadable .git marker: {exc}"
            continue
        expected_fragment = f"/worktrees/{handle}/modules/{submodule}"
        normalized = text.replace("\\", "/")
        if expected_fragment in normalized:
            layout[submodule] = "worktree submodule"
        elif "/.git/modules/" in normalized:
            layout[submodule] = "shared main submodule"
        else:
            layout[submodule] = "unexpected gitdir"
    return layout


def discover_runtime_signals(repo: Path) -> RuntimeSignals:
    live_handles: set[str] = set()
    live_paths: set[Path] = set()
    workmux_open_handles: set[str] = set()

    tmux = run(
        ["tmux", "list-windows", "-a", "-F", "#{window_name}\t#{pane_current_path}"],
        cwd=repo,
    )
    if tmux.returncode == 0:
        for line in tmux.stdout.splitlines():
            name, _, pane_path = line.partition("\t")
            if name:
                live_handles.add(name)
            if pane_path:
                live_paths.add(Path(pane_path).resolve())

    workmux = run(["workmux", "list", "--json"], cwd=repo)
    if workmux.returncode == 0:
        try:
            for item in json.loads(workmux.stdout):
                if item.get("is_open") and item.get("handle"):
                    workmux_open_handles.add(str(item["handle"]))
        except json.JSONDecodeError:
            pass

    return RuntimeSignals(
        live_handles=frozenset(live_handles),
        live_paths=frozenset(live_paths),
        workmux_open_handles=frozenset(workmux_open_handles),
    )


def worktree_dirty(path: Path) -> bool:
    result = run(["git", "status", "--porcelain"], cwd=path)
    return bool(result.stdout.strip()) if result.returncode == 0 else True


def head_age_days(path: Path, now: int) -> int | None:
    result = run(["git", "show", "-s", "--format=%ct", "HEAD"], cwd=path)
    if result.returncode != 0:
        return None
    try:
        timestamp = int(result.stdout.strip())
    except ValueError:
        return None
    return max(0, (now - timestamp) // 86400)


def remote_branch_exists(repo: Path, branch: str) -> bool | None:
    if not branch:
        return None
    result = run(["git", "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{branch}"], cwd=repo)
    return result.returncode == 0


def merged_to_origin_main(repo: Path, head: str) -> bool | None:
    if not head:
        return None
    main = run(["git", "show-ref", "--verify", "--quiet", "refs/remotes/origin/main"], cwd=repo)
    if main.returncode != 0:
        return None
    result = run(["git", "merge-base", "--is-ancestor", head, "origin/main"], cwd=repo)
    if result.returncode == 0:
        return True
    if result.returncode == 1:
        return False
    return None


def bead_status(bead_id: str | None, repo: Path) -> str | None:
    if not bead_id:
        return None
    result = run(["bd", "show", bead_id, "--json"], cwd=repo)
    if result.returncode != 0:
        return None
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None
    if isinstance(payload, list) and payload:
        status = payload[0].get("status")
        return str(status) if status else None
    return None


def gather_facts(
    repo: Path,
    record: WorktreeRecord,
    main_path: Path,
    submodule_paths: Sequence[str],
    now: int,
) -> WorktreeFacts:
    branch = branch_name(record.branch)
    bead_id = extract_bead_id(record.handle, branch)
    return WorktreeFacts(
        record=record,
        is_main=record.path.resolve() == main_path.resolve(),
        dirty=worktree_dirty(record.path),
        age_days=head_age_days(record.path, now),
        remote_exists=remote_branch_exists(repo, branch),
        merged_to_origin_main=merged_to_origin_main(repo, record.head),
        bead_id=bead_id,
        bead_status=bead_status(bead_id, repo),
        submodule_layout=detect_submodule_layout(record.path, record.handle, submodule_paths),
    )


def report_rows(
    facts: Sequence[WorktreeFacts],
    classifications: Sequence[Classification],
) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for item, classification in zip(facts, classifications, strict=True):
        rows.append(
            {
                "handle": item.record.handle,
                "state": classification.state,
                "branch": branch_name(item.record.branch),
                "dirty": item.dirty,
                "age_days": item.age_days,
                "bead": item.bead_id,
                "bead_status": item.bead_status,
                "remote_exists": item.remote_exists,
                "merged_to_origin_main": item.merged_to_origin_main,
                "submodules": item.submodule_layout,
                "reasons": list(classification.reasons),
                "confirmation_required": classification.confirmation_required,
                "path": str(item.record.path),
            }
        )
    return rows


def print_markdown(rows: Sequence[dict[str, object]]) -> None:
    print("| State | Handle | Branch | Dirty | Bead | Age | Reasons |")
    print("|---|---|---|---:|---|---:|---|")
    for row in rows:
        reasons = "; ".join(str(reason) for reason in row["reasons"])
        bead = row["bead"] or ""
        bead_status = row["bead_status"] or ""
        bead_text = f"{bead} {bead_status}".strip()
        print(
            "| {state} | `{handle}` | `{branch}` | {dirty} | {bead} | {age} | {reasons} |".format(
                state=row["state"],
                handle=row["handle"],
                branch=row["branch"],
                dirty="yes" if row["dirty"] else "no",
                bead=bead_text,
                age="" if row["age_days"] is None else row["age_days"],
                reasons=reasons,
            )
        )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Classify xenota worktrees as active, abandoned, or unsure without pruning.",
    )
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="repository worktree to audit")
    parser.add_argument("--stale-days", type=int, default=14, help="HEAD age threshold")
    parser.add_argument("--json", action="store_true", help="emit JSON instead of Markdown")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    repo = args.repo.resolve()
    main_path = Path(run(["git", "rev-parse", "--show-toplevel"], cwd=repo, check=True).stdout.strip())
    if not main_path.is_absolute():
        main_path = (repo / main_path).resolve()
    common_git_dir = git_dir(main_path)
    main_repo_path = common_git_dir.parent if common_git_dir.name == ".git" else main_path
    submodule_paths = discover_submodule_paths(main_path)
    records = discover_worktrees(main_path)
    runtime = discover_runtime_signals(main_path)
    now = int(time.time())
    facts = [
        gather_facts(main_path, record, main_repo_path, submodule_paths, now)
        for record in records
    ]
    classifications = [
        classify_worktree(item, runtime, stale_days=args.stale_days) for item in facts
    ]
    rows = report_rows(facts, classifications)
    if args.json:
        print(json.dumps(rows, indent=2, sort_keys=True))
    else:
        print_markdown(rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
