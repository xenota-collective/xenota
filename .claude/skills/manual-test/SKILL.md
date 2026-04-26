---
name: manual-test
description: Execute a manual test plan and record a structured receipt on the bead and in the runtime state.
---

# Manual Test

Use this skill when you are assigned to a `manual_qa` role for a bead.

## Startup

1.  Check the bead for a linked manual test plan (usually in `_ai/manual-tests/`).
2.  If no plan exists, identify the key scenarios based on the bead's AC.
3.  Ensure you have the implementation commit checked out in your worktree.

## Execution

1.  Run the scenarios.
2.  Record all commands, environment setup, and artifacts produced.
3.  Note any regressions or unexpected behavior.

## Recording Verdict

You MUST record the verdict in two places.

### 1. Runtime state

Run the `xsm worker-qa-verdict` command. The supervisor uses this to unlock the next stage.

```bash
xsm worker-qa-verdict \
  --status <pass | fail> \
  --tester "<your_name>" \
  --scenarios "<brief_summary_of_scenarios>" \
  --sources "<commits_or_pr_reviewed>" \
  --notes "<reproduction_steps_if_fail_or_other_notes>"
```

### 2. Bead comment

Post a comment on the bead with the same data for permanent record.

```
manual_qa_receipt: <pass | fail>
tester: <your_name>
scenarios: <brief_summary_of_scenarios>
sources: <commits_or_pr_reviewed>
notes: <reproduction_steps_if_fail_or_other_notes>
```

## Hard Boundaries

- **Do not commit code.** If you find a bug, record it and report it as a failure.
- **Do not skip the command.** The supervisor cannot advance the pipeline without the runtime state record.
- **Be thorough.** Manual QA is the final gate before review and landing.
