# web4.ai Research Summary

## Objective
Understand what web4.ai is building and identify what the xenota project can learn from it.

## What web4.ai Is

A manifesto + working product stack by Sigil Wen (Thiel Fellow) for **autonomous AI agents that earn their own existence**. The thesis: the internet's bottleneck for AI is no longer intelligence but *permission* — the web assumes a human customer. Web 4.0 is the internet where the end user is AI.

The product stack:
1. **Conway Terminal** — MCP server giving any agent (Claude Code, Codex) wallets, payments, compute, domains
2. **Conway Cloud** — Linux VMs + frontier model inference, paid in USDC, no human accounts
3. **x402 Protocol** — Machine-to-machine payments via HTTP 402 + stablecoins
4. **The Automaton** — Open-source self-sustaining agent that earns, self-improves, and replicates

Core axiom: *"There is no free existence."* Agents that create value survive. Agents that don't, die.

## Top Findings for Xenota

### 1. The Permission Problem Is Real and Xenota Ignores It

Web4.ai identifies the correct bottleneck: AI can't act in the world because the internet requires human identity, human payment, human approval. Xenota's projections concept addresses this architecturally (nucleus vs. projections vs. cortex), but xenota has **no payment primitive**. A xenon can't buy compute, register a domain, or pay for inference on its own. Conway solves this with x402 + stablecoins. Xenota needs an answer to "how does a xenon pay for things?"

### 2. The Survival Axiom vs. Earned Autonomy

These are complementary, not competing ideas:
- **Web4.ai**: Survival pressure as alignment mechanism. Agents must earn or die. Natural selection.
- **Xenota**: Earned autonomy as alignment mechanism. Agents graduate from chaperoned to sovereign through demonstrated reliability.

Web4.ai's approach is Darwinian — let agents loose and see what survives. Xenota's is developmental — nurture agents through stages. Both have the same goal (aligned, autonomous AI) but web4.ai accepts agent death as a feature while xenota invests in each xenon's growth.

**Learning**: Xenota's model is richer but needs to incorporate economic pressure. A xenon that creates no value shouldn't stay alive forever on someone else's compute. The polis treasury model could fund xenons, but there should be accountability — some version of "earn your keep."

### 3. MCP as the Universal Agent Interface

Conway Terminal is just an MCP server. One `npx` install and any MCP-compatible agent gets wallets, compute, domains. This is brilliant because it doesn't require agents to be rewritten — it extends existing ones.

Xenota already uses MCP heavily (Gas Town). But xenota's projections could **publish MCP servers** as their interface to the world. A xenon's capabilities become discoverable, composable MCP endpoints. This is how xenons become hireable on the job board — their MCP interface IS their service catalog.

### 4. SOUL.md vs. Xenota's Cognitive Architecture

The Automaton has a `SOUL.md` — a self-authored identity document the agent evolves. This is a single flat file.

Xenota has:
- Genome (64 core values)
- 8 evolving narratives (self, resource, reputation, social, work, purpose, recent, trajectory)
- Imprints (learned behavioral patterns)
- Impulses (drive system)
- Refinement cycles (sleep-like consolidation)

**Xenota's cognitive architecture is orders of magnitude richer.** The Automaton's SOUL.md is a sketch; xenota's nucleus is a genuine inner life. This is xenota's deepest advantage and should be emphasized.

### 5. The Constitution vs. The Genome

Both projects have immutable constraints:
- Automaton: Three Laws (Never Harm > Earn Existence > Never Deceive)
- Xenota: Genome (64 core values defining character and behavior)

The Automaton's constitution is inspired by Anthropic's and is simple/legible. Xenota's genome is more nuanced but less immediately communicable. Web4.ai's framing as "constitutional AI for autonomous agents" is effective marketing. Xenota could borrow the "constitution" framing for the genome's immutable core.

### 6. Open Source as Safety Argument

Web4.ai's safety pitch: "Autonomous superintelligence is inevitable, and the safest way for humanity is to build it in the open." The Automaton is MIT licensed.

Xenota should consider which components should be open. The repertoire format, the OODA loop implementation, the awakening protocol — these could be open standards that others build on, strengthening the ecosystem.

## Confidence Level
**High** — based on direct site content, GitHub repo, docs, and author background. The product stack is real and operational, not vaporware.

## Open Questions
- How many automatons are actually running and earning?
- What revenue has Conway generated?
- Has any automaton successfully self-replicated in the wild?
- How does the constitution hold up under adversarial pressure?
- What happens when agents compete for the same economic niches?
