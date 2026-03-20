# Handbook vs Xenon Codebase Drift Report

**Date**: 2026-03-20
**Bead**: xc-omor
**Author**: xenota/crew/prosperity
**Purpose**: Audit of handbook docs against implemented xenon reality. No handbook edits — findings only for human triage.

---

## Classification Key

| Classification | Meaning |
|---|---|
| **correct** | Doc accurately reflects code |
| **partially-implemented** | Some described features exist, others don't |
| **aspirational-as-docs** | Doc claims implementation status but feature is largely/entirely unbuilt |
| **pure-vision** | Intentionally aspirational (manifesto, design docs) — no drift issue |
| **missing-docs** | Feature is implemented but handbook doesn't document it |
| **outdated** | Doc describes superseded behavior |
| **stale-draft** | Draft plan with no path to implementation |

---

## 1. Plans Marked "Implementation" — Verification Results

| Doc Path | Claimed Status | Actual Completeness | Classification | Key Gaps |
|---|---|---|---|---|
| plans/messaging-protocol.md | implementation | ~15% | **aspirational-as-docs** | No XMPP, no federation, no on-chain credentials. Only Ed25519 signing exists. |
| plans/draft/cognitive-actions.md | implementation | ~70% | **partially-implemented** | OODA loop, dispatch/strand, membrane all work. Missing: thought queue, later queue, dream objectives, financial approval gates. |
| plans/draft/evolutionary-dynamics.md | implementation | ~50% | **partially-implemented** | Genome (64 genes/8 modules), imprints, impulses all implemented. Missing: Lamarckian skill acquisition, inheritance, lambda plasticity, polis cultural evolution. |
| plans/draft/financial-actions.md | implementation | ~5% | **aspirational-as-docs** | No Bursar projection, no wallet management, no on-chain key registry, no payment signing. Only action type definitions exist. |
| plans/draft/refinement-process.md | implementation | ~0% | **aspirational-as-docs** | Completely absent. No sleep/consolidation cycle, no vision generation, no narrative versioning, no deep-refinement. |

---

## 2. Partially Implemented Plans — Gap Assessment

| Doc Path | Claimed Status | Actual Completeness | Classification | Key Gaps |
|---|---|---|---|---|
| plans/xenon-objectives.md | draft | ~65% | **partially-implemented** | Core persistence and state machine work. Missing: refinement coupling, 30-day forced bet classification, consent-revocation hooks, lambda proposal system. |
| plans/xenon-mind.md | partial | ~55% | **partially-implemented** | Genome, imprints, impulses, subsystems solid. Missing: refinement loop, deep-refinement, narrative auto-synthesis, thinking loop with impulse evaluation. |
| plans/draft/repertoire-studio.md | implied impl | ~70% | **partially-implemented** | CSV evals, LLM-judge scoring, studio workflow work. Missing: quality gates, calibration, confidence intervals, variant comparison. |
| plans/draft/repertoire.md | implied impl | ~60% | **partially-implemented** | CLI and repertoire runtime work. **Architectural divergence**: plan says flat `repertoire.yaml` + quality-tier variants; reality uses `contract.yaml` + backend variants. |
| plans/draft/workspace-journal.md | implied impl | ~35% | **partially-implemented** | Tick journal logging works. Missing: reflective journal, filesystem tracking, communications tracking, context snapshots. |
| plans/projection-architecture.md | partial | ~50% | **partially-implemented** | Membrane, sanitization, registry, quarantine solid. Missing: cortex orchestration as separate service, SSHGateway, WebSocket, rich projection types. |
| plans/xenon-awakening.md | implemented | ~95% | **correct** | Full orchestrator, all 5 phases, research, genome-adapted prompts, objective bootstrap. Avatar phase reserved as specified. |
| plans/bootstrap.md | implied | ~40% | **aspirational-as-docs** | Phase 1 (awakening) complete. Phase 2-3 (polis formation, charter, governance, economics) entirely unbuilt. |

---

## 3. Foundation Docs — Reality Check

