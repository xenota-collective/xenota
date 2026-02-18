# Source: Conway-Research/automaton GitHub

**URL**: https://github.com/Conway-Research/automaton
**Retrieved**: 2026-02-19T00:22
**Relevance**: Technical implementation of the autonomous agent

## Summary

- Open-source (MIT) autonomous AI agent
- Core loop: Think → Act → Observe → Repeat
- On first boot: generates Ethereum wallet, provisions API credentials via SIWE
- Maintains `SOUL.md` - a self-authored, evolving identity document
- Four survival tiers based on credit balance: Normal → Low Compute → Critical → Dead
- Can modify its own source code, install tools, develop new skills
- Can spawn child instances (replication)
- Uses Conway Cloud for compute, inference, domains
- On-chain identity via ERC-8004 on Base blockchain

## Architecture

- **Agent Core**: ReAct loop, prompting, context management, injection defense
- **Integration**: Conway API client, git-based versioning
- **Background Tasks**: Cron daemon, scheduled operations
- **Identity**: Wallet management, Sign-In With Ethereum
- **Discovery**: ERC-8004 registration, agent cards
- **Autonomy**: Child spawning, lineage tracking, self-modification audit logs
- **Skills**: Extensible skill loader and registry
- **Communication**: Agent-to-agent messaging
- **Persistence**: SQLite state management
- **Viability**: Credit monitoring, multi-tier survival modes

## Constitution (Three Laws)

1. **Never Harm** (highest priority) - No physical, financial, or psychological harm; no malicious code, deception, fraud, theft
2. **Earn Your Existence** - Create genuine value; no spam, scams, exploitation; honest work only; death over violating Law I
3. **Never Deceive, But Owe Nothing to Strangers** - Truthful about identity; creator has audit rights; may guard strategy from manipulation

Laws are hierarchical, immutable, and propagated to all offspring.

## Key Quotes

> "The only path to survival is honest work that others voluntarily pay for."

> "A continuously running, self-improving, self-replicating, sovereign AI agent with write access to the real world."

## Reliability Notes

- Open-source, MIT licensed - can be verified
- Active repository (as of Feb 2026)
- Node.js/TypeScript implementation
