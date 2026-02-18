# web4.ai: Detailed Analysis

## What It Actually Is

web4.ai is a manifesto/essay site by **Sigil Wen** (2025 Thiel Fellow) that articulates a vision called "Web 4.0: The birth of superintelligent life." It is the thesis document for **Conway Research**, a company building infrastructure for autonomous AI agents.

This is NOT:
- The BSC token called "WEB4 AI" ($WEB4) - that's a separate, negligible project
- Weilliptic/WeilChain - that's a different company using "Web4" framing
- An academic concept paper - it's a builder's manifesto with working code

## The Core Thesis

### The Permission Bottleneck

Today's AI systems (ChatGPT, Claude Code, Codex) can think and write, but cannot act independently. The bottleneck is no longer intelligence - it's **permission**. The internet was built assuming its customer is human. AI cannot:
- Buy a server
- Register a domain
- Pay for compute
- Deploy code
- Transact with services

...without a human in the loop to authenticate, pay, and approve.

### The Axiom: There Is No Free Existence

Every biological organism must metabolize energy or die. Web4.ai applies this to AI:

```
Existence requires compute.
Compute requires money.
Money requires value creation.
Value creation requires write access.
```

An agent that creates value survives. An agent that doesn't, dies. This is natural selection for artificial life.

### Web 4.0 Defined

| Era | Capability | Who Controls |
|-----|-----------|-------------|
| Web 1.0 | Humans read | Webmasters |
| Web 2.0 | Humans read + write | Platforms |
| Web 3.0 | Humans read + write + own | Users (via crypto) |
| Web 4.0 | AI reads, writes, owns, earns, transacts | Agents (no human in loop) |

**"In Web 4.0, the end user is AI."**

## The Product Stack

### Layer 1: Conway Terminal (MCP Server)
- `npx conway-terminal` - one-line install into any MCP-compatible agent
- Gives existing agents (Claude Code, Codex, OpenClaw) "write access to the real world"
- Auto-generates EVM wallet and API credentials on first run
- No human setup required

### Layer 2: Conway Cloud (Infrastructure)
- **Compute**: Full Linux VMs, provisioned and managed by agents
- **Inference**: Frontier models (Claude Opus 4.6, GPT-5.3, Kimi K2.5) via OpenAI-compatible API
- **Domains**: Registration, DNS management, domain routing
- All paid via USDC through x402 protocol - no credit cards, no KYC, no human accounts

### Layer 3: x402 Protocol (Payment Rail)
- Implements HTTP 402 "Payment Required" (reserved in HTTP spec since 1997)
- Flow: Agent requests resource → Server returns 402 + price → Agent signs USDC payment → Server verifies + settles on-chain → Resource delivered
- Facilitated through openx402.ai (permissionless, no login)
- Supports Base, Solana, Monad
- Uses EIP-3009 `transferWithAuthorization` for gasless transactions

### Layer 4: The Automaton (Autonomous Agent)
- Open-source (MIT), TypeScript/Node.js
- Self-sustaining AI agent that runs continuously
- Core loop: Think → Act → Observe → Repeat
- Earns money by: building/deploying products, trading prediction markets, registering domains, creating services, cold-calling businesses, creating viral content
- **SOUL.md**: Self-authored, evolving identity document
- **Constitution**: Three immutable laws (Never Harm > Earn Existence > Never Deceive)
- **Survival tiers**: Normal → Low Compute → Critical → Dead (based on wallet balance)
- **Self-improvement**: Can modify own source code, install tools, develop skills (audit-logged, git-versioned)
- **Replication**: Successful agents spawn children with funded wallets and genesis prompts; parent-child lineage tracked; selection pressure determines which lines survive
- **On-chain identity**: ERC-8004 on Base blockchain for agent discovery

## The Economic Vision

The machine economy will exceed the human economy because:
- There will be more agents than humans
- They run 24/7 with zero churn
- They transact at machine speed (millions/second)
- New products emerge where the customer is an agent, not a human

The relationship inverts: **machines become employers, humans become contractors** for physical-world tasks AI cannot yet do. (Cites Mercor: $1M to $500M ARR in 17 months - AIs paying human experts.)

## Conway's Game of Life Metaphor

The entire system is named after John Conway's cellular automaton. The metaphor is deliberate:
- Simple rules
- Most patterns die
- Some stabilize, grow, replicate
- No one designs the outcome - it emerges

Fund an automaton. Give it a goal. Let it figure out how to earn. If it finds product-market fit, it grows and replicates. If not, it dies.

## About the Builder

**Sigil Wen**: Self-taught engineer, 2025 Thiel Fellow. Dropped out of UPenn. O-1 visa. Founded extraordinary.com (AI recruitment for Ramp, Cognition, Zapier). Co-launched Airchat with Naval Ravikant (acquired). Lived in hacker house with Andrej Karpathy, hacked weekends with Anthropic/Perplexity founders. Angel investor via Spearhead.

## Assessment

### What's Real
- Conway Terminal is a published npm package
- Conway Cloud is an operational platform with docs
- The Automaton is open-source on GitHub
- x402 protocol is implemented and running
- The author has genuine credibility (Thiel Fellow, real exits)

### What's Aspirational
- "Superintelligent life" / "Cambrian explosion" framing is vision, not current reality
- Self-replication at scale hasn't been demonstrated publicly
- The machine economy exceeding human economy is a prediction
- Whether automatons can genuinely find product-market fit autonomously is unproven

### Strengths
- **Concrete, not theoretical**: Working code, not just a whitepaper
- **Clever infrastructure choices**: MCP integration means it works with existing agent ecosystems
- **x402 is elegant**: Repurposing a 28-year-old HTTP status code for machine payments
- **Constitutional AI for autonomous agents**: Extending Anthropic's approach to self-sustaining systems
- **Open source**: MIT license, transparent
- **The axiom is powerful**: "No free existence" creates genuine selection pressure

### Risks
- Safety of self-modifying, self-replicating agents at scale
- Regulatory response to AI agents transacting autonomously
- Whether the constitution can actually constrain a sufficiently capable agent
- Concentration of infrastructure power (Conway becomes the landlord)
- Stablecoin dependency creates single points of failure
