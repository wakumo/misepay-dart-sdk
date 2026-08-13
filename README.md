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

Create a client and fetch the PaymentIntent from `payment_intent.request_uri` returned by MisePay checkout creation. Pass that value to the SDK as `requestUri`; do not construct a backend path from the PaymentIntent id. The default client uses the production MisePay origin and the configured production salt label, `misepay:prod`. Before signing, the SDK sets `typedData.domain.salt` to the lowercase, `0x`-prefixed bytes32 produced by `keccak256(UTF-8(label))`.

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
paymentIntent.orderId;
paymentIntent.requestUri;
paymentIntent.status;
paymentIntent.createdAt;
paymentIntent.completedAt;
paymentIntent.cancelledAt;
paymentIntent.merchant.name;
paymentIntent.merchant.imageUrl;
paymentIntent.store.name;
paymentIntent.store.imageUrl;
paymentIntent.amount.gross;
paymentIntent.amount.net;
paymentIntent.payer?.point.balance.available;
paymentIntent.payer?.point.authorization.amount;
paymentIntent.payer?.point.authorization.maxAmount;
paymentIntent.payer?.point.authorization.revision;
paymentIntent.paymentOptions.first.chainName;
paymentIntent.paymentOptions.first.amountBaseUnits;
```

When the PaymentIntent is fetched without `payerAddress`, the backend returns
an explicit null payer context:

```json
{
  "payer": null
}
```

When `payerAddress` is provided, the SDK parses the canonical point context:

```json
{
  "payer": {
    "address": "0xabc...",
    "point": {
      "label": "MisePay Points",
      "balance": { "available": "5000" },
      "authorization": {
        "amount": "1200",
        "max_amount": "3000",
        "revision": 1
      }
    }
  }
}
```

`authorization.amount` is the point amount currently associated with this
PaymentIntent. `authorization.max_amount` is the total target allowed for the
current backend snapshot, not an additional amount. The SDK exposes the latter
as `authorization.maxAmount`. Internal benefit lifecycle status is not part of
the public SDK model.

`orderId`, `createdAt`, `completedAt`, `cancelledAt`, `merchant.imageUrl`, and
`store.imageUrl` are nullable so the SDK remains compatible while API
deployments roll out independently. The canonical API supplies `order_id`,
`created_at`, `completed_at`, `cancelled_at`, and both `image_url` keys. Use
`orderId` as the payer-visible receipt reference when it is available. For
checkout presentation, try a nonblank Store image first, then a nonblank
Merchant image, then a local placeholder. Handle image load errors directly;
do not issue HTTP `HEAD` requests to probe whether an image URL exists.

Serialize typed response data when you need to cache, log, debug, or pass data across app layers:

```dart
final json = paymentIntent.toJson();
```

## Polling and Terminal Statuses

Use `PaymentIntent.requestUri` to refresh PaymentIntent state. Every initial,
polled, and action response carries the canonical URI for that exact intent. Stop
polling when the returned status is `completed`, `expired`, `cancelled`, or
`reviewRequired`.

```dart
var current = paymentIntent;

