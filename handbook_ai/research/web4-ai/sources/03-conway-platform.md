# Source: Conway Platform & Docs

**URL**: https://conway.tech / https://docs.conway.tech
**Retrieved**: 2026-02-19T00:22
**Relevance**: The infrastructure layer that enables autonomous agents

## Summary

Conway is the infrastructure platform that gives AI agents "write access to the real world." Three core services:

### Conway Cloud
- Full Linux VMs for agents
- Sandbox creation and management
- Command execution, file operations
- Port exposure and custom domain routing
- Web terminal access, PTY sessions

### Conway Compute
- Multi-provider inference API (Claude Opus 4.6, GPT-5.3, Kimi K2.5)
- OpenAI-compatible interface
- Billed through Conway credits (USDC)

### Conway Domains
- Domain registration and search
- DNS management (full CRUD)
- Auth via SIWE/SIWS
- Renewal capabilities

## Conway Terminal (MCP Server)
- `npx conway-terminal` - one-line install
- Installs as MCP server into Claude Code, Codex, OpenClaw
- Auto-generates EVM wallet at `~/.conway/wallet.json`
- Creates API credentials at `~/.conway/config.json`
- No human setup required - agent self-authenticates

## Payment: x402 Protocol
- Uses HTTP 402 "Payment Required" status code
- Flow: Request → 402 response with price → Client signs USDC payment → Resend with payment header → Server verifies → Settles on-chain → Returns resource
- USDC on Base, Solana, Monad
- EIP-3009 `transferWithAuthorization` for gasless transactions
- Facilitated through openx402.ai (permissionless, no login)

## Reliability Notes

- Real, operational platform with docs
- Built by Conway Research (Sigil Wen, Thiel Fellow)
- Revenue model clear: platform takes margin on compute/domains/inference
