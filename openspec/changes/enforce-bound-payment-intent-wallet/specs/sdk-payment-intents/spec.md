## ADDED Requirements
### Requirement: Point Authorization Holder Consistency

The SDK SHALL derive point authorization identity from the PaymentIntent's canonical point holder context and SHALL reject submission of an authorization signed for a different payer before making an HTTP request.

Canonical holder resolution SHALL be `points.authorization.holder_address ?? payer_address`. The SDK SHALL NOT use legacy `payer.address` as authorization identity.

#### Scenario: Authorization payer matches canonical holder

- **GIVEN** a PaymentIntent whose canonical point authorization holder is Wallet A
- **WHEN** the SDK builds and submits point authorization for Wallet A
- **THEN** the EIP-712 payer SHALL be Wallet A
- **AND** the SDK SHALL continue through normal action validation and submission

#### Scenario: Authorization payer differs from canonical holder

- **GIVEN** a PaymentIntent whose canonical point authorization holder is Wallet A
- **AND** a point authorization whose payer is Wallet B
- **WHEN** the integrating app calls `applyPoints`
- **THEN** the SDK SHALL fail locally with `POINT_AUTHORIZATION_HOLDER_MISMATCH`
- **AND** SHALL NOT make an HTTP request

### Requirement: Backend-Owned Payment Sender Verification

The SDK SHALL NOT treat app runtime wallet state or proof payer context as verified on-chain sender identity.

#### Scenario: Submit post-broadcast proof

- **GIVEN** the wallet app has an on-chain transaction hash
- **WHEN** it calls `provePayment`
- **THEN** the SDK SHALL submit the hash through the backend-provided action URL
- **AND** the backend SHALL remain responsible for verifying ERC-20 `Transfer.from` before settlement

### Requirement: Viewer Account Is Not Authorization Identity

The SDK SHALL preserve `points.account` as viewer context and `points.authorization` as persisted authorization context without deriving one from the other.

#### Scenario: Wallet B views Wallet A's bound intent

- **GIVEN** Wallet A is the persisted point authorization holder
- **WHEN** the app fetches the PaymentIntent with `payerAddress` equal to Wallet B
- **THEN** the SDK SHALL expose Wallet B under `points.account`
- **AND** SHALL retain Wallet A under `points.authorization` and legacy `payer`
- **AND** SHALL continue deriving point authorization identity from Wallet A

#### Scenario: Canonical top-level payer without points authorization

- **GIVEN** canonical `points.authorization` is absent
- **AND** top-level `payer_address` identifies Wallet A
- **WHEN** the SDK builds point authorization using the legacy point amount projection
- **THEN** the EIP-712 payer SHALL be Wallet A

#### Scenario: Legacy payer is not identity fallback

- **GIVEN** canonical `points.authorization` and top-level `payer_address` are absent
- **AND** legacy `payer.address` identifies Wallet A
- **WHEN** the SDK attempts to build point authorization
- **THEN** it SHALL fail locally with `PAYER_REQUIRED`
