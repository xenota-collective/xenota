# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Test Xenon Data

- Store all manual test xenon data under repo root `.xenons/`.
- Do not create test xenon data directories under `xenon/nucleus/.tmp/`.
- Use paths like `.xenons/<xenon-name-or-scenario>/` for reproducible manual runs.

## Handbook Oversight (Mandatory)

- Never edit, commit, or push changes under `handbook/` without explicit human approval in the current session.
- For handbook work, stop after preparing proposals/diffs and wait for a human "approved/proceed" confirmation before applying edits.
- If handbook changes were made accidentally, stop and ask for human direction before continuing.

## OpenSpec Usage Policy

OpenSpec is used as a **change-spec workflow**, not as a second long-lived documentation system.

- Handbook is the source of truth for implemented architecture and behavior.
- Use OpenSpec for non-trivial/high-risk changes (security boundaries, protocol contracts, data formats, cross-module behavior).
- Do not create OpenSpec changes for small/local edits that do not benefit from formal deltas.
- Every OpenSpec change must reference the target handbook doc(s) to update.
- `openspec validate <change>` must pass before review/merge.
- After implementation lands, archive/close the OpenSpec change and ensure handbook docs reflect final behavior.
- Do not treat archived `xenon/openspec/specs/*` content as current authority when handbook says otherwise.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

## Campground Mode (Always Leave It Better)

Pre-existing problems are never an excuse to skip responsibility.

- NEVER treat "it was already broken" as a reason to avoid fixing tests, lint, build, or tooling failures.
- If a failure blocks your task, debug it and either fix it directly or create a clearly scoped bead with reproduction, impact, and next action.
- Do not hand off unknowns without first doing real investigation (logs, repro steps, git history, and local validation).
- Every session must improve repo health: fewer failures, clearer docs, stronger tests, or better issue tracking than when you started.
- If you touch an area, leave it cleaner and more reliable than you found it.
