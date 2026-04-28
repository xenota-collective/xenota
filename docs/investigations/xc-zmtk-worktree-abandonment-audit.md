# xc-zmtk Worktree Abandonment Audit

Date: 2026-04-29
Scope: `/Users/jv/projects/xenota/.worktrees/`

## Heuristic

The audit uses `git worktree list --porcelain` as the canonical inventory. Directory listings and workmux sidebar watcher state are secondary signals only.

Classify a worktree as `active` when any of these hold:

- It is the main checkout.
- A tmux/workmux window is live for the handle or current path.
- The handle is a reserved swarm lane (`worker-{claude,codex,gemini}-{1,2}`, `landing`, `landing-2`, `supervisor`, `product-owner`, `auditor`, `retro`, `wrangler`, `watcher`, `watcher-xenota`).

Classify a worktree as `abandoned` only when it is clean and has no live runtime signal, plus one of these deterministic patterns:

- Legacy per-bead worker handle such as `worker-codex-1-xc-*`.
- Remote branch is gone and the HEAD is older than the stale threshold.
- HEAD is reachable from `origin/main` and older than the stale threshold.

Classify everything else as `unsure`. Dirty worktrees are never prune candidates. Non-standard submodule layout is supporting evidence, not a standalone prune rule, because missing `xenon/.git` or `handbook/.git` can make cleanup commands dangerous.

Every `abandoned` result still requires explicit operator confirmation before pruning. The audit command is read-only.

## Command

```bash
python3 scripts/audit-worktree-abandonment.py --repo /Users/jv/projects/xenota --stale-days 14
python3 scripts/audit-worktree-abandonment.py --repo /Users/jv/projects/xenota --json
```

## Current Read-Only Result

The first-class per-bead leftovers are classified as `abandoned` and require operator confirmation before removal:

- `worker-codex-1-xc-2n4m`
- `worker-codex-1-xc-jcmv0.9`
- `worker-codex-1-xc-qihk`
- `worker-codex-1-xc-qj62`
- `worker-codex-1-xc-u8o0`

Additional legacy per-bead trees also classify as `abandoned` by the same rule and should be confirmed separately:

- `worker-codex-1-xc-17ri`
- `worker-codex-1-xc-k7p6`

One-off landing/project trees remain `unsure` unless a later operator pass confirms their branch/PR lifecycle:

- `land-fnik8`
- `landing-5b34-1777235431`
- `landing-xc-fkr2-1777379574`
- `landing-xc-pchm-1777379925`
- `landing-xc-vi07-rebase`
- `xc-jcmv0-po`
- `xsm-workmux-driver`

No pruning was performed for this bead.
