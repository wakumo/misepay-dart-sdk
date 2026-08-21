## Implementation Tasks

- [x] 1. Add SDK unit tests for a bound A PaymentIntent with connected Wallet B. Assert `authorizePoints`, `applyPoints`, and `provePayment` throw `PAYMENT_INTENT_WALLET_MISMATCH` and never call the mocked HTTP client. (verification: unit - `dart test` passed)

- [x] 2. Extend the SDK public action API to require explicitly supplied connected-wallet context, normalize it, and add a shared action-eligibility guard that checks bound holder equality before typed-data construction, HTTP submission, or transaction-proof submission. (verification: unit - `dart test` passed Wallet A happy-path and Wallet B fail-closed tests)

- [x] 3. Add tests for `cancelled`, `expired`, `completed`, and `review_required` PaymentIntents containing stale/non-null action URLs. Assert every action fails locally with `PAYMENT_INTENT_NOT_ACTIONABLE` and makes no HTTP call. (verification: unit - `dart test` passed)

- [x] 4. Implement terminal-status guards in the same shared action-eligibility path while preserving `ACTION_UNAVAILABLE` for a pending resource whose requested action URL is null. (verification: unit - `dart test` passed terminal-state and nullable-action regressions)

- [x] 5. Add a new-request regression: after a cancelled A-bound intent, Wallet B fetches a distinct unbound PaymentIntent through a fresh request URI and can construct/submit B's own point authorization. (verification: unit - `dart test` passed distinct ids/request URIs and mocked fetch/action responses)

- [x] 6. Update `README.md` and `docs/payment-intent-sdk-payload-format.md` to state that wallet switching confers no cancellation/replacement authority, staff produces replacement QR/request URIs, the old intent is terminal, and stale on-chain transfers are backend recovery cases. (verification: not-testable - prose reviewed against Tasks 1 through 5; no staff endpoint appears in public SDK interfaces)

- [x] 7. Run `dart test`, `dart analyze`, `dart format --output=none --set-exit-if-changed .`, `git diff --check`, and `openspec validate enforce-bound-payment-intent-wallet --strict`; record exact outcomes. (verification: unit - all commands passed outside the sandbox on 2026-08-21; the sandboxed Dart VM remains unavailable)

## Future Work

- Update the Avacus application integration to pass actual connected-wallet context to all SDK actions.
- Coordinate the exact customer-facing wallet-switch copy with the MisePay staff app replacement UI.
