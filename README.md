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

When the payer wants to apply points, build EIP-712 typed data from the full `PaymentIntent`. The full object is required because validation depends on payer, amount, limits, and expiry data.

```dart
final authorization = client.paymentIntents.authorizePoints(
  paymentIntent: paymentIntent,
  paymentOption: paymentIntent.paymentOptions.first,
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

`pointAmount` is a non-negative integer string. Money, points, and token base-unit amounts are represented as strings; do not convert them to floating point values.

For point authorization, the selected payment option's `amountBaseUnits` is the current expected token payment and already accounts for verified payments. The SDK converts the selected `pointAmount` to token base units using that payment option's `assetDecimals`, then subtracts it from `amountBaseUnits` to produce the signed `netAmount`. The signed `grossAmount` remains the full gross order amount.

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
