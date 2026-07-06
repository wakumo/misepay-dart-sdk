---
change_type: implementation
priority: high
dependencies: []
references:
  - https://github.com/wakumo/aim-api/issues/218
  - docs/payment-intent-sdk-payload-format.md
---

# Change: Add PaymentIntent SDK

**Change Type**: implementation

## Problem / Context

Avacus app needs a Dart SDK that can consume MisePay PaymentIntent request URIs, expose a typed PaymentIntent domain object, build EIP-712 point authorization payloads locally, submit signed point authorizations, and submit transaction hashes for payment proof acceleration.

The SDK must be environment-safe: the first fetch uses `requestUri`, while follow-up calls use absolute `actions` URLs returned by the API. The SDK must not hardcode or compose backend base URLs for dev, staging, or production.

## Proposed Solution

- Add a Flutter-independent Dart package named `misepay_sdk`.
- Implement `MisePayClient.getPaymentIntent({requestUri, payerAddress})`.
- Parse PaymentIntent response models, including payer point state, amount summary, payment options, actions, and expiry.
- Implement `PaymentIntent.buildPointAuthorization({pointAmount})` to build EIP-712 typed data locally without calling a quote endpoint.
- Implement `PaymentIntent.submitPointAuthorization({authorization, signature})` using `actions.submit_point_authorization`.
- Implement `PaymentIntent.submitTransactionHash({chainId, tokenAddress, txHash})` using `actions.submit_payment_proof`.
- Use string amounts only; do not use floating point for money, points, or token amounts.

## Acceptance Criteria

- SDK fetches the exact `requestUri` when `payerAddress` is omitted.
- SDK appends or replaces `payer_address` query parameter when `payerAddress` is provided, while preserving existing query params.
- SDK parses the PaymentIntent JSON contract into typed Dart models.
- SDK builds `PaymentIntentPointAuthorization` EIP-712 typed data with intent id, payer, gross amount, point amount, net amount, and PaymentIntent expiry timestamp.
- SDK rejects point authorization building when payer data is missing, point amount is negative, point amount exceeds max, point amount equals current applied amount, or net amount would be negative.
- SDK submits point authorization to `actions.submit_point_authorization` and returns the updated PaymentIntent.
- SDK submits transaction hash to `actions.submit_payment_proof` with chain id, token address, and tx hash, and returns the updated PaymentIntent.
- SDK never composes follow-up endpoint URLs from `requestUri`.

## Explicit Completion Conditions

- Public library exports `MisePayClient`, `PaymentIntent`, model classes, and EIP-712 authorization classes.
- Tests cover request URI payer query behavior, JSON parsing, EIP-712 typed data construction, validation failures, action URL usage, point authorization submit body, and transaction hash submit body.
- `dart test`, `dart analyze`, and `dart format --output=none --set-exit-if-changed .` pass.

## Out Of Scope

- Flutter UI widgets.
- Wallet/signature implementation.
- ERC20 transaction sending.
- Backend API implementation.
- Multi-token FX quote logic.
