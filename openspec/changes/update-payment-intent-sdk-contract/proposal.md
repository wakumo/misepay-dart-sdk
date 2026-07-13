# Change: Update PaymentIntent SDK contract hardening

## Why

The PaymentIntent SDK needs to match the clarified POC contract for Avacus checkout: trusted entrypoint handling, environment-separated point authorization signatures, nullable follow-up actions, stable backend error handling, and chain display data.

## What Changes

- Validate `requestUri` origins from trusted app/build settings; validate origin only, not path.
- Support permissive origin mode for dev/stg/local builds.
- Add EIP-712 domain `salt` from trusted app/build settings.
- Model `actions.*` as nullable and fail locally with `ACTION_UNAVAILABLE` when absent.
- Preserve machine-readable backend error codes in SDK exceptions.
- Add `payment_options[].chain_name` support.
- Update docs/tests for point identity and settlement separation.

## Impact

- Affected specs: payment-intent-sdk
- Affected code: `lib/src/misepay_client.dart`, `lib/src/payment_intents/**`, `lib/src/core/**`, `test/misepay_client_test.dart`, SDK docs
