# xc-x5rg8 Landing Readiness

Bead: `xc-x5rg8` (`Auto-spawn and sleep projections from cortex-issued instructions`)

Top-level repo state:
- repo: `xenota`
- branch baseline: `main`

Implementation reality:
- the xenon implementation is already landed on `xenon/main`
- current top-level `main` already tracks a newer `xenon` commit than the original `xc-x5rg8` landing work
- this landing branch adds a follow-on `xenon-cli` warm-up reliability fix via `xenon#26`

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

Fresh manual rerun completed on `2026-03-19` against current `xenon/main`:
- rebuilt `localhost/xenon-nucleus:latest` from the checked-out `xenon` repo
- reinitialized disposable instance at
  `~/.xenons/xc-x5rg8-e2e/xenon-2a48ee97`
- registered `proj-sleeper` as `suspended` on the fresh schema
- injected operator dispatch `Research the Xenota landing lane status and report back.`
- processed tick `1`; emitted one instruction and created one `start` job
- reconciled cortex start successfully:
  - projection state moved to `active`
  - mapped container `xc-x5rg8-sleeper` reached `running`
- submitted a report dispatch back from `proj-sleeper`
- processed tick `2`; report dispatch was accepted/actioned with no further instruction
- forced idle reconciliation and verified cortex auto-sleep:
  - created one `stop` job
  - `stop|succeeded`
  - projection returned to `suspended`
  - `xc-x5rg8-sleeper` returned to `Exited`
- operator verification after console warm-up:
  - `xn state projections .` showed `proj-sleeper | test | suspended | 1 | -`
  - `xn state dispatches --limit 5` showed both the operator request and the
    `proj-sleeper` report dispatch
- cleanup completed:
  - disposable `xc-x5rg8-e2e` instance torn down and removed
  - `xc-x5rg8-sleeper` container removed
  - live nucleus `xenon-152f4bf8_nucleus_1` restored on `127.0.0.1:7600`

Follow-on CLI hardening now staged in this landing path:
- `xenon#26` updates `xenon-cli` to retry warm-up handshakes and read-only
  console state requests with a fresh bearer token
- mutating console POSTs remain single-shot so the CLI does not replay side
  effects on disconnect
- local validation for the follow-on fix:
  - `uv run --directory xenon/xenon-cli pytest`
  - `uv run --directory xenon/xenon-cli black --check src tests`
  - `uv run --directory xenon/xenon-cli flake8 src tests`

## Current Landing Decision

The old draft PR `xenota#12` was a placeholder landing vehicle. It became stale
because:
- the xenon implementation landed on `xenon/main`
- follow-up cortex work landed on `xenon/main`
- `xenota/main` now already tracks a newer xenon commit
- the old PR diff mostly consisted of stale submodule pointers, placeholder
  metadata, and packet artifacts

This refreshed PR is the real top-level landing vehicle for the remaining human
review/manual-QA gate, including the `xenon#26` follow-on reliability fix.

## Human Verification Checklist

1. Confirm the parent `xc-x5rg8` comments and child close reasons match the
   landed xenon reality.
2. Review the fresh `2026-03-19` rerun evidence together with the
   `2026-03-17` transcript and confirm manual QA is satisfied.
3. Review `xenon#26` and confirm the warm-up retry fix is acceptable for the
   landing stack.
4. Confirm this refreshed top-level PR should replace the prior placeholder
   interpretation of `xenota#12`.

## Final Merge Intent

If human review/manual-QA accepts the existing packet, merge `xenon#26` first,
then merge this top-level PR and close `xc-x5rg8` as landed.
