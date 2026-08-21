## ADDED Requirements

### Requirement: Bound Wallet Action Eligibility

The SDK SHALL require explicit connected-wallet context before it builds point authorization, submits a point authorization, or submits a payment proof. When a PaymentIntent identifies a bound point holder, the SDK SHALL allow those actions only when the connected wallet equals that holder.

#### Scenario: Different connected wallet cannot act on bound intent

- **GIVEN** a PaymentIntent is bound to Wallet A by point authorization
- **AND** Wallet B is the explicitly supplied connected wallet
- **WHEN** the integrating app calls `authorizePoints`, `applyPoints`, or `provePayment`
- **THEN** the SDK SHALL fail locally with `PAYMENT_INTENT_WALLET_MISMATCH`
- **AND** SHALL NOT construct typed data, submit an HTTP request, or initiate a payment action

#### Scenario: Bound wallet continues its own payment attempt

- **GIVEN** a PaymentIntent is bound to Wallet A
- **AND** Wallet A is the explicitly supplied connected wallet
- **WHEN** the integrating app invokes an otherwise available PaymentIntent action
- **THEN** the SDK SHALL continue with existing action validation and submission behavior

#### Scenario: Replacement intent is a new unbound resource

- **GIVEN** a staff member has cancelled an A-bound PaymentIntent
- **AND** Wallet B obtains a fresh request URI for a distinct replacement PaymentIntent
- **WHEN** the SDK fetches the replacement
- **THEN** the SDK SHALL treat it as a new unbound payment attempt
- **AND** Wallet B MAY authorize B's own points only through the replacement's normal point authorization flow

### Requirement: Terminal PaymentIntent Action Safety

The SDK SHALL treat `completed`, `expired`, `cancelled`, and `review_required` PaymentIntents as non-actionable regardless of any stale action URL retained by a caller.

#### Scenario: Cancelled QR cannot submit stale actions

- **GIVEN** a PaymentIntent has status `cancelled`
- **WHEN** the integrating app attempts to authorize points, apply points, or submit a payment proof using that resource
- **THEN** the SDK SHALL fail locally with `PAYMENT_INTENT_NOT_ACTIONABLE`
- **AND** SHALL NOT make an HTTP request

#### Scenario: Pending resource with no action URL remains unavailable

- **GIVEN** a pending PaymentIntent has a null action URL for a requested action
- **WHEN** the integrating app invokes that action
- **THEN** the SDK SHALL fail locally with `ACTION_UNAVAILABLE`
