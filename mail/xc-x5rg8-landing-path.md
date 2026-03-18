# xc-x5rg8 Landing Path

Bead: `xc-x5rg8` (`Auto-spawn and sleep projections from cortex-issued instructions`)

## Current Reality

- `xenon` implementation is already landed on `xenon/main`
- follow-up cortex slices `.4`, `.5`, and `.6` are closed
- `xenota/main` already tracks a newer `xenon` commit than the original
  `xc-x5rg8` landing work
- the only remaining landing work is top-level human review/manual-QA on the
  refreshed packet and final parent-bead closure

## Why The Old Placeholder PR Was Stale

The original `xenota#12` placeholder branch carried:
- stale `xenon` submodule pointers from pre-landing work
- a stale `handbook` pointer for boundary-plan review context
- placeholder `.beads` metadata
- early packet artifacts that referenced older branch provenance

That made it a poor landing vehicle once the actual xenon code landed on
`main`.

## Refreshed Landing Vehicle

This refreshed branch/PR is intentionally narrow:
- no stale submodule pointer changes
- no placeholder `.beads` payload
- no top-level code delta that tries to re-land already-landed xenon work
- only current landing packet artifacts under `mail/`

## Human Gate

Stop at human review/manual-QA:

1. Review `mail/xc-x5rg8-landing-readiness.md`
2. Review the `2026-03-17` command transcript and the fresh `2026-03-19`
   rerun evidence on `xc-x5rg8`
3. Confirm the known console startup/warm-up race is acceptable as operator
   context, not as a landing blocker
4. Merge the refreshed top-level PR and close `xc-x5rg8`

## Closing Rule

Do not close `xc-x5rg8` from this branch refresh alone. Close it only after the
human gate accepts the packet and the refreshed top-level PR is merged.
