import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
HELPER = ROOT / ".claude" / "skills" / "manage-swarm" / "scripts" / "landing_blocker.sh"


FAKE_BD = r"""#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

store_path = Path(os.environ["FAKE_BD_STORE"])


def load():
    if store_path.exists():
        return json.loads(store_path.read_text())
    return []


def save(items):
    store_path.write_text(json.dumps(items, sort_keys=True))


args = sys.argv[1:]
items = load()

if args[:1] == ["list"]:
    print(json.dumps(items))
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


if __name__ == "__main__":
    unittest.main()
