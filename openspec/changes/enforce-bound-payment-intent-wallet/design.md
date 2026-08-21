## Context

The SDK is used by Avacus DeFi Wallet, a customer wallet application. It reads public PaymentIntent resources and builds/submits customer point authorization or post-broadcast proof actions. It is not authenticated as merchant staff and must never mutate a merchant payment request.

The API returns `points.authorization.holder_address` as canonical point-holder context. `payer` is a legacy compatibility projection only. The connected wallet is app-owned runtime state and must be supplied explicitly to SDK action calls. It must not be inferred from the resource or a caller-provided proof payload.

## Decisions

### Guard before all customer actions

Introduce one internal eligibility guard used by `authorizePoints`, `applyPoints`, and `provePayment`:

```text
terminal PaymentIntent -> PAYMENT_INTENT_NOT_ACTIONABLE
bound holder differs from connected wallet -> PAYMENT_INTENT_WALLET_MISMATCH
otherwise -> continue with current validation/action
```

The guard receives the explicitly connected wallet address, normalizes/checks it, and compares it to `paymentIntent.points?.authorization?.holderAddress`; it falls back to `paymentIntent.payer?.address` only while older API responses remain in circulation. An unbound intent remains eligible for B to inspect and use according to current point authorization rules.

The guard does not claim that connected wallet identity proves the on-chain sender. The API still verifies the eventual ERC-20 `Transfer.from` before settlement.

### Cancelled QR is terminal

The API's nullable action URLs are the source of truth for terminal status. The SDK also checks the enum before using a retained `PaymentIntent` object so an old QR cannot submit stale actions if malformed or cached payloads contain action URLs. No action request is sent for terminal status.

### Replacement begins with a new request URI

The SDK provides no replacement function. The staff app may cancel/reissue separately. The integrating app discards its old PaymentIntent action state, obtains the new request URI from staff display/QR, then calls `get(requestUri: ...)`. The new resource has a distinct id and starts unbound. It is not B-bound merely because B scanned it.

## Risks / Trade-offs

- Requiring connected-wallet context is a public SDK API change. It is necessary because the SDK otherwise cannot distinguish A from B safely. Version/documentation changes must make the migration explicit.
- A normal external wallet can still transfer to an old ERC-20 QR. SDK prevention avoids induced stale submissions but cannot block the chain transfer; backend recovery policy owns it.

## Rollout

1. Publish API replacement and terminal-state contract.
2. Publish SDK guard update.
3. Update Avacus wallet integration to pass the currently connected wallet to SDK actions and refetch only staff-issued replacement request URIs.
