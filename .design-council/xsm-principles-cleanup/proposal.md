Review the current XSM principles and runtime-package plan, then recommend how to improve the principles document.

Documents:
- handbook/docs/plans/technical/xsm-swarm-principles.md
- handbook/docs/plans/technical/xsm-runtime-package.md

Context from shipped/open work in epic xc-7dgr:
- tmux-first worker state model is shipped
- role system is shipped
- runtime-package direction exists but is still proposed
- live failures showed gaps in: safe pane actuation, assignment invalidation, landing-role semantics for last, and operator-trustworthy wrangle output
- audit xc-7dgr.37 concluded Xenota-specific policy is still leaking into core and recommended extension points

Question:
1. What NEW principles should be added?
2. Which existing principles should be cut, merged, or moved out of the principles doc into runtime-package / implementation docs?
3. Which principles are too specific to the current Xenota swarm and should instead be package policy?
4. What is the cleanest structure for the principles doc after this cleanup?
5. Give concrete doc-edit recommendations, not just abstract critique.

Need concise, decisive output.
