# Phase 1 Comparative Analysis — Council Skill Meta-Review

## Role Fit (did they play the assigned role?)
| Seat | Role | Fit | Notes |
|------|------|-----|-------|
| Codex | Systems Critic | **A** | Read actual source files, found real bugs. Identified structural flaws with precision. |
| Claude | Safety Auditor | **A+** | Perfect role execution. Never drifted. Found the canonical abuse path. |
| Gemini | Execution Pragmatist | **A** | Stayed pragmatic. Bold recommendations (delete files, collapse states). |

## Specificity (file:line citations)
| Seat | Citation Quality | Count |
|------|-----------------|-------|
| Codex | **Best** — real line numbers from actual file reads | 40+ citations |
| Claude | **Very good** — precise file:line references | 30+ citations |
| Gemini | **None** — file names only, no line numbers | 0 line citations |

## Actionability
| Seat | Quality | Style |
|------|---------|-------|
| Codex | **High** — 5 MUST-level spec changes, each concrete | Fix-oriented |
| Claude | **Very high** — 8 numbered guardrails, each implementable | Guardrail-oriented |
| Gemini | **High** — 4 concrete cuts (delete release.py, delete hooks.py, split main.py, collapse states) | Cut-oriented |

## Novel Insights (things only one seat caught)
| Seat | Unique Finding |
|------|----------------|
| Codex | assignment_epoch propagated but not enforced in safety checks |
| Codex | Split-brain "safe for actuation, unsafe for persistence" |
| Claude | Zero shell=True audit (positive finding) |
| Claude | Clock skew in cooldown timing |
| Claude | Config-writable command execution via backend_command |
| Claude | QA operator override accountability gap |
| Gemini | Closed-loop actuation verification missing (fire-and-hope) |
| Gemini | State explosion: 17 states should collapse to 8 |

## Grading Spread
| Seat | Harshest | Most Generous | Range |
|------|----------|---------------|-------|
| Codex | C- (P6) | B+ (T6) | Narrow — consistent B-/C+ |
| Claude | B- (T6,T8) | A (P1,P2,T1,T3) | Wide — gives A's and B-'s |
| Gemini | F (P1,T3,T7,T9) | A (P3,P7,T1,T6) | Widest — polarized |

## Best Model for Each Seat Type
- **Systems Critic**: Codex with source access. It READS the code. The 347K tokens are expensive but it catches things the others can't because it verifies claims against actual implementation. No other model did this.
- **Safety Auditor**: Claude Opus. Perfect role discipline, found the canonical abuse path, provided actionable guardrails. The most structured output.
- **Execution Pragmatist**: Gemini. Bold, opinionated, willing to say "delete it." The harshest grader — which is exactly what a pragmatist should be.

## Process Improvements for Council Skill
1. **Claude -p needs session capture** — use `--output-file` or tee for replayable logs
2. **Codex output extraction is messy** — 1.5MB output with interleaved exec blocks; need better extraction logic
3. **Gemini needs code access** — it graded without reading source, leading to some uninformed grades (T3:F when Claude who read the code gave T3:A)
4. **Grade calibration**: Consider providing a rubric with concrete thresholds for each letter grade
5. **Cross-seat visibility**: Phase 2+ prompts should include the other seats' Phase 1 grades so they can respond to disagreements
