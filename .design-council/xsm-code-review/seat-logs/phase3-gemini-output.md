# Phase 3 (Simplify) — Gemini (Execution Pragmatist)
**Model**: gemini-3.1-pro-preview
**Quality notes**: Most aggressive cuts. Proposes 12K→4.5K source, 17K→5K tests. Specific state mapping, function assignments, dead config identification.

## Key Proposals
- Delete visualize.py + audit.py (-900 LOC) — UI bloat, SQLite+WAL replaces custom audit
- Collapse 17 states → 8: STARTING, RUNNING, IDLE, HANDOFF, BLOCKED, UNKNOWN, STOPPED, FAILED
- Delete 5 dead strategy configs: FormulasConfig, LifecycleConfig, WorkerContractConfig, DetectionConfig, IncidentsConfig
- Delete 8K lines of low-value tests (test_main, test_tui_classification, test_recovery_drill, test_installer, test_uninstaller)
- Split main.py into cli.py + orchestrator.py + session.py with exact function assignments
- Target: 4.5K source, 5K tests

## Process Observations
- Gemini tried to use tools (run_shell_command) but failed — didn't affect quality
- Boldest cuts of all seats — willing to say "delete audit.py" which others wouldn't
- State mapping is concrete and defensible
- Dead config identification is useful but needs verification against source
- 30-day plan is a full lockdown — ambitious but clear
