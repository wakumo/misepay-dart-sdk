## Implementation Tasks

- [x] Implement public SDK models for PaymentIntent payloads, actions, point state, amount summary, and payment options (verification: unit - JSON parsing tests cover full response and missing optional payer).
- [x] Implement `MisePayClient.getPaymentIntent` using the exact request URI and optional `payer_address` query handling (verification: unit - mock HTTP tests cover no payer, append payer, replace existing payer, and preserve existing query params).
- [x] Implement local EIP-712 `PaymentIntentPointAuthorization` construction (verification: unit - typed data test asserts exact domain, primary type, fields, and message values).
- [x] Implement point amount validation before typed data construction (verification: unit - tests reject missing payer, negative amount, amount above max, unchanged amount, and amount greater than gross).
- [x] Implement `submitPointAuthorization` using `actions.submit_point_authorization` (verification: unit - mock HTTP test asserts absolute action URL usage and request body fields).
- [x] Implement `submitTransactionHash` using `actions.submit_payment_proof` (verification: unit - mock HTTP test asserts absolute action URL usage and chain/token/tx body fields).
- [x] Export the public API from `lib/misepay_sdk.dart` and document usage in `README.md` (verification: manual - README example compiles against public API names).
- [x] Run final verification (verification: manual - `dart test`, `dart analyze`, `dart format --output=none --set-exit-if-changed .`).

## Final Validation

Expected OpenSpec validation before archival: `openspec validate add-payment-intent-sdk --strict`.
