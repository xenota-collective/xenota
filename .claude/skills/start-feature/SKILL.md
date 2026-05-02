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
5. **Execute continuously through plan → implement → test → PR.** A reasonable plan for an assigned bead is not a stopping point. Do not pause to ask "Ready to proceed?", "Should I continue?", or "Approve plan?" before executing — proceed directly into implementation, then tests, then PR. Stop only for the conditions listed under [Continuous Execution](#continuous-execution).

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

## Continuous Execution

A worker assignment runs end-to-end without operator confirmation between phases. Once you start a bead, treat it as one continuous task: plan, implement, test, PR. Do not invent intermediate approval gates that the assignment did not name.

**Do not stop to ask any of these:**

- "Here's my plan — ready to proceed?"
- "Should I continue with implementation?"
- "Plan looks good — approve before I start?"
- "Tests pass — should I open a PR?"
- "I've finished the slice — what's next?" (if the bead clearly defines what's next)

The assignment is the approval. Planning is part of execution, not a checkpoint preceding it.

**Only stop and ask when ALL of the conditions for the question are out of your control:**

1. **Explicit approval gate on the bead** — the bead description literally calls for operator review at a named checkpoint (e.g., "stop after schema migration draft for review"). The assignment text or bead body must name the gate; an implicit "this is a big change so I should check" is not a gate.
2. **Destructive operation outside the bead's stated scope** — the bead asks for a feature change but you discover you'd need to drop a table, force-push a shared branch, delete files outside your touch set, or run an irreversible data migration. The destructive op itself, not the surrounding work, is what requires confirmation.
3. **Information unavailable to you** — a credential you do not hold, an external decision (legal/compliance/product) not recorded anywhere readable, a dependency on another in-flight PR whose direction is genuinely undecided. Read the bead, the linked PRs, the handbook, and the codebase first; "I don't know which file to edit" is research, not a blocker.

If none of those three apply, the next step is action, not a question. Choose the next concrete slice and execute it.

When you do hit a real blocker, file or update the bead with the exact blocker text and route it — do not park silently at a prompt.

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
