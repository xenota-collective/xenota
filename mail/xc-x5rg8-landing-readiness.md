# xc-x5rg8 Landing Readiness

Bead: `xc-x5rg8` (`Auto-spawn and sleep projections from cortex-issued instructions`)

Top-level repo state:
- repo: `xenota`
- branch baseline: `main`

Implementation reality:
- the xenon implementation is already landed on `xenon/main`
- current top-level `main` already tracks a newer `xenon` commit than the original `xc-x5rg8` landing work

Key landed xenon evidence:
- `4712094` `add projection auto-spawn and idle-sleep with lifecycle persistence`
- `5925e05` `add deterministic e2e tests for cortex-mediated projection startup and fix missing cortex notify in run_tick_once/process_dispatch`

Closed follow-up children:
- `xc-x5rg8.4` Route projection reconciliation through cortex for missing and suspended targets
- `xc-x5rg8.5` Define nucleus-to-cortex orchestration boundary for projection routing
- `xc-x5rg8.6` Add deterministic e2e coverage for cortex-mediated projection startup

## Scope

This packet is no longer for an unlanded xenon code change.

It exists to support final human review of the already-landed `xc-x5rg8`
feature and to resolve the stale top-level placeholder PR state in `xenota`.

## Evidence

Automated evidence captured across the parent and child beads:
- original implementation note recorded `512` nucleus tests and `48` xenon-cli tests passing
- child `xc-x5rg8.4` closed with `15` new tests plus `528` existing passing
- child `xc-x5rg8.6` closed with `8` deterministic e2e tests for cortex-mediated startup/routing

Current code-reality evidence:
- the feature commits are already present on `xenon/main`
- current `xenota/main` already points at a newer `xenon` commit than the original
  `xc-x5rg8` landing branch

Manual e2e evidence recorded on the bead comments on `2026-03-17`:
- used the global `xn` CLI from `PATH`
- used disposable test data under `~/.xenons/xc-x5rg8-e2e`
- validated lifecycle path `suspended -> active -> suspended`
- verified persisted lifecycle jobs:
  - `start|succeeded`
  - `stop|succeeded`
- verified mapped Podman container state changed accordingly
- restored the pre-existing live nucleus after the run
- re-verified cleanup:
  - no `xc-x5rg8-e2e*` containers remain
  - no `xc-x5rg8-sleeper` container remains
  - `~/.xenons/xc-x5rg8-e2e` no longer exists

## Operator Note

Fresh disposable instances have a startup race immediately after:

`xn up -d && xn status && xn state projections .`

The final `xn state projections .` can fail before `console.json` is written.
A short wait/retry resolves it. This is operator context, not a blocker to the
validated lifecycle behavior.

## Current Landing Decision

The old draft PR `xenota#12` was a placeholder landing vehicle. It became stale
because:
- the xenon implementation landed on `xenon/main`
- follow-up cortex work landed on `xenon/main`
- `xenota/main` now already tracks a newer xenon commit
- the old PR diff mostly consisted of stale submodule pointers, placeholder
  metadata, and packet artifacts

This refreshed PR is the real top-level landing vehicle for the remaining human
review/manual-QA gate.

## Human Verification Checklist

1. Confirm the parent `xc-x5rg8` comments and child close reasons match the
   landed xenon reality.
2. Confirm the `2026-03-17` manual validation packet is still sufficient for
   the landed cortex follow-up state, or explicitly request a fresh rerun on
   current `xenon/main`.
3. Confirm the `console.json` startup race is acceptable as operator context,
   not as a blocker.
4. Confirm this refreshed top-level PR should replace the prior placeholder
   interpretation of `xenota#12`.

## Final Merge Intent

If human review/manual-QA accepts the existing packet, this top-level PR can be
merged and `xc-x5rg8` can then be closed as landed.
