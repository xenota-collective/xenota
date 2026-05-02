# xc-m7mq routing-accuracy eval

Evidence pass over open + merged PR outcomes in xenota-collective/xenon and
xenota-collective/xenota for the 2026-04-26 → 2026-05-02 window. Generated for
bead xc-m7mq before any model-strength tuning so the strategy-tune lane has
current evidence to work from.

## Scope (bounded)

- Two repos: `xenota-collective/xenon`, `xenota-collective/xenota`.
- Window: PRs **merged or created** between 2026-04-26 and 2026-05-02 inclusive
  (~1 week — the active swarm period since the last routing-accuracy baseline
  in xenon#596).
- Excluded: `dependabot/*`, `bump-*` (no routing decision), and the eval PR
  itself.
- This artifact is **read-only evidence**. It does not modify
  `driver_preference`, dispatcher policy, or `xsm.routing_accuracy` thresholds.
  Strategy edits get filed as separate beads (per AC).

## Inputs

- `gh pr list` snapshots of merged + open PRs in the window. Captured into
  `inputs/xenon_prs.json` and `inputs/xenota_prs.json`.

## Taxonomy

`driver_preference` is inferred from the head-ref prefix:

| prefix                     | driver       |
|----------------------------|--------------|
| `codex/`, `worker-codex-*` | codex        |
| `claude/`                  | claude       |
| `gemini/`, `gemini-1/`     | gemini       |
| `xsm/`, `starshot/`        | xsm-internal |
| anything else              | unknown      |

`risk_class` is inferred from title/branch keywords (coarse, intentionally
overlapping rules collapse to the *first* match in this order):

1. `production_security`: ssh, redact, privacy, audit, secret, sensitive,
   security, gpg, host-key
2. `landing_protocol`: landing, blocker, conflict, merge, gate, qa, handoff,
   verdict
3. `xsm_control_plane`: xsm, supervisor, dispatch, role, control, lane,
   intervene, restart, respawn, hook, monitor, pane, tmux, window, worker,
   pool, recover
4. `cheap_eligible`: docs, doc, prompt, comment, typo, lint, format, baseline,
   pointer-only, README, AGENTS, CLAUDE
5. `routing_evidence`: routing, accuracy, eval, evidence
6. fallback: `unclassified`

`outcome_class` is observable per PR:

- `merged` — `state == MERGED`
- `merged_late_pointer` — merged but title contains "bump"/"pointer"/"refresh"
  AND merge time delta from creation is > 24h (proxy for late-review or stack
  refresh churn)
- `open_recent` — `state == OPEN`, created within 48h of snapshot
- `open_stale` — `state == OPEN`, older than 48h (potential late-review /
  conflict pressure)
- `closed_unmerged` — `state == CLOSED && mergedAt is null`

## Outputs

- `inputs/xenon_prs.json`, `inputs/xenota_prs.json` — raw snapshots
- `outcomes.csv` — flat row-per-PR dataset
- `report.md` — pivot tables and verdicts (no policy edits)
- `scripts/build_dataset.py` — deterministic build from inputs/* → outcomes.csv
- `scripts/render_report.py` — outcomes.csv → report.md tables

## Verdict thresholds (matching xenon#596 conventions)

These are read from `xsm.routing_accuracy.Thresholds` defaults:

- `EXPAND_CHEAP`: cheap-eligible × cheap, late_review ≤ 0.10, n ≥ 3
- `PAUSE_CHEAP`: cheap × any, late_review ≥ 0.30, n ≥ 3
- `WATCH_STRONG`: strong-routed class with late_review ≥ 0.30 OR
  security_followup ≥ 0.20, n ≥ 3
- `STRONG_OK`: strong-routed class, late_review ≤ 0.20, security_followup ≤
  0.10, n ≥ 3
- `INCONCLUSIVE`: n < 3 in bucket

Because this eval uses *coarse* outcome proxies (no review-comment scrape, no
CI-failure scrape), late_review/security_followup numbers are upper bounds; we
flag `WATCH_*` only when the bucket already trips on the proxy alone.

## Non-goals

- Driver-quality scoring per file/path.
- Re-deriving risk_class from bead-store labels (the bd lookup window is
  separate work — see xc-tx49i).
- Recommending driver_preference edits. That is xc-m7mq's *output*, not its
  body of work; if any are warranted they are filed as new strategy-tune beads.

## How to refresh

```sh
cd _ai/evals/xc-m7mq-routing-accuracy
gh pr list --repo xenota-collective/xenon --state merged --limit 100 \
  --json number,title,state,labels,mergedAt,createdAt,headRefName \
  --search "merged:2026-04-26..2026-05-02" > inputs/xenon_merged.json
gh pr list --repo xenota-collective/xenon --state open --limit 100 \
  --json number,title,state,labels,createdAt,headRefName \
  --search "created:2026-04-26..2026-05-02" > inputs/xenon_open.json
# repeat for xenota; then:
python3 scripts/build_dataset.py
python3 scripts/render_report.py
```
