# Source: x402 Payment Protocol (Deep Technical)

**URL**: https://github.com/coinbase/x402, https://x402.org, https://docs.openx402.ai
**Retrieved**: 2026-02-19T00:35
**Relevance**: Core payment protocol for machine-to-machine transactions

## Summary

x402 is a **Coinbase-created open protocol** (Apache 2.0) that implements HTTP 402 "Payment Required" for native machine-to-machine payments using stablecoins. Launched May 2025, processing 100M+ payments by early 2026.

### HTTP Flow

```
Client → GET /resource → Server
Server → 402 + PAYMENT-REQUIRED header (base64 JSON with price, network, asset, payTo)
Client → Signs EIP-3009 transferWithAuthorization (EVM) or SPL TransferChecked (Solana)
Client → GET /resource + PAYMENT-SIGNATURE header → Server
Server → POST /verify to facilitator → valid?
Server → POST /settle to facilitator → on-chain settlement
Server → 200 + PAYMENT-RESPONSE header (txHash) → Client
```

### Payment Signing (EVM - EIP-3009)

- Client signs EIP-712 typed data authorizing USDC transfer
- Fields: from, to, value, validAfter, validBefore, nonce (random bytes32)
- Facilitator calls `transferWithAuthorization()` on USDC contract
- Client never pays gas - facilitator relays
- ~1.5-2s end-to-end on Base

### Payment Signing (Solana)

- Client creates SPL `TransferChecked` instruction
- Signs full transaction with keypair
- Facilitator submits to Solana network
- ~400ms settlement

### Facilitator API

- `POST /verify` - Validate payment without on-chain execution
- `POST /settle` - Submit transaction to blockchain
- `GET /supported` - List supported schemes/networks
- Known facilitators: x402.org (Coinbase), facilitator.openx402.ai (OpenX402)

### SDKs

| Package | Language | Purpose |
|---------|----------|---------|
| @x402/fetch | TypeScript | Wraps fetch with auto-402 handling |
| @x402/express | TypeScript | Express middleware for servers |
| @x402/core | TypeScript | Core types and utilities |
| @x402/evm | TypeScript | EVM signing/verification |
| @x402/svm | TypeScript | Solana signing/verification |
| x402 | Python | Official Python client |
| github.com/coinbase/x402/go | Go | Official Go client |

### Payment Schemes

- `exact` - Fixed amount (production)
- `upto` - Variable/consumption-based (planned)
- `deferred` - Batch settlement (Cloudflare extension)

### Networks (CAIP-2)

- Base: `eip155:8453`
- Base Sepolia: `eip155:84532`
- Solana mainnet: `solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp`
- Avalanche, IoTeX, Monad also supported

## Key Quotes

> "HTTP 402. Reserved 1997. Implemented 2025."

## Reliability Notes

- Coinbase-backed, Apache 2.0 licensed
- 100M+ payments processed
- x402 Foundation established with Cloudflare
- Multiple independent implementations (Coinbase, OpenX402, community)
- USDC dependency is intentional - Coinbase co-created both
