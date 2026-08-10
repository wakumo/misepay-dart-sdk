# PaymentIntent SDK Payload Format

Source contract: <https://github.com/wakumo/aim-api/issues/218>

This package implements the client-side Dart SDK for the MisePay PaymentIntent payload contract used by Avacus app.

## Core SDK Contract

```dart
final misepayClient = MisePayClient();

final paymentIntent = await misepayClient.paymentIntents.get(
  requestUri: requestUri,
  payerAddress: payerAddress,
);

final authorization = misepayClient.paymentIntents.authorizePoints(
  paymentIntent: paymentIntent,
  pointAmount: '1200',
);

final signature = await signer.signTypedData(authorization.typedData);

final updatedPaymentIntent = await misepayClient.paymentIntents.applyPoints(
  paymentIntent: paymentIntent,
  authorization: authorization,
  signature: signature,
);

final selectedOption = updatedPaymentIntent.paymentOptions.first;

await misepayClient.paymentIntents.provePayment(
  paymentIntent: updatedPaymentIntent,
  chainId: selectedOption.chainId,
  tokenAddress: selectedOption.tokenAddress,
  txHash: txHash,
);
```

## Key Rules

- Checkout creation returns `{ order, payment_intent }`; the initial GET URL is `payment_intent.request_uri`, exposed by the SDK as `PaymentIntent.requestUri`.
- `request_uri` is required on every version 1 PaymentIntent response, including polling, terminal, point-authorization, and payment-proof responses.
- Apps MUST reuse the returned `PaymentIntent.requestUri` and MUST NOT construct a route from `PaymentIntent.id`.
- The SDK validates the `requestUri` origin against built-in production settings unless trusted override settings or permissive origin mode are provided.
- The SDK validates origin only, not path. The backend route remains opaque to the SDK.
- If `payerAddress` is provided, the SDK appends `payer_address` to the initial GET URL.
- Follow-up API calls MUST use response `actions` URLs.
- The SDK MUST NOT compose follow-up URLs by appending paths to `requestUri`.
- The SDK accepts PaymentIntent payload version `1` and rejects any other version with `UNSUPPORTED_PAYMENT_INTENT_VERSION` before using payment instructions or actions.
- The SDK exposes API `created_at` as nullable `PaymentIntent.createdAt` so it remains compatible with older deployments where the field is missing or null.
- Merchant and Store summaries expose nullable `imageUrl` values from `image_url`. Missing, null, empty, and whitespace-only values are unavailable.
- Wallet UI owns image selection and load-error fallback in Store, Merchant, local-placeholder order. The SDK does not select a fallback or probe image URLs with HTTP `HEAD` requests.
- Point identity is backend-owned as `merchant_id + point_type + holder_address`. For the POC, `point_type` has a single backend default value. The SDK/app sends only `payerAddress`; it does not send or choose `point_type`.
- Payment chain is not part of point identity.
- EIP-712 domain salt labels are derived from the SDK environment, not from app input, the link, or the API response. The configured labels are `misepay:prod` for production and `misepay:dev` for development. Before signing, `typedData.domain.salt` is set to `keccak256(UTF-8(label))` as a lowercase, `0x`-prefixed bytes32.
- `pointAmount` is a non-negative integer point string where `1 point = 1 JPY`; it is never scaled using token decimals.
- `amount.gross`, `amount.benefit`, and `amount.net` are backend-derived display/accounting values and are not part of point consent.
- Each `payment_options[].amount_base_units` is the current expected token payment in token base units, scaled using that asset's decimals.
- Point authorization is independent of chain and payment option. The SDK needs no settlement option to construct it.
- The V1 EIP-712 message signs exactly `intentId`, `payer`, `pointAmount`, and `expiresAt`. There is no fallback for the unreleased earlier message shape.
- `authorizePoints` is local SDK logic and MUST NOT call a quote endpoint.
- Any point amount change requires EIP-712 signature.
- If current point amount is already `0`, cancellation is a no-op and should not submit.
- On submission, the backend locks canonical state and recomputes current remaining value, available point balance, benefit, net amount, and settlement base units before reserving points.
- A signature remains usable after verified payment state changes only while its exact point amount is within the current remaining value.

## PaymentIntent Response Shape

Without `payerAddress`, the canonical resource explicitly contains
`"payer": null`:

```json
{
  "version": 1,
  "id": "pi_123",
  "request_uri": "https://api.misepay.app/v1/payment-intents/pi_123",
  "status": "pending",
  "merchant": {
    "name": "Cafe ABC",
    "image_url": "https://cdn.example.com/merchants/cafe-abc.jpg"
  },
  "store": { "name": "Shibuya Store", "image_url": null },
  "payer": null,
  "amount": {
    "currency": "JPY",
    "gross": "3000",
    "benefit": "0",
    "net": "3000"
  },
  "payment_options": [
    {
      "chain_id": 137,
      "chain_name": "Polygon",
      "asset_symbol": "JPYC",
      "asset_decimals": 18,
      "token_address": "0xJPYCPolygon...",
      "recipient_address": "0xMerchantPolygon...",
      "amount_base_units": "3000000000000000000000"
    }
  ],
  "actions": {
    "submit_point_authorization": "https://api.misepay.app/v1/payment-intents/pi_123/benefits",
    "submit_payment_proof": "https://api.misepay.app/v1/payment-intents/pi_123/payment-proofs"
  },
  "created_at": "2026-07-06T12:00:00Z",
  "expires_at": "2026-07-06T12:05:00Z"
}
```

