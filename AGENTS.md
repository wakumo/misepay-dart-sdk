# MisePay Dart SDK - Agent Guide

## Project Snapshot

- Dart package for the MisePay PaymentIntent SDK contract used by Flutter apps.
- Package name: `misepay_sdk`.
- Keep the core SDK Flutter-independent. Do not add Flutter-only dependencies unless explicitly requested.

## Commands

- Install dependencies: `dart pub get`
- Tests: `dart test`
- Analyze: `dart analyze`
- Format check: `dart format --output=none --set-exit-if-changed .`
- Format write: `dart format .`

## Code Style

- Prefer immutable value objects.
- Keep public models and SDK methods small and explicit.
- Do not hardcode MisePay environment base URLs. Use `requestUri` for the first fetch and response `actions` URLs for follow-up requests.
- Do not introduce Flutter UI code into this package.
- Use string amounts for money/points/token base units. Do not use floating point for financial values.

## Testing

- Add tests before implementation changes.
- Use mock HTTP clients for SDK tests.
- Cover URL construction, JSON parsing, EIP-712 payload construction, point validation, action URL usage, and submit payloads.
