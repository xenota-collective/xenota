---
name: update-handbook
description: Update the Xenota handbook to reflect recent implemented changes in the xenon codebase. Use when auditing whether landed behavior needs handbook updates, when preparing handbook sync proposals after code changes, or when moving content from plans into current technical docs after implementation.
---

# Update Handbook

Use this skill when a landed or landing code change may require handbook updates.

This is a project skill for syncing `handbook/` to implemented `xenon/` reality. It is not for speculative design writing.

## Core Boundary

The handbook has a strict content lifecycle:

- `ideas/`: raw brainstorming and early exploration
- `plans/`: designs that are planned but not yet implemented
- `foundation/`, `economics/`, `technical/`, `protocols/`, `guides/`, `branding/`: current implemented reality only

Rules:

- Do not document unimplemented behavior in technical docs.
- Keep docs high-level and human-readable. Explain what a system does and why it exists, not code snippets or API signatures.
- Move content forward through the lifecycle when implementation lands.
- If implementation is partial, document only the parts that are real now.

## Mandatory Approval Gate

The proposal step is a hard stop.

- You may inspect `xenon/` and prepare handbook diffs locally.
- You must present the exact proposed handbook edits before applying them.
- You must not commit or push handbook changes until the human explicitly approves after seeing the proposal.
- Earlier generic instructions like "do it" do not count as approval for handbook edits.

Also follow the repo rule in `AGENTS.md`:

- local handbook edits are allowed for review prep
- committing or pushing `handbook/` changes requires explicit human approval in the current session

## Workflow

### 1. Pull

Refresh the relevant repos before diffing:

```bash
git -C xenon pull --rebase
git -C handbook pull --rebase
```

If the top repo needs submodule alignment, verify it separately:

```bash
git status
git submodule status
```

### 2. Diff Since Last Sync

Read the handbook sync marker:

```bash
cat handbook/_ai/sync-state.json
```

Identify the last synced `xenon` commit, then inspect what changed since then:

```bash
git -C xenon log --oneline <last_synced_commit>..HEAD
git -C xenon diff --stat <last_synced_commit>..HEAD
git -C xenon diff <last_synced_commit>..HEAD -- <relevant paths>
```

Focus on implemented behavior changes, operator-visible semantics, renamed concepts, new workflows, and anything that invalidates current handbook wording.

### 3. Audit Current Handbook

Check whether current docs already cover the landed behavior.

Useful targets:

- `handbook/docs/technical/`
- `handbook/docs/protocols/`
- `handbook/docs/guides/`
- `handbook/docs/plans/`

Questions to answer:

- Is the behavior already documented accurately?
- Is any current technical doc now stale or misleading?
- Does plan content need to move into technical docs because implementation landed?
- Is the change too small for handbook docs and better handled as no-op?

### 4. Propose Exact Edits

Before editing committed history, provide a concrete proposal with:

- the code change being documented
- the exact handbook files to update
- what each file needs to say differently
- whether any plan content should move to a current-reality section
- whether the correct result is "no handbook change needed"

Stop here until the human approves.

### 5. Apply Approved Changes

After approval, make only the approved `handbook/` edits.

Guidelines:

- keep prose concise
- document behavior and operator meaning, not implementation minutiae
- preserve the handbook’s current voice and structure
- do not silently expand scope beyond the approved proposal

### 6. Update Sync State

After the approved handbook update is complete, write the new synced `xenon` commit to:

```bash
handbook/_ai/sync-state.json
```

Use the exact `xenon` commit hash that the handbook now matches.

## Recommended Output Shape

When using this skill, structure the handoff like this:

1. `scope`: what landed in `xenon/` and what range was audited
2. `current coverage`: which handbook docs already cover it
3. `gaps`: exact stale or missing docs, if any
4. `proposal`: precise files and edits
5. `approval status`: waiting for approval, or approved and applied

## When No Change Is Needed

It is acceptable to conclude that no handbook update is required. If so, say so explicitly and justify it with file references and the current implemented-doc boundary.

## Quick Commands

```bash
cat handbook/_ai/sync-state.json
git -C xenon log --oneline <last_synced_commit>..HEAD
git -C xenon diff --stat <last_synced_commit>..HEAD
rg -n "<concept|endpoint|feature>" handbook/docs
git -C handbook status --short
```
