# MisePay Dart SDK

Dart SDK for MisePay PaymentIntent checkout flows.

The SDK is Flutter-independent. Apps provide the selected payer address and signer; the SDK fetches PaymentIntent state, builds EIP-712 point authorization typed data, submits signed point authorizations, and submits transaction hashes for optional payment proof acceleration.

See `docs/payment-intent-sdk-payload-format.md` for the contract used by both the MisePay backend and this SDK.

## Install

Until the package is published, load it directly from GitHub:

```yaml
dependencies:
  misepay_sdk:
    git:
      url: https://github.com/wakumo/misepay-dart-sdk.git
      ref: main
```

After publishing to pub.dev, use the package version instead:

```yaml
dependencies:
  misepay_sdk: ^0.1.0
```

## Usage

Create a client and fetch the PaymentIntent from the `requestUri` returned by MisePay checkout creation. The default client uses the production MisePay origin and the configured production salt label, `misepay:prod`. Before signing, the SDK sets `typedData.domain.salt` to the lowercase, `0x`-prefixed bytes32 produced by `keccak256(UTF-8(label))`.

```dart
import 'package:misepay_sdk/misepay_sdk.dart';

final client = MisePayClient();

final paymentIntent = await client.paymentIntents.get(
  requestUri: requestUri,
  payerAddress: payerAddress,
);
```

Dev builds can select the development environment. The SDK derives the EIP-712 domain salt label (`misepay:prod` or `misepay:dev`) from `MisePayEnv`; app code does not supply `domainSalt`. The derived label is hashed before the typed data is signed.

```dart
final devClient = MisePayClient(
  env: MisePayEnv.development,
  allowedOrigins: {'https://dev-apis.misepay.app'},
);
```

Local development can use a permissive origin policy when needed:

```dart
final localClient = MisePayClient(
  env: MisePayEnv.development,
  originPolicy: MisePayOriginPolicy.allowAll,
);
```

Read response data through typed fields:

```dart
paymentIntent.id;
paymentIntent.status;
paymentIntent.merchant.name;
paymentIntent.store.name;
paymentIntent.amount.gross;
paymentIntent.amount.net;
paymentIntent.payer?.point.balance.available;
paymentIntent.paymentOptions.first.chainName;
paymentIntent.paymentOptions.first.amountBaseUnits;
```

Serialize typed response data when you need to cache, log, debug, or pass data across app layers:

```dart
final json = paymentIntent.toJson();
```

## Point Authorization

When the payer wants to apply points, build EIP-712 typed data from the full `PaymentIntent`. The full object supplies the intent ID, payer, point limits, current point selection, and expiry. Point authorization is independent of the selected chain or payment option.

```dart
final authorization = client.paymentIntents.authorizePoints(
  paymentIntent: paymentIntent,
  pointAmount: '1200',
);

final typedData = authorization.typedData;
final signature = await signer.signTypedData(typedData);

final updatedIntent = await client.paymentIntents.applyPoints(
  paymentIntent: paymentIntent,
  authorization: authorization,
  signature: signature,
);
```

An open checkout remains `PaymentIntentStatus.pending` after partial point
application. Replace local checkout state with `updatedIntent`, then send the
selected payment option's exact `amountBaseUnits` when `updatedIntent.status`
is `pending`. If it is `completed`, show success and do not send a token
transaction.

The V1 EIP-712 message signs exactly `intentId`, `payer`, `pointAmount`, and `expiresAt`. The domain remains version `1`; the unreleased earlier message shape is not supported as a fallback.

Keep these unit domains separate:

- `pointAmount` is a positive integer point value where `1 point = 1 JPY`; it is never scaled using token decimals.
- `paymentIntent.amount.gross`, `benefit`, and `net` are backend-derived display/accounting values.
- Each payment option's `amountBaseUnits` is an exact settlement-token quantity scaled by that asset's decimals.

The backend locks current PaymentIntent state and recomputes remaining value, balance, benefit, net amount, and settlement base units when the signed authorization is submitted. Do not convert any of these string values to floating point.

## Payment Proof

After sending the on-chain payment, submit the transaction hash to the action URL returned by the PaymentIntent.

```dart
final paidIntent = await client.paymentIntents.provePayment(
  paymentIntent: updatedIntent,
  chainId: 137,
  tokenAddress: '0xJPYCPolygon',
  txHash: '0xtx',
);
```

## Errors

SDK validation and HTTP errors throw `MisePayException`:

```dart
try {
  final paymentIntent = await client.paymentIntents.get(requestUri: requestUri);
} on MisePayException catch (error) {
  print(error.code);
  print(error.message);
}
```

Common SDK codes include `UNTRUSTED_REQUEST_ORIGIN`, `ACTION_UNAVAILABLE`, `HTTP_ERROR`, `UNKNOWN_STATUS`, `PAYER_REQUIRED`, `INVALID_POINT_AMOUNT`, `INVALID_EXPECTED_PAYMENT_AMOUNT`, `POINT_AMOUNT_EXCEEDS_MAX`, `POINT_AMOUNT_UNCHANGED`, and `POINT_AMOUNT_EXCEEDS_REMAINING`. Backend machine-readable error codes are preserved when present.
