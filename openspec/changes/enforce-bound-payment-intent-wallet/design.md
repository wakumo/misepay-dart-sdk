## Context
The SDK is used by the Avacus customer wallet. `points.authorization.holder_address` is canonical point-holder context, while `payer` is a legacy compatibility projection. The EIP-712 point authorization itself contains the payer address. A post-broadcast proof contains a transaction hash, so sender identity can only be established from verified chain data.

## Decisions

### Use signed authorization identity

`authorizePoints` delegates to `PointAuthorizationService`, which derives the EIP-712 payer from `points.authorization.holder_address ?? payer_address`. `applyPoints` compares the resulting authorization payer to the same holder context before sending HTTP and returns `POINT_AUTHORIZATION_HOLDER_MISMATCH` on inconsistency. Legacy `payer.address` is display-only and is not an identity fallback.

No `connectedWalletAddress` parameter is needed. It would be duplicated app runtime state rather than an independent security boundary.

### Keep payment proof verification backend-owned

`provePayment` forwards the transaction hash and optional payer rendering context. It does not validate wallet binding because it has no verified `Transfer.from`. The API scanner/proof worker remains authoritative.

### Keep viewer account separate from authorization

`payerAddress` remains the SDK parameter for requesting point-account viewer context. When B fetches an A-bound PaymentIntent, `points.account` represents B while `points.authorization` and legacy `payer` remain A. The SDK preserves these fields as returned and does not treat the account snapshot as authorization identity.

### Keep terminal actions resource-driven

The SDK uses backend-provided nullable action URLs. A terminal or otherwise unavailable action has no URL and returns the existing `ACTION_UNAVAILABLE` error. The wallet app may also disable UI based on status, but that UI state is not represented as a second SDK identity guard.

## Risks / Trade-offs

- A caller can manually construct inconsistent authorization data, so `applyPoints` checks holder consistency before HTTP; the backend still performs authoritative signature and state validation.
- Older payloads missing both canonical authorization and top-level `payer_address` cannot build or submit point authorization, even if legacy `payer.address` is present.
