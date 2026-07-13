## ADDED Requirements

### Requirement: Trusted Request URI Origins

The SDK SHALL validate the origin of `requestUri` against built-in production defaults or trusted environment-specific app/build origin configuration before fetching a PaymentIntent, unless permissive origin mode is explicitly enabled by the integrating app.

#### Scenario: Built-in production origin accepted
- **WHEN** `MisePayClient()` fetches a `requestUri` from `https://apis.misepay.app`
- **THEN** the SDK fetches the PaymentIntent without requiring app-provided origin configuration

#### Scenario: Development origin accepted
- **WHEN** the SDK uses `MisePayEnv.development` and `requestUri` has an origin in `allowedOrigins`
- **THEN** the SDK fetches the PaymentIntent

#### Scenario: Untrusted origin rejected
- **WHEN** `requestUri` has an origin outside `allowedOrigins` and permissive origin mode is disabled
- **THEN** the SDK fails before making an HTTP request with `UNTRUSTED_REQUEST_ORIGIN`

#### Scenario: Dev permissive mode accepts any origin
- **WHEN** permissive origin mode is enabled
- **THEN** the SDK fetches the PaymentIntent without checking the origin allowlist

### Requirement: Environment-Separated Point Authorization Domain

The SDK SHALL include an EIP-712 domain `salt` derived from `MisePayEnv` for point authorization typed data, and SHALL NOT expose `domainSalt` as public app-provided configuration.

#### Scenario: Built-in salt included in typed data
- **WHEN** `MisePayClient()` builds a point authorization
- **THEN** the typed data domain includes `salt: misepay:prod`

#### Scenario: Development salt included in typed data
- **WHEN** the SDK uses `MisePayEnv.development` and builds a point authorization
- **THEN** the typed data domain includes `salt: misepay:dev`

### Requirement: Nullable PaymentIntent Actions

The SDK SHALL model PaymentIntent action URLs as nullable stable keys and SHALL fail locally with `ACTION_UNAVAILABLE` when the caller invokes an unavailable action.

#### Scenario: Point authorization action unavailable
- **WHEN** `actions.submit_point_authorization` is null
- **THEN** `applyPoints` fails with `ACTION_UNAVAILABLE` without making an HTTP request

#### Scenario: Payment proof action unavailable
- **WHEN** `actions.submit_payment_proof` is null
- **THEN** `provePayment` fails with `ACTION_UNAVAILABLE` without making an HTTP request

### Requirement: Machine-Readable Backend Errors

The SDK SHALL preserve backend machine-readable error codes in `MisePayException.code` when non-2xx responses include a code.

#### Scenario: Backend error code preserved
- **WHEN** a backend response returns non-2xx JSON with a `code` field
- **THEN** the SDK throws `MisePayException` with that code

### Requirement: Payment Option Chain Display Name

The SDK SHALL parse and serialize `payment_options[].chain_name` when present.

#### Scenario: Chain name present
- **WHEN** a PaymentIntent response includes `payment_options[].chain_name`
- **THEN** the SDK exposes it as `PaymentOption.chainName` and includes it in JSON serialization
