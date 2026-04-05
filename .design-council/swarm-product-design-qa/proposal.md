We need to improve three functions in the Xenota swarm operating model:

1. Product / planning
Current problem: work gets created and assigned, but the swarm lacks a strong product-owner function that shapes epics into dependency-safe, testable, operator-visible slices before implementation begins. This leads to unclear sequencing, stale beads, and implementation starting before the path to QA/landing is designed.

2. Technical design before dev
Current problem: design decisions are often implicit in bead text or worker reasoning. The swarm needs a lightweight but real pre-dev design check so implementation does not begin before key architecture constraints, state-machine impacts, authority boundaries, and rollout risks are checked.

3. QA / acceptance
Current problem: coding completion is too often treated as the end state. The swarm needs a formal acceptance function covering static review, automated tests, manual testing, external model spot-checks, and merge-readiness, with explicit pass/fail routing.

Context from approved XSM principles:
- XSM is the sole coordinator.
- Deterministic infrastructure, not model intelligence, is the coordination primitive.
- One fact, one authority.
- Linear bead lifecycle OPEN -> ASSIGNED -> ISOLATED -> ACTIVE -> REVIEWING -> VERIFYING -> RESOLVED.
- Admission gated by downstream absorption capacity.
- QA approval is content-addressed to exact commit SHA.
- Landing queue serialized per dependency graph.
- CI/workflow changes require mandatory human review.
- Progress is evidence-bound.
- QA has layered gates.
- Merge policy is human-gated by default.

Ask:
Design a minimal but strong swarm process that covers:
- product planning and bead shaping before implementation
- technical design review/check before dev starts
- QA/acceptance workflow before PR merge
- explicit roles/lane ownership
- state transitions and handoff gates
- what should be deterministic vs model-assisted
- what artifacts must exist at each gate
- where human approval is mandatory

Return:
1. Recommended operating model
2. Required roles and responsibilities
3. Required artifacts per phase
4. State machine / gate model
5. Failure modes and anti-patterns to avoid
6. Minimal first implementation plan for Xenota
