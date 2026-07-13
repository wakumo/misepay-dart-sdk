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
- Point lookup is backend-resolved as `merchant_id + point_type + holder_address`.
- Payment chain is not part of point identity.
- EIP-712 domain `salt` defaults to the built-in production value. Override values must come from trusted app/build settings, not from the link or API response. Current values are `misepay:prod` for prod/stg and `misepay:dev` for dev.
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
      "intent": { "amount": "1200" },
      "limits": { "max": "3000" }
    }
  },
  "amount": {
    "currency": "JPY",
    "gross": "3000",
    "benefit": "1200",
    "net": "1800"
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

## EIP-712 Typed Data

```json
{
  "domain": {
    "name": "MisePay PaymentIntent",
    "version": "1",
    "salt": "misepay:prod"
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
    "expiresAt": 1780000300
  }
}
```

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

## SDK Origin And Domain Settings

`MisePayClient()` includes built-in production defaults:

```txt
allowedOrigins = { https://apis.misepay.app }
domainSalt = misepay:prod
```

Apps may override these values for controlled non-production builds:

```dart
MisePayClient(
  allowedOrigins: {'https://dev-apis.misepay.app'},
  domainSalt: 'misepay:dev',
);
```

Dev builds may use permissive origin mode for local tunnels or temporary hosts, but should use the dev domain salt:

```dart
MisePayClient(
  allowAllOrigins: true,
  domainSalt: 'misepay:dev',
);
```

These settings are trusted app/build configuration. They must not be read from `request_uri`, query parameters, user input, or the PaymentIntent API response.
