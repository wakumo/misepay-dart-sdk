## ADDED Requirements

### Requirement: PaymentIntent Fetch

The SDK SHALL fetch MisePay PaymentIntent payloads from a request URI and optionally add payer context.

#### Scenario: Fetch without payer
- **WHEN** the app calls `getPaymentIntent` with only `requestUri`
- **THEN** the SDK SHALL GET that exact URI
- **AND** parse the response into a PaymentIntent object

#### Scenario: Fetch with payer
- **WHEN** the app calls `getPaymentIntent` with `requestUri` and `payerAddress`
- **THEN** the SDK SHALL add or replace the `payer_address` query parameter
- **AND** preserve other query parameters

### Requirement: Point Authorization Typed Data

The SDK SHALL build EIP-712 point authorization typed data locally from a PaymentIntent object and selected point amount.

#### Scenario: Build valid point authorization
- **WHEN** the app selects a point amount within limits
- **THEN** the SDK SHALL return `PaymentIntentPointAuthorization` typed data binding intent id, payer, gross amount, point amount, net amount, and expiry

#### Scenario: Reject invalid point authorization inputs
- **WHEN** payer context is missing, point amount is negative, above max, unchanged, or exceeds gross amount
- **THEN** the SDK SHALL throw a typed SDK exception before requesting a signature

### Requirement: Action URL Submission

The SDK SHALL use PaymentIntent action URLs for follow-up calls.

#### Scenario: Submit point authorization
- **WHEN** the app submits a signature for a point authorization
- **THEN** the SDK SHALL POST to `actions.submit_point_authorization`
- **AND** include payer address, point amount, and signature
- **AND** parse the updated PaymentIntent response

#### Scenario: Submit transaction hash
- **WHEN** the app submits a transaction hash
- **THEN** the SDK SHALL POST to `actions.submit_payment_proof`
- **AND** include chain id, token address, and transaction hash
- **AND** parse the updated PaymentIntent response