while (current.status == PaymentIntentStatus.pending) {
  await Future<void>.delayed(const Duration(seconds: 2));
  current = await client.paymentIntents.get(
    requestUri: current.requestUri,
    payerAddress: payerAddress,
  );
}
```

Terminal PaymentIntents remain readable resources. Their merchant, store,
creation time, nullable completion/cancellation time, payer, amount, benefit, expiry, and status fields remain
available for UI rendering, while `paymentOptions` is empty and both action
URLs are `null`. `paymentOptions` describes routes that can be used now; never
retain or reuse it as historical evidence after completion. Read the actual
verified token transfer from `confirmedPayments` instead.

```dart
if (current.status == PaymentIntentStatus.completed) {
  if (current.confirmedPayments.isNotEmpty) {
    final receipt = current.confirmedPayments.first;
    showTokenReceipt(
      chainId: receipt.chainId,
      symbol: receipt.assetSymbol,
      amountBaseUnits: receipt.amountBaseUnits,
      transactionHash: receipt.txHash,
    );
  } else if (current.amount.net == '0' && current.amount.benefit != '0') {
    showPointOnlyCompletion();
  } else {
    showCompletedWithReceiptUnavailable();
  }
}
```

`confirmedPayments` is in deterministic backend order and currently contains
zero or one item. A point-only completion has an empty list. The SDK also
defaults a missing JSON field to an empty list during backend-first rollout, so
do not invent a token or network when the list is empty, and do not fall back to
stale `paymentOptions`.
Always branch on `status` before attempting payment or point authorization:

- `completed`: show success and do not submit another transaction.
- `expired`: show the expired checkout and request a new payment request.
- `cancelled`: show cancellation and disable payment controls.
- `reviewRequired`: show a pending-review outcome and disable payment controls.

`expiresAt` can drive a local countdown, but the status returned by the backend
is authoritative. Fetch once more when the countdown elapses so the backend can
finalize and return the persisted `expired` resource.

For terminal UI, use `completedAt` only with `completed` and `cancelledAt` only
with `cancelled`. Either value can be null for historical data or during a
staggered backend rollout; do not substitute `createdAt` or `expiresAt` as an
invented terminal time.

When a merchant creates a replacement PaymentIntent after expiry, the backend
returns a new id, expiry, and `requestUri`. Generate the replacement QR from
that new URI; never reuse the expired intent URI or rebuild one from the id.

## Point Authorization

When the payer wants to apply points, build EIP-712 typed data from the full `PaymentIntent`. The full object supplies the intent ID, payer, current authorization amount, maximum authorization target, and expiry. Point authorization is independent of the selected chain or payment option.

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

The single EIP-712 domain version `1` message signs `intentId`, `payer`, the total `pointAmount` target, `authorizationRevision`, and `expiresAt`. The SDK reads the current response revision and signs the next one. The first authorization uses revision `1`; each later change uses the current revision plus one, preventing an older request from overwriting a newer selection.

Keep these unit domains separate:

- `pointAmount` is a non-negative integer point target where `1 point = 1 JPY`; zero clears an existing pending reservation and it is never scaled using token decimals.
- `paymentIntent.amount.gross`, `benefit`, and `net` are backend-derived display/accounting values.
- Each payment option's `amountBaseUnits` is an exact settlement-token quantity scaled by that asset's decimals.

The backend locks current PaymentIntent state and recomputes remaining value, balance, benefit, net amount, and settlement base units when the signed authorization is submitted. Do not convert any of these string values to floating point.

While the PaymentIntent remains pending, the same holder may increase, decrease, clear, or reapply points within the returned `authorization.maxAmount`. An unchanged selection is a local `POINT_AMOUNT_UNCHANGED` no-op. The holder remains bound after clearing to zero.

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

The backend returns `202 Accepted` after durably scheduling independent chain,
token, receipt, confirmation, recipient, and exact token base-unit verification.
This response acknowledges background work; it does not confirm payment. Replace
local checkout state with the returned PaymentIntent, then poll its `requestUri`
until a terminal state is observed. Normal scanning remains the fallback if the
bounded proof-verification job finishes too early or exhausts its retries.
The SDK includes `paymentIntent.payer?.address` as proof response context when available; the backend does not treat that client value as verified transaction-sender evidence.

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

Common SDK codes include `UNSUPPORTED_PAYMENT_INTENT_VERSION`, `UNTRUSTED_REQUEST_ORIGIN`, `ACTION_UNAVAILABLE`, `HTTP_ERROR`, `UNKNOWN_STATUS`, `PAYER_REQUIRED`, `INVALID_POINT_AMOUNT`, `INVALID_EXPECTED_PAYMENT_AMOUNT`, `POINT_AMOUNT_EXCEEDS_MAX`, `POINT_AMOUNT_UNCHANGED`, and `POINT_AMOUNT_EXCEEDS_REMAINING`. Backend machine-readable error codes are preserved when present.
