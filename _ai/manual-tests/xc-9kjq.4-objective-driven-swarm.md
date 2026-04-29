# MT-OBJ-001: Objective-Driven Swarm Operation

## Category
objectives, xsm-cli

## Prerequisites
- XSM CLI available in `xenon/packages/xsm`.
- Seed data in `xenon/packages/xsm/src/xsm/objectives.yaml`.

## Steps
1. **List Objectives**:
   Run `uv run xsm objectives list --config <config>`.
   Verify the three seeded objectives are listed.

2. **Show Objective Details**:
   Run `uv run xsm objectives show obj-objective-driven-swarms --config <config>`.
   Verify the intent, status, and decomposition are displayed correctly.

3. **Add Audit Log Entry**:
   Run `uv run xsm objectives audit-add obj-objective-driven-swarms --config <config> --lane supervisor --decision continue --rationale "Manual QA in progress" --next-action "Verify completion evaluation"`.
   Verify the entry is added to the audit log in `show`.

4. **Evaluate Completion (Negative)**:
   Run `uv run xsm objectives evaluate obj-objective-driven-swarms --config <config> --lane supervisor --evidence "receipt-1"`.
   Verify decision is `continue` and missing receipts are listed.

5. **Evaluate Completion (Positive)**:
   Run `uv run xsm objectives evaluate obj-objective-driven-swarms --config <config> --lane supervisor --evidence "swarm-objectives.md status promoted from design-draft to design-approved" --evidence "bd:xc-9kjq.1 closed (this contract landed and reviewed)" --evidence "bd:xc-9kjq.2 closed (patrol loop running)" --evidence "bd:xc-9kjq.3 closed (completion evaluator running)" --evidence "bd:xc-9kjq.4 closed (manual QA passed)" --apply`.
   Verify decision is `complete`, result is applied, and status changes to `complete`.

6. **Evaluate Metric (Stable)**:
   Run `uv run xsm objectives evaluate obj-test-pass-rate --config <config> --lane supervisor --metrics-json '{"ci_pass_rate": 0.98}' --apply`.
   Verify decision is `stable_long_lived` and status is updated.

7. **Evaluate Metric (Regression)**:
   Run `uv run xsm objectives evaluate obj-test-pass-rate --config <config> --lane supervisor --metrics-json '{"ci_pass_rate": 0.85}' --apply`.
   Verify decision is `regression`, rationale mentions threshold violation, and status changes to `gated`.

## Expected Results
- All commands execute without errors.
- Status transitions and audit logs persist in `objectives.yaml`.
- CLI output matches the logic of the evaluator.
