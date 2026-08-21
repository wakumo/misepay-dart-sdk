---
change_type: hybrid
priority: high
dependencies:
  - update-payment-intent-sdk-contract
references:
  - lib/src/payment_intents/payment_intents_client.dart
  - lib/src/payment_intents/data/payment_intent_api.dart
  - lib/src/payment_intents/domain/payment_intent.dart
  - ../aim-api/openspec/changes/enforce-single-payer-payment-intent
---

# Change: Enforce Bound PaymentIntent Wallet Use

**Change Type**: hybrid

## Why

The Avacus DeFi Wallet SDK currently consumes public PaymentIntent resources. Product policy requires one payer per point-backed payment attempt: after Wallet A authorizes points, Wallet B must not use the old discounted payment instruction, mutate A's reservation, or infer authority to cancel/reissue the PaymentIntent.

Staff replacement is a MisePay staff-app workflow, not an SDK capability. The SDK must fail closed on a wallet mismatch or terminal/cancelled resource and direct the integrating app to obtain a fresh staff-created request URI before another payment attempt.

## What Changes

- Add explicit SDK guards that allow point authorization and token-payment proof only when the connected wallet equals the PaymentIntent's bound point holder, if one exists.
- Reject a Wallet B attempt to pay or apply points on Wallet A's bound PaymentIntent before signing, broadcasting, or calling an action URL.
- Treat `cancelled`, `expired`, `completed`, and `review_required` PaymentIntents as non-actionable. A cancelled old QR must not be reused for point authorization or payment proof.
- Document that the SDK cannot cancel, replace, or create PaymentIntents and that a wallet switch requires a fresh `request_uri` from the MisePay staff app.
- Preserve the API contract distinction between point holder and verified chain sender; sender verification remains backend-owned.

## Acceptance Criteria

- When A is the bound holder and A is the connected wallet, SDK point authorization and proof submission retain normal behavior.
- When B is connected to an A-bound PaymentIntent, `authorizePoints`, `applyPoints`, and `provePayment` fail locally with a stable wallet-mismatch error before an HTTP request or wallet transaction is initiated.
- The SDK never calls a staff-only replacement endpoint and exposes no method to cancel, release points, rebind a payer, or create a replacement PaymentIntent.
- When the old request returns `cancelled`, its action URLs remain unavailable and SDK actions fail locally without network calls even if an integrating app retained the prior object.
- The integrating app must fetch a new staff-provided request URI and treats it as a distinct PaymentIntent. The new intent remains unbound until B explicitly authorizes B's own points.
- SDK docs clearly state that a normal ERC-20 transfer to an old QR cannot be prevented by the SDK and must not be retried/aggregated automatically.

## Explicit Completion Conditions

- SDK domain/client methods accept explicit connected-wallet context for action eligibility or equivalent validated API that does not infer a wallet from `payer` response data.
- Unit tests prove no `http.Client.post` is called for Wallet B mismatch and for each terminal intent status.
- Unit tests prove a new unbound PaymentIntent with a fresh request URI remains usable by B, including B's own point authorization flow.
- README and payload-format documentation describe staff authority and replacement flow without suggesting an SDK cancellation feature.
- `dart test`, `dart analyze`, `dart format --output=none --set-exit-if-changed .`, `git diff --check`, and strict OpenSpec validation record truthful results.

## Out of Scope

- Staff authentication, staff replacement API calls, or MisePay staff UI.
- Sender verification, settlement classification, refunds, or recovery of a late on-chain transfer.
- Split payment, sponsored payment, payer handoff, and use of another wallet's points.

## Impact

- Affected specs: `sdk-payment-intents`
- Affected code: PaymentIntent domain/client/repository API, exception types, SDK tests and docs
- Companion change: `../aim-api/openspec/changes/enforce-single-payer-payment-intent`
