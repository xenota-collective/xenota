#!/usr/bin/env python3
"""Build outcomes.csv from inputs/*.json snapshots.

Pure-stdlib, deterministic. See ../README.md for taxonomy + scope.
"""
from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUTS = ROOT / "inputs"
OUTCOMES = ROOT / "outcomes.csv"

SNAPSHOT_AT = datetime(2026, 5, 3, 0, 0, tzinfo=timezone.utc)
STALE_HOURS = 48
LATE_POINTER_HOURS = 24

DRIVER_PREFIXES = (
    ("worker-codex-", "codex"),
    ("codex/", "codex"),
    ("claude/", "claude"),
    ("gemini-1/", "gemini"),
    ("gemini/", "gemini"),
    ("xsm/", "xsm-internal"),
    ("starshot/", "xsm-internal"),
)


def driver_for(head_ref: str) -> str:
    for prefix, name in DRIVER_PREFIXES:
        if head_ref.startswith(prefix):
            return name
    if head_ref.startswith("dependabot/") or head_ref.startswith("bump-"):
        return "bot"
    return "unknown"


RISK_RULES = (
    (
        "production_security",
        ("ssh", "redact", "privacy", "audit", "secret", "sensitive", "security",
         "gpg", "host-key", "host_key"),
    ),
    (
        "landing_protocol",
        ("landing", "blocker", "conflict", "merge", " gate", "qa ", " qa", "qa-",
         "handoff", "verdict"),
    ),
    (
        "xsm_control_plane",
        ("xsm", "supervisor", "dispatch", "role", "control", "lane", "intervene",
         "restart", "respawn", "hook", "monitor", "pane", "tmux", "window",
         "worker", "pool", "recover", "wrangle", "wrangler"),
    ),
    (
        "cheap_eligible",
        (" docs", "doc:", "prompt", "comment", "typo", "lint", "format",
         "baseline", "pointer-only", "readme", "agents", "claude.md"),
    ),
    (
        "routing_evidence",
        ("routing", "accuracy", " eval", "evidence"),
    ),
)


def risk_class_for(title: str, head_ref: str) -> str:
    # Pad with spaces so keywords like " gate", "qa ", " docs", " eval"
    # match when they appear at the very start or end of title/head_ref.
    blob = f" {title.lower()} {head_ref.lower()} "
    for label, kws in RISK_RULES:
        for kw in kws:
            if kw in blob:
                return label
    return "unclassified"


def hours_between(a: datetime, b: datetime) -> float:
    return (a - b).total_seconds() / 3600.0


def parse_dt(s: str | None) -> datetime | None:
    if not s:
        return None
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def outcome_for(state: str, created: datetime, merged: datetime | None,
                title: str) -> tuple[str, float | None]:
    if state == "MERGED" and merged is not None:
        delta = hours_between(merged, created)
        title_l = title.lower()
        if any(t in title_l for t in ("bump", "pointer", "refresh")):
            if delta > LATE_POINTER_HOURS:
                return "merged_late_pointer", delta
        return "merged", delta
    if state == "CLOSED":
        return "closed_unmerged", None
    age = hours_between(SNAPSHOT_AT, created)
    return ("open_stale" if age > STALE_HOURS else "open_recent", age)


def load(path: Path) -> list[dict]:
    if not path.exists():
        return []
    return json.loads(path.read_text())


def main() -> None:
    rows: list[dict] = []
    for repo, mfile, ofile in (
        ("xenota-collective/xenon", "xenon_merged.json", "xenon_open.json"),
        ("xenota-collective/xenota", "xenota_merged.json", "xenota_open.json"),
    ):
        for source in (load(INPUTS / mfile), load(INPUTS / ofile)):
            for pr in source:
                head_ref = pr["headRefName"]
                if head_ref.startswith("dependabot/") or head_ref.startswith("bump-"):
                    continue
                title = pr["title"]
                created = parse_dt(pr["createdAt"])
                merged = parse_dt(pr.get("mergedAt"))
                outcome, age_h = outcome_for(pr["state"], created, merged, title)
                rows.append({
                    "repo": repo,
                    "pr": pr["number"],
                    "title": title,
                    "head_ref": head_ref,
                    "state": pr["state"],
                    "driver_preference": driver_for(head_ref),
                    "risk_class": risk_class_for(title, head_ref),
                    "outcome_class": outcome,
                    "age_or_delta_hours": (
                        round(age_h, 2) if age_h is not None else ""
                    ),
                    "created_at": pr["createdAt"],
                    "merged_at": pr.get("mergedAt") or "",
                })
    rows.sort(key=lambda r: (r["repo"], r["pr"]))
    fieldnames = [
        "repo", "pr", "driver_preference", "risk_class", "outcome_class",
        "state", "age_or_delta_hours", "title", "head_ref", "created_at",
        "merged_at",
    ]
    with OUTCOMES.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {OUTCOMES} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
