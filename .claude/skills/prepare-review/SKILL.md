---
name: prepare-review
description: Prepare a feature branch for PR review. Enforces rebase onto current main, test pass, PR creation with proper description, and bead status update. Use when work is complete and ready for review.
---

# Prepare Review

Use this skill when a feature branch is ready for human review. It ensures the branch is clean, tested, rebased, and submitted as a proper PR.

## Pre-Review Checklist

Before creating a PR, verify ALL of the following:

### 1. Rebase onto current main

```bash
git fetch origin main
git rebase origin/main
# resolve any conflicts
```

If conflicts arise, resolve them and re-run tests. Do not submit a PR with unresolved conflicts.

### 2. All tests pass

```bash
# Run the relevant test suite for your changes
# For xenon packages:
uv run --directory packages/<pkg> pytest
# For nucleus:
uv run --directory nucleus pytest
# For xenon-desktop:
cd xenon-desktop && npm run build && npm test
```

Do NOT submit a PR with failing tests. Fix them first.

### 3. No untracked or uncommitted changes

```bash
git status  # must be clean
```

For normal `xenon/` feature work, review preparation stops at the xenon PR.
Do **not** create a paired xenota pointer PR for each submodule PR. The landing
lane drains CLEAN xenon PRs in batches of 3-5 and then pushes one consolidated
xenota pointer bump commit listing all bead IDs in the batch. Create a
top-level pointer branch only when the bead is explicitly a landing,
handbook-sync, or emergency/hotfix pointer task.

For xenota top-level pointer PRs, also verify local XSM worker state is not
tracked or staged:

```bash
scripts/check-xsm-worker-state.sh
```

Pointer PRs should carry only stable review/provenance metadata in the PR body:
bead ID/title, branch names, submodule PR links, test evidence, CI status,
review path, and landing dependency. Keep dynamic `.xsm-worker.json` fields
such as worker handle, assignment source/status, session-local branch state,
landing-gate scratch state, worktree paths, and resume/provisioning state
local/ignored.

### 4. Push the branch

```bash
git push -u origin <branch-name> --force-with-lease
```

Use `--force-with-lease` if you rebased. Never force-push without lease.

## Create the PR

Use `gh` to create the PR. The PR must target `main`.

```bash
gh pr create --title "<bead-id>: <short description>" --body "$(cat <<'EOF'
## Summary
<1-3 bullet points of what changed and why>

## Bead
<bead-id>: <bead title>

## Test evidence
<what tests were run and their results>

## Review notes
<anything the reviewer should pay attention to, edge cases, design decisions>
EOF
)"
```

### PR title rules
- Start with the bead ID
- Keep under 70 characters
- Describe what, not how

### PR title examples
```
xc-cf28: add staging directory with atomic rename for snapshots
xc-97kb: implement dream consolidation loop
xc-6g6w: scaffold Tauri v2 desktop wrapper
```

## After PR Creation

1. Update the bead with the PR link:
```bash
bd comments add <BEAD> "PR created: xenon#<number> - ready for review"
```

2. Do NOT merge the PR yourself. Wait for human review and approval.

3. If the reviewer requests changes:
   - Make the changes on the same branch
   - Push new commits (do not force-push over review comments)
   - Comment on the PR when changes are ready for re-review

## Polling for CI (xc-zojv)

If you need to wait for CI to finish before merging, **always bound the wait with a wall-clock timeout**. Bare `until ... do sleep ... done` shells started via the Bash tool's `run_in_background: true` mode survive parent session restarts and poll forever, burning the fd budget.

Prefer `gh pr checks --watch` (which exits when checks complete) over a hand-rolled `until` loop:

```bash
# CORRECT: gh blocks until done, timeout caps the wall-clock
timeout 30m gh pr checks <PR> --watch

# WRONG: redundant loop around --watch and unbounded if you forget timeout
until gh pr checks <PR> --watch | grep -q completed; do sleep 30; done
```

If you genuinely need an `until` loop (polling for a non-CI condition), wrap it with `timeout`:

```bash
timeout 30m bash -c 'until <test>; do sleep <n>; done'
```

## What Not To Do

- Do not create a PR with failing tests
- Do not create a PR against a branch other than main unless explicitly told to
- Do not merge your own PR
- Do not close the bead — that happens after landing
- Do not squash commits before review
- Do not create a PR without a bead reference in the title
- Do not push directly to main instead of creating a PR
- Do not background `until ... do sleep ... done` polls without `timeout` (xc-zojv)
