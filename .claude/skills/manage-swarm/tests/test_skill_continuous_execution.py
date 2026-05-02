"""xc-z123: assert worker dispatch template + start-feature skill carry the
continuous-execution rule that prevents workers from stopping at routine
'Ready to proceed?' prompts between phases."""

import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
MANAGE_SWARM_SKILL = REPO_ROOT / ".claude" / "skills" / "manage-swarm" / "SKILL.md"
START_FEATURE_SKILL = REPO_ROOT / ".claude" / "skills" / "start-feature" / "SKILL.md"


class ManageSwarmDispatchTemplate(unittest.TestCase):
    """The dispatch template at section 'Preferred wording (via helper)' is the
    canonical worker assignment text. It must explicitly tell workers to keep
    moving through plan -> implement -> test -> PR without pausing for
    operator confirmation between phases."""

    @classmethod
    def setUpClass(cls):
        cls.text = MANAGE_SWARM_SKILL.read_text(encoding="utf-8")
        # Isolate the preferred-wording dispatch block so we don't accidentally
        # match the same phrases elsewhere in the file.
        marker = "Preferred wording (via helper):"
        idx = cls.text.find(marker)
        assert idx != -1, "manage-swarm SKILL.md missing 'Preferred wording' section"
        # Take the next ~3000 chars; the block is a single fenced code sample.
        cls.dispatch_block = cls.text[idx : idx + 3000]

    def test_dispatch_template_forbids_proceed_prompt(self):
        # Worker must not pause to ask 'Ready to proceed?' between phases.
        self.assertIn("Ready to proceed?", self.dispatch_block)
        self.assertIn("do NOT pause", self.dispatch_block)

    def test_dispatch_template_names_the_continuous_phase_chain(self):
        # The template must spell out plan -> implement -> test -> PR so the
        # worker treats them as one assignment rather than four.
        self.assertIn("Plan, implement, test, and PR continuously", self.dispatch_block)

    def test_dispatch_template_states_the_assignment_is_the_approval(self):
        self.assertIn("the assignment is the approval", self.dispatch_block)

    def test_dispatch_template_lists_the_only_legitimate_stop_conditions(self):
        # Real blocker, destructive op outside scope, named approval gate.
        self.assertIn("real blocker", self.dispatch_block)
        self.assertIn("destructive operation outside the bead scope", self.dispatch_block)
        self.assertIn("explicit approval gate named on the bead", self.dispatch_block)


class StartFeatureContinuousExecution(unittest.TestCase):
    """start-feature is the skill workers read FIRST when they pick up a bead
    (per the dispatch template). Its hard rules and Continuous Execution
    section define the contract a worker is expected to follow when no
    operator is in the loop."""

    @classmethod
    def setUpClass(cls):
        cls.text = START_FEATURE_SKILL.read_text(encoding="utf-8")

    def test_hard_rule_5_calls_out_continuous_execution(self):
        # Hard Rules section is the eye-catching contract; rule 5 must
        # explicitly forbid pausing between phases.
        self.assertIn("Execute continuously through plan", self.text)
        self.assertIn("Ready to proceed?", self.text)

    def test_continuous_execution_section_exists(self):
        self.assertIn("## Continuous Execution", self.text)

    def test_continuous_execution_lists_forbidden_questions(self):
        # Workers were observed asking these literal questions and parking.
        # Pinning them as forbidden examples keeps the contract concrete.
        forbidden = [
            "Ready to proceed?",
            "Should I continue with implementation?",
            "Approve plan?",
        ]
        for question in forbidden:
            with self.subTest(question=question):
                self.assertIn(question, self.text)

    def test_continuous_execution_names_three_legitimate_stop_conditions(self):
        # The bead AC (xc-z123) restricts legitimate stops to: explicit
        # approval gate on the bead, destructive operation, or unavailable
        # information. The skill must name all three so the worker can
        # judge edge cases.
        self.assertIn("Explicit approval gate on the bead", self.text)
        self.assertIn("Destructive operation outside the bead", self.text)
        self.assertIn("Information unavailable to you", self.text)

    def test_continuous_execution_says_assignment_is_the_approval(self):
        self.assertIn("The assignment is the approval", self.text)


if __name__ == "__main__":
    unittest.main()
