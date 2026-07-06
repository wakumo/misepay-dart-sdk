# Project Context

## Purpose

`misepay-dart-sdk` provides a Dart SDK for MisePay PaymentIntent checkout flows. It is used by Flutter apps but should keep the core SDK Flutter-independent.

## Conventions

- Keep public API small and explicit.
- Use string amounts for points, JPY display amounts, and ERC20 base-unit token amounts.
- Use `requestUri` for initial PaymentIntent fetch.
- Use response `actions` URLs for follow-up API calls.
- Do not compose follow-up paths from `requestUri`.
- Keep EIP-712 typed data construction deterministic and test-covered.

## Verification

- `dart test`
- `dart analyze`
- `dart format --output=none --set-exit-if-changed .`