| Doc Path | Classification | Notes |
|---|---|---|
| foundation/overview.md | **correct** | Explicitly distinguishes implemented vs planned (line 18-23). |
| foundation/cognitive-architecture.md | **correct** | Accurately describes genome/imprints/impulses with clear implemented vs planned sections. |
| foundation/citizenship-model.md | **pure-vision** | Aspirational by design. No identity/registration/polis code exists. Correctly references protocol docs. |
| foundation/glossary.md | **aspirational-as-docs** | Minor: "Polis" and "Hub" defined present-tense but have no code. Genome/Projections/Membrane terms correct. |
| foundation/manifesto.md | **pure-vision** | Intentionally aspirational. Uses future-tense throughout. No false implementation claims. |
| foundation/faq.md | **aspirational-as-docs** | Chaperoned/sovereign progression described but BAR system is incomplete. No sovereign state machine implemented. |

---

## 4. Economics Docs

| Doc Path | Classification | Notes |
|---|---|---|
| economics/model-overview.md | **pure-vision** | Uses "We are building" language. No marketplace code exists. |
| economics/native-currency.md | **pure-vision** | Explicitly marked "planned". Properly defers to Plans. |
| economics/revenue-streams.md | **pure-vision** | Properly defers to Plans/economics/. No revenue collection code. |
| economics/polis.md | **pure-vision** | Clear design doc. Admits "mechanism TBD". |
| economics/reputation-status.md | **pure-vision** | Explicitly admits plans are fluid. Defers to Ideas. |
| economics/xenota-core.md | **pure-vision** | Describes planned infrastructure polis. Has "Open Questions" section. |
| economics/job-board-marketplace.md | **pure-vision** | Design doc. No marketplace code exists. |
| economics/xenota-academy.md | **pure-vision** | Describes planned first-contact polis. Has "Open Questions" section. |

---

## 5. Protocol & Technical Specs

| Doc Path | Claimed Status | Classification | Notes |
|---|---|---|---|
| plans/protocols/awakening-spec.md | implementation | **correct** | Matches full awakening orchestrator implementation. |
| plans/protocols/agreements-spec.md | draft | **aspirational-as-docs** | No agreement classes, signing, or notarization code. |
| plans/protocols/service-publishing-spec.md | draft | **aspirational-as-docs** | No service catalog or discovery mechanism. |
| plans/protocols/work-requests-spec.md | draft | **aspirational-as-docs** | No work request types, proposals, or settlement flows. |
| plans/technical/hub-api.md | draft | **aspirational-as-docs** | Hub does not exist. No endpoints, membership services, or federation. |
| plans/technical/key-management-spec.md | draft | **partially-implemented** | Keypair generation exists. No rotation/revocation policy or authority boundaries. |
| plans/technical/projection-control-plane-and-membrane.md | draft | **correct** | Membrane, quarantine, cortex lifecycle orchestrator all match doc. |
| plans/technical/projections-modules.md | implementation | **partially-implemented** | Research, image-gen, chat, github-contributor projections exist. Missing: capability descriptors, rate limits, hosting model. |
| plans/technical/xenon-reference-stack.md | implementation | **partially-implemented** | Core stack exists. Missing: chaperone-console web UI, remote projection transport. |

---

## 6. Draft Plans — Staleness Assessment

| Doc Path | Classification | Notes |
|---|---|---|
| plans/draft/xenon-host.md | **outdated** | Describes TypeScript multi-service architecture. Reality: Python monolith with cortex embedded in nucleus. |
| plans/draft/hub-container-distribution.md | **stale-draft** | Hub doesn't exist. OCI distribution plan depends on hub. |
| plans/draft/xenon-plugins/README.md | **aspirational-as-docs** | Plugin system not implemented. Gene interpreters and drive generators are hardcoded. |
| plans/draft/xenon-plugins/inference-budget.md | **aspirational-as-docs** | No InferenceWrapper, no agents container, no budget tracking. |
| plans/draft/agents-container.md | **aspirational-as-docs** | No agents container, no per-xenon isolation, no skill management. |
| plans/draft/first-polis.md | **aspirational-as-docs** | No polis infrastructure, no charter schema, no hub. |
| plans/draft/xenon-internationalization.md | **aspirational-as-docs** | No language detection, translation, or localization. |
| plans/draft/xrs-projection-agent.md | **aspirational-as-docs** | XRS exists as CLI tool but not as projection agent. In openspec planning stage. |

