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

## Bead Reference Clarity

- Whenever referring to a bead in updates, plans, or handoff notes, always include both:
  - bead ID (for example `xc-wisp-sm2`)
  - bead title (for example `update-handbook`)
- Preferred format: `<id> (<title>)`.

## Test Xenon Data

- Store all manual test xenon data under `~/.xenons/`.
- Do not create test xenon data directories under `xenon/nucleus/.tmp/`.
- Use paths like `~/.xenons/<xenon-name-or-scenario>/` for reproducible manual runs.

## Manual Testing CLI Policy

- For manual testing, always use the globally installed `xn` CLI from `PATH`.
- Do not run `xn` via package-local paths like `.venv/bin/xn` except for explicit debugging.
- If behavior differs, fix the global install and continue manual testing with global `xn`.

## Handbook Oversight (Mandatory)

- You may make local edits under `handbook/` in order to prepare diffs for human review.
- Never commit or push changes under `handbook/` without explicit human approval in the current session.
- For handbook work, default to preparing proposals/diffs first, then wait for a human "approved/proceed" confirmation before committing or pushing handbook changes.
- If handbook changes were made accidentally and you are unsure whether they should be kept, stop and ask for human direction before continuing.

## Handbook Reality Boundary

- `handbook/docs/technical/` is for implemented/current reality only.
- Do not put speculative, draft, or future-state behavior in technical docs.
- Put proposed/future-state design in `handbook/docs/plans/` (or `handbook/docs/plans/draft/`) until implemented.
- When implementation lands, update technical docs to match reality and keep plans as planning artifacts.

## OpenSpec Usage Policy

OpenSpec is used as a **change-spec workflow**, not as a second long-lived documentation system.

- Handbook is the source of truth for implemented architecture and behavior.
- Use OpenSpec for non-trivial/high-risk changes (security boundaries, protocol contracts, data formats, cross-module behavior).
- Do not create OpenSpec changes for small/local edits that do not benefit from formal deltas.
- Every OpenSpec change must reference the target handbook doc(s) to update.
- `openspec validate <change>` must pass before review/merge.
- After implementation lands, archive/close the OpenSpec change and ensure handbook docs reflect final behavior.
- Do not treat archived `xenon/openspec/specs/*` content as current authority when handbook says otherwise.

## Submodule Workflow (Mandatory)

This repo uses git submodules (`xenon/`, `handbook/`). Treat submodules as separate repos with their own commits.

- Always check state in both layers:
  - Top repo: `git status`
  - Submodule: `git -C <submodule> status`
- Never commit top-level pointer changes before submodule commits are pushed.
- For code changes in `xenon/`:
  1. Commit and push inside `xenon/` first.
  2. Then commit the updated `xenon` pointer in top repo.
  3. Run `git pull --rebase`, `bd sync`, `git push` in top repo.
- For `handbook/`, follow Handbook Oversight rules above. Do not edit or push handbook content without explicit human approval.

### Rebase/Merge Safety for Submodules

- After any `git pull --rebase` in top repo, verify submodule alignment:
  - `git submodule status`
  - If status shows `+` for a submodule, your working tree checkout does not match the commit recorded by top repo.
- To realign submodule checkout to recorded commit (safe, non-destructive):
  - `git submodule update --init --recursive <submodule>`
- If submodule has local edits you intend to keep:
  1. Commit/push inside the submodule.
  2. Return to top repo and commit/push updated submodule pointer.
- If submodule has unexpected changes you did not make:
  - Stop and ask for human direction before modifying submodule content.

### Quick Diagnostics

- Show recorded commit from top repo: `git ls-tree HEAD <submodule>`
- Show current submodule HEAD: `git -C <submodule> rev-parse HEAD`
- Show submodule upstream HEAD: `git -C <submodule> rev-parse @{u}`
- Healthy state means:
  - Top repo `git status` clean
  - Submodule `git status` clean
  - `git submodule status` has no leading `+`

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

<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Dolt-powered version control with native sync
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update <id> --claim --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task atomically**: `bd update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Auto-Sync

bd automatically syncs via Dolt:

- Each write auto-commits to Dolt history
- Use `bd dolt push`/`bd dolt pull` for remote sync
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
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

<!-- END BEADS INTEGRATION -->
