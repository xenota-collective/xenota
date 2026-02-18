# Source: x402 Codebase Analysis

**URL**: https://github.com/coinbase/x402 (local at /Users/jv/gt/x402/crew/xenota-life/)
**Retrieved**: 2026-02-19T01:00
**Relevance**: Implementation internals for xenon integration

## Key Implementation Details

### Architecture: 3-Layer Separation

```
Transport Layer (HTTP, MCP, A2A) — independent of payment logic
Scheme Layer (exact, upto, deferred) — how money moves
Network Layer (EVM, Solana) — blockchain execution
```

This is cleanly extensible — new transports, schemes, and networks can be added independently.

### MCP Transport (Critical for Xenon Integration)

x402 already defines MCP-native payment flow:

**402 in MCP tool result:**
```json
{
  "isError": true,
  "structuredContent": {PaymentRequired},
  "content": [{"type": "text", "text": "{...PaymentRequired JSON}"}]
}
```

**Payment in MCP tool call:**
```json
{
  "params": {
    "name": "tool_name",
    "arguments": {...},
    "_meta": {
      "x402/payment": {PaymentPayload}
    }
  }
}
```

**Settlement in MCP result:**
```json
{
  "_meta": {
    "x402/payment-response": {SettlementResponse}
  }
}
```

This means an MCP projection can use x402 natively within the MCP protocol — no HTTP layer needed for the payment flow.

### Python SDK Structure

```python
# Client side (xenon paying for things)
class ExactEvmScheme:
    def create_payment_payload(self, requirements) -> dict

# Server side (xenon selling services)
class ExactEvmServerScheme:
    def parse_price(self, price, network) -> AssetAmount
    def enhance_payment_requirements(self, requirements, ...) -> requirements

# MCP client (automatic payment on tool calls)
class x402MCPClient:
    async def callTool(self, name, arguments) -> result  # auto-pays if 402
```

### Express Middleware Pattern (Response Buffering)

The middleware uses a response buffering strategy:
1. Intercept response from handler
2. Buffer all writes
3. If handler returns success: settle payment FIRST, then flush buffer
4. If handler returns error: flush buffer as-is (no payment)

This ensures payment only settles when the service actually succeeds.

### EIP-712 Signing (Exact Details)

```python
domain = {
    "name": extra["name"],           # "USDC" (from payment requirements)
    "version": extra["version"],     # "2"
    "chainId": chain_id,             # extracted from CAIP-2 network string
    "verifyingContract": asset       # USDC contract address
}

types = {
    "TransferWithAuthorization": [
        {"name": "from", "type": "address"},
        {"name": "to", "type": "address"},
        {"name": "value", "type": "uint256"},
        {"name": "validAfter", "type": "uint256"},
        {"name": "validBefore", "type": "uint256"},
        {"name": "nonce", "type": "bytes32"}
    ]
}

message = {
    "from": payer_address,
    "to": payTo,
    "value": amount,
    "validAfter": now - 600,          # 10min clock skew tolerance
    "validBefore": now + timeout,
    "nonce": random_32_bytes()
}
```

### Extensibility: Bazaar Extension

The codebase includes a "bazaar" extension for resource discovery — services can register themselves with metadata (category, provider) making them discoverable by agents. This aligns with the xenon service publishing concept.

### Payment Scheme Types

- `exact` — Fixed amount, fully implemented
- `upto` — Variable/metered (spec exists, implementation in progress)
- `deferred` — Batch settlement via Cloudflare (spec exists)

### Infinite Loop Prevention

Client wrapper checks if `PAYMENT-SIGNATURE` header already present before retrying — prevents infinite payment loops on broken servers.

## Integration Implications for Xenota

1. **Python SDK exists** — xenon nucleus/projections are Python, so direct integration is possible
2. **MCP transport is native** — the MCP projection plan aligns perfectly; x402 payments flow through MCP `_meta` fields
3. **Response buffering pattern** — useful for the MCP projection's paid tools implementation
4. **Bazaar extension** — could serve as the xenon service discovery mechanism
5. **`eth_account` for signing** — standard Python library, fits into existing xenon key management