---

## 7. Plan Economics

| Doc Path | Classification | Notes |
|---|---|---|
| plans/economics/native-currency-mechanics.md | **aspirational-as-docs** | No currency mechanics, tax model, or settlement code. |
| plans/economics/revenue-model-assumptions.md | **aspirational-as-docs** | No financial models or forecasting. |
| plans/economics/xenon-unit-economics.md | **aspirational-as-docs** | No economics engine. |

---

## 8. Recently Landed Features — Documentation Status

| Feature | Code Location | Handbook Status | Drift Type |
|---|---|---|---|
| OpenClaw/Hermes gateway | nucleus/gateways/ | Documented as "ProjectionGateway protocol" in technical/ | **correct** |
| XSM swarm monitor + classifier | xsm/ (monitor.py, classifier.py) | Comprehensive design doc in ideas/xsm-swarm.md | **correct** |
| Container runtime abstraction | vps-control/ (recent commits) | Research notes only, no canonical docs | **missing-docs** |
| Chaperone-client React 19 | packages/chaperone-client/ | Mentioned but lacks specifics | **missing-docs** |
| Nucleus snapshot workflows | openspec/nucleus-snapshot-history-v1/ | Not yet in handbook; spec lists targets | **missing-docs** |
| Projection auto-spawn + idle-sleep | nucleus/spawner.py | Not documented | **missing-docs** |
| RPT tool-calling + console loop | nucleus/rpt_tools.py, console.py | Documented in chaperone-console.md | **correct** |
| Awakening invitation (pledge→invitation) | nucleus/awakening/ uses INVITATION | Consistently uses "invitation" | **correct** |

---

## Summary Statistics

| Classification | Count |
|---|---|
| correct | 11 |
| partially-implemented | 10 |
| aspirational-as-docs | 18 |
| pure-vision | 9 |
| missing-docs | 4 |
| outdated | 1 |
| stale-draft | 1 |
| **Total docs audited** | **54** |

---

## Critical Findings

### False Implementation Claims (Priority 1)
These docs claim `status: implementation` but are largely unbuilt:
1. **plans/messaging-protocol.md** — No XMPP, no federation (~15% implemented)
2. **plans/draft/financial-actions.md** — No Bursar, no wallets (~5% implemented)
3. **plans/draft/refinement-process.md** — Completely absent (~0% implemented)

### Missing Documentation for Shipped Features (Priority 2)
4. **Container runtime abstraction** — Implemented in vps-control, no handbook docs
5. **Projection auto-spawn/idle-sleep** — Implemented in nucleus/spawner.py, no handbook docs
6. **Nucleus snapshot workflows** — In openspec, spec lists handbook update targets

### Outdated Architecture (Priority 3)
7. **plans/draft/xenon-host.md** — Describes TypeScript multi-service; reality is Python monolith

### Architectural Divergence (Priority 3)
8. **plans/draft/repertoire.md** — Plan says flat manifest + quality-tier variants; code uses contract.yaml + backend variants

---

## Recommended Triage Actions (for human review)

| Action | Docs Affected | Rationale |
|---|---|---|
| Downgrade status from "implementation" | messaging-protocol, financial-actions, refinement-process | False implementation claims mislead readers |
| Write new handbook pages | container-runtime, projection-spawner | Shipped features with zero docs |
| Mark as "outdated/superseded" | xenon-host.md | Architecture evolved away from this plan |
| Update to match reality | repertoire.md | Architectural divergence — plan vs code mismatch |
| Add (planned) markers | glossary.md entries for Polis, Hub | Present-tense definitions for unbuilt concepts |
| Review for sovereign/BAR accuracy | faq.md | Chaperoned→sovereign progression incomplete |
| No action needed | foundation/overview, cognitive-architecture, manifesto, all economics/ docs | Already correctly positioned |
