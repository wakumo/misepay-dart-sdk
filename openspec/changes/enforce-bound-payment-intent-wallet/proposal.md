---
change_type: hybrid
priority: high
dependencies:
  - update-payment-intent-sdk-contract
references:
  - lib/src/payment_intents/payment_intents_client.dart
  - lib/src/payment_intents/services/point_authorization_service.dart
  - ../aim-api/openspec/changes/enforce-single-payer-payment-intent
---
# Change: Validate PaymentIntent Point Authorization Holder

**Change Type**: hybrid

## Why

The Avacus wallet SDK already builds EIP-712 point authorization with a payer address derived from PaymentIntent point context. Passing separate connected-wallet runtime state duplicates that identity and does not prove the eventual on-chain sender.

## What Changes

- Do not require `connectedWalletAddress` in `authorizePoints`, `applyPoints`, or `provePayment`.
- Derive the EIP-712 payer from canonical `points.authorization.holder_address`, with legacy `payer.address` only as a compatibility fallback.
- Before HTTP submission, reject a point authorization whose payer differs from the PaymentIntent holder.
- Leave proof sender verification to the API's verified ERC-20 `Transfer.from` processing.
- Keep cancellation and PaymentIntent creation outside the public SDK.

## Acceptance Criteria

- Point authorization construction uses the PaymentIntent's canonical holder context without separate wallet state.
- `applyPoints` fails locally with `POINT_AUTHORIZATION_HOLDER_MISMATCH` when the authorization payer differs from the canonical holder and makes no HTTP request.
- `provePayment` submits only the transaction hash and optional rendering context; it does not claim to validate the sender locally.
- The SDK exposes no cancellation or PaymentIntent creation method.

## Out of Scope

- Staff cancellation or PaymentIntent creation APIs and UI.
- Client-side verification of an on-chain transaction sender.
- Split payment, sponsored payment, or payer handoff.

## Impact

- Affected specs: `sdk-payment-intents`
- Affected code: PaymentIntent client, tests, README, and payload-format documentation
- Companion change: `../aim-api/openspec/changes/enforce-single-payer-payment-intent`
