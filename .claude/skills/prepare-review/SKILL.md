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

### 4. Record QA verdict artifact

XSM requires a machine-readable QA verdict artifact in `_ai/` before a branch
can be landed. For xenon/xenota projects, use the `manual-test` skill or
`scripts/record-qa-verdict.sh` (if available) to generate one.

The verdict MUST include:
- `bead_id`
- `commit_sha` (matching the head of the PR)
- `overall_status`: `pass` or `fail`
- `gates`: status of individual checks

If no automated tool is available, manually create `_ai/verdict-<bead-id>.json`.

### 5. Push the branch

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

## What Not To Do

- Do not create a PR with failing tests
- Do not create a PR against a branch other than main unless explicitly told to
- Do not merge your own PR
- Do not close the bead — that happens after landing
- Do not squash commits before review
- Do not create a PR without a bead reference in the title
- Do not push directly to main instead of creating a PR
