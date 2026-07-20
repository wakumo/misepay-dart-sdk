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
  paymentOption: paymentIntent.paymentOptions.first,
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

- `requestUri` is the initial GET URL.
- The SDK validates the `requestUri` origin against built-in production settings unless trusted override settings or permissive origin mode are provided.
- The SDK validates origin only, not path. The backend route remains opaque to the SDK.
- If `payerAddress` is provided, the SDK appends `payer_address` to the initial GET URL.
- Follow-up API calls MUST use response `actions` URLs.
- The SDK MUST NOT compose follow-up URLs by appending paths to `requestUri`.
- Point identity is backend-owned as `merchant_id + point_type + holder_address`. For the POC, `point_type` has a single backend default value. The SDK/app sends only `payerAddress`; it does not send or choose `point_type`.
- Payment chain is not part of point identity.
- EIP-712 domain salt labels are derived from the SDK environment, not from app input, the link, or the API response. The configured labels are `misepay:prod` for production and `misepay:dev` for development. Before signing, `typedData.domain.salt` is set to `keccak256(UTF-8(label))` as a lowercase, `0x`-prefixed bytes32.
- Point and JPY amounts are non-negative integer strings where `1 point = 1 JPY`; they are never scaled using token decimals.
- Each `payment_options[].amount_base_units` is the current expected token payment in token base units and is separate from point/JPY amounts.
- The signed `grossAmount`, `pointAmount`, and `netAmount` use integer JPY-value units. `netAmount = grossAmount - pointAmount`.
- `authorizePoints` is local SDK logic and MUST NOT call a quote endpoint.
- Any point amount change requires EIP-712 signature.
- If current point amount is already `0`, cancellation is a no-op and should not submit.

## PaymentIntent Response Shape

```json
{
  "version": 1,
  "id": "pi_123",
  "status": "pending",
  "merchant": { "name": "Cafe ABC" },
  "store": { "name": "Shibuya Store" },
  "payer": {
    "address": "0xabc...",
    "point": {
      "label": "MisePay Points",
      "balance": { "available": "5000" },
      "intent": { "amount": "0" },
      "limits": { "max": "3000" }
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
  "expires_at": "2026-07-06T12:05:00Z"
}
```

This response represents a partial-payment state: `1200000000000000000000` token base units have already been verified on-chain, so the current expected payment in `payment_options[0].amount_base_units` is `1800000000000000000000` even though the full gross order amount remains `3000`.

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
      { "name": "grossAmount", "type": "uint256" },
      { "name": "pointAmount", "type": "uint256" },
      { "name": "netAmount", "type": "uint256" },
      { "name": "expiresAt", "type": "uint256" }
    ]
  },
  "message": {
    "intentId": "pi_123",
    "payer": "0xabc...",
    "grossAmount": "3000",
    "pointAmount": "1200",
    "netAmount": "1800",
    "expiresAt": 1783339500
  }
}
```

The payer selects `1200` points from a gross JPY amount of `3000`. The signed values remain JPY-value integers: `grossAmount = 3000`, `pointAmount = 1200`, and `netAmount = 1800`. Token decimal conversion is represented separately by `payment_options[].amount_base_units`.

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
