# MisePay Dart SDK

Dart SDK for MisePay PaymentIntent checkout flows.

The first implementation targets Avacus app integration and stays Flutter-independent. Apps provide the selected payer address and signer; the SDK fetches PaymentIntent state, builds EIP-712 point authorization typed data, submits signed point authorizations, and submits transaction hashes for optional payment proof acceleration.

See `docs/payment-intent-sdk-payload-format.md` for the contract used by both the MisePay backend and this SDK.