With `payerAddress`, the same resource contains the payer-specific point
balance and authorization values:

```json
{
  "version": 1,
  "id": "pi_123",
  "request_uri": "https://api.misepay.app/v1/payment-intents/pi_123",
  "status": "pending",
  "merchant": {
    "name": "Cafe ABC",
    "image_url": "https://cdn.example.com/merchants/cafe-abc.jpg"
  },
  "store": { "name": "Shibuya Store", "image_url": null },
  "payer": {
    "address": "0xabc...",
    "point": {
      "label": "MisePay Points",
      "balance": { "available": "5000" },
      "authorization": {
        "amount": "0",
        "max_amount": "3000"
      }
    }
  },
  "amount": {
    "currency": "JPY",
    "gross": "3000",
    "benefit": "0",
    "net": "3000"
  },
  "payment_options": [
    {
      "chain_id": 137,
      "chain_name": "Polygon",
      "asset_symbol": "JPYC",
      "asset_decimals": 18,
      "token_address": "0xJPYCPolygon...",
      "recipient_address": "0xMerchantPolygon...",
      "amount_base_units": "1800000000000000000000"
    }
  ],
  "actions": {
    "submit_point_authorization": "https://api.misepay.app/v1/payment-intents/pi_123/benefits",
    "submit_payment_proof": "https://api.misepay.app/v1/payment-intents/pi_123/payment-proofs"
  },
  "created_at": "2026-07-06T12:00:00Z",
  "expires_at": "2026-07-06T12:05:00Z"
}
```

This response represents a partial-payment state: `1200000000000000000000` token base units have already been verified on-chain, so the current expected payment in `payment_options[0].amount_base_units` is `1800000000000000000000` even though the full gross order amount remains `3000`.

The SDK exposes `authorization.amount` as a string and `authorization.max_amount`
as `authorization.maxAmount`. Both fields are required whenever `payer` is not
null. The maximum is the total authorization target for the current snapshot,
not an incremental allowance. Internal `reserved`, `consumed`, and `released`
benefit statuses remain backend-only.

Initial fetches, polling responses, and action responses use this same resource
shape. Replace local state with each returned PaymentIntent and use its
`requestUri` for the next poll. When the backend creates a replacement intent
after expiry, use the replacement resource's new `requestUri` to generate the
new QR; do not reuse the expired URI.

The API requires `created_at`, `merchant.image_url`, and `store.image_url` on
the canonical response. The SDK intentionally treats them as nullable for
staggered rollout compatibility and serializes unavailable values as null. It
keeps Store and Merchant images separate so wallet UI can retry the Merchant
image when the Store image is absent or fails to load.

## EIP-712 Typed Data

```json
{
  "domain": {
    "name": "MisePay PaymentIntent",
    "version": "1",
    "salt": "0x934a72bcfc23658c976948324c105b63256b1fd78f220a1ac53fba14c85c8502"
  },
  "primaryType": "PaymentIntentPointAuthorization",
  "types": {
    "PaymentIntentPointAuthorization": [
      { "name": "intentId", "type": "string" },
      { "name": "payer", "type": "address" },
      { "name": "pointAmount", "type": "uint256" },
      { "name": "expiresAt", "type": "uint256" }
    ]
  },
  "message": {
    "intentId": "pi_123",
    "payer": "0xabc...",
    "pointAmount": "1200",
    "expiresAt": 1783339500
  }
}
```

The payer authorizes exactly `1200` point units for `pi_123` until the stated expiry. The signature does not bind display/accounting amounts or settlement-token quantities. The backend derives those values from current canonical state when the authorization is submitted.

## Point Authorization Submit Body

```json
{
  "payer_address": "0xabc...",
  "point_amount": "1200",
  "signature": "0x..."
}
```

## Transaction Hash Submit Body

```json
{
  "chain_id": 137,
  "token_address": "0xJPYCPolygon...",
  "tx_hash": "0x..."
}
```

## Actions

Action keys are stable, but values may be null when an action is unavailable for the current PaymentIntent state. SDK methods fail locally with `ACTION_UNAVAILABLE` when called for a null action.

## SDK Environment And Origin Settings

`MisePayClient()` includes built-in production defaults:

```txt
environment = production
allowedOrigins = { https://apis.misepay.app }
domainSaltLabel = misepay:prod
```

Apps may select development settings and provide trusted non-production origins:

```dart
MisePayClient(
  env: MisePayEnv.development,
  allowedOrigins: {'https://dev-apis.misepay.app'},
);
```

Dev builds may use permissive origin mode for local tunnels or temporary hosts:

```dart
MisePayClient(
  env: MisePayEnv.development,
  originPolicy: MisePayOriginPolicy.allowAll,
);
```

These settings are trusted app/build configuration. They must not be read from `request_uri`, query parameters, user input, or the PaymentIntent API response. `domainSalt` is intentionally not public SDK configuration; its label is derived from `MisePayEnv` and hashed with `keccak256(UTF-8(label))` before the typed data is signed.
