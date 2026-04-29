---
name: start-feature
description: Start a new feature branch from a bead. Enforces branch naming, rebase off origin/main, bead hygiene, and PR-only landing. Use when beginning work on a bead, starting a new feature, or when a worker needs to set up their branch correctly.
---

# Start Feature

Use this skill when beginning work on a bead. It enforces the branch and bead hygiene rules that keep the repo clean and reviewable.

## Hard Rules

1. **NEVER push directly to main.** All work goes through feature branches and PRs. Direct pushes to main are a policy violation.
2. **Always start from a fresh rebase off origin/main.** Stale bases cause merge conflicts that waste reviewer time.
3. **One bead per branch.** Do not mix unrelated work on the same branch.
4. **Name branches consistently.** Use the pattern `<crew>/<bead-id>-<short-slug>`.

## Startup Sequence

When starting work on bead `<BEAD>`:

```bash
# 1. Sync with remote
git fetch origin main

# 2. Create feature branch from current main
git checkout -b <crew>/<bead-id>-<short-slug> origin/main

# 3. Verify clean state
git status  # must be clean

# 4. Update bead status
bd update <BEAD> -s in_progress

# 5. Start working
```

### Branch naming examples

```
harbor/xc-cf28-snapshot-staging
life/xc-wc20.3-snapshot-capture
starshot/xc-6g6w-tauri-phase1
quay/xc-97kb-dreaming-consolidation
```

## Commit Hygiene

- Commit messages must be ONE SHORT SENTENCE. No description, no body, no co-authored-by, no emojis.
- Each commit should be a coherent unit. Do not commit half-finished work just to checkpoint.
- Run tests before committing. Do not push broken commits.

## Push Rules

- Push to your feature branch only: `git push -u origin <branch-name>`
- NEVER `git push origin main`
- If your branch is behind main, rebase before pushing:

```bash
git fetch origin main
git rebase origin/main
# resolve any conflicts
git push --force-with-lease
```

## Bead Hygiene

- Update bead status when you start: `bd update <BEAD> -s in_progress`
- Add comments to the bead as you make progress on meaningful milestones
- If you discover the work is bigger than expected, comment on the bead and ask for it to be split
- If you get blocked, update the bead with the exact blocker
- Do NOT close the bead yourself. Closing happens after PR review and landing.

## Polling Rules (xc-zojv)

When you need to poll for an external event — CI completion, a SHA appearing on a branch, a file showing up — **always wrap the wait with a wall-clock deadline**:

```bash
# CORRECT: bounded wait
timeout 30m bash -c 'until [[ $(gh run list --jq ".[0].headSha") == abc123* ]]; do sleep 6; done'

# WRONG: unbounded — survives parent restart, polls forever
until [[ $(gh run list --jq ".[0].headSha") == abc123* ]]; do sleep 6; done
```

If you use Claude's Bash tool with `run_in_background: true`, the rule is the same: wrap with `timeout`. Detached shells without a deadline orphan when the watched condition never becomes true (force-pushed branch, never-running workflow, restarted parent), and they keep firing `gh` + `jq` subprocesses indefinitely. The XSM hygiene reaper kills them after 1h, but you should not rely on that — write the deadline yourself.

## What Not To Do

- Do not push to main under any circumstances
- Do not create branches off other feature branches unless explicitly told to
- Do not amend commits that have already been pushed
- Do not work on a bead without updating its status
- Do not leave a branch with failing tests
- Do not squash your branch history before review — the reviewer wants to see the progression
- Do not background `until ... do sleep ... done` polls without `timeout` (xc-zojv)
