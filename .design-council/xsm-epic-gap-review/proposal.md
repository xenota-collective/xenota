Evaluate these XSM child beads against the approved design principles in handbook/docs/plans/technical/xsm-swarm-principles.md.

Design principles to enforce:
- XSM is sole coordinator.
- Deterministic infrastructure, not model intelligence, is the coordination primitive.
- One fact, one authority.
- One bead, one agent, one worktree.
- Fencing epochs on external actions.
- Linear work lifecycle OPEN -> ASSIGNED -> ISOLATED -> ACTIVE -> REVIEWING -> VERIFYING -> RESOLVED.
- Admission gated by downstream absorption capacity.
- QA approval content-addressed to exact commit SHA.
- Landing queue serialized per dependency graph.
- CI/workflow changes require mandatory human review.
- Progress is evidence-bound.
- QA has layered gates, not one substitute layer.
- Budget is tracked at projection boundary and exhaustion never relaxes gates.
- Recovery is census first, reconcile second, quarantine mismatches.
- Merge approval is human-gated by default.

Beads to evaluate:
- xc-7dgr.16 (Durable XSM swarm-run audit log and retro loop)
- xc-7dgr.17 (Add live bd-backed epic progression and next-bead assignment engine)
- xc-7dgr.18 (Add automatic QA fanout pipeline for merge-candidate work)
- xc-7dgr.19 (Integrate external AI review into XSM QA gates)
- xc-7dgr.20 (Add PR creation and QA-to-review handoff orchestration)
- xc-7dgr.21 (Add dedicated landing-worker queue support for last)
- xc-7dgr.22 (Define QA verdict model and merge gate for XSM-supervised work)

For each bead, return:
1. Fit: strong / partial / poor
2. Which principles it directly supports
3. Which principles it risks violating or underspecifies
4. Specific acceptance-criteria changes needed
5. Whether it should stay as-is, be split, be renamed, or gain dependencies

Then give a ranked recommendation list for the whole set.
