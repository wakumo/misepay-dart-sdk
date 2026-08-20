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
  payerAddress: connectedWalletAddress,
);
```

## Key Rules

- Checkout creation returns `{ order, payment_intent }`; the initial GET URL is `payment_intent.request_uri`, exposed by the SDK as `PaymentIntent.requestUri`.
- `request_uri` is required on every version 1 PaymentIntent response, including polling, terminal, point-authorization, and payment-proof responses.
- Apps MUST reuse the returned `PaymentIntent.requestUri` and MUST NOT construct a route from `PaymentIntent.id`.
- The SDK validates the `requestUri` origin against built-in production settings unless trusted override settings or permissive origin mode are provided.
- The SDK validates origin only, not path. The backend route remains opaque to the SDK.
- If `payerAddress` is provided, the SDK appends `payer_address` to the initial GET URL.
- `PaymentIntent.points` is canonical point context. `PaymentIntent.payer` is a nullable legacy projection during the compatibility window; neither is connected-wallet state. Once A is bound, switching the app wallet to B does not replace A.
- Follow-up API calls MUST use response `actions` URLs.
- The SDK MUST NOT compose follow-up URLs by appending paths to `requestUri`.
- The SDK accepts PaymentIntent payload version `1` and rejects any other version with `UNSUPPORTED_PAYMENT_INTENT_VERSION` before using payment instructions or actions.
- The SDK exposes API `order_id` as nullable `PaymentIntent.orderId` so payer clients can display a stable receipt reference while remaining compatible with deployments where the additive field is not available yet.
- The SDK exposes API `created_at` as nullable `PaymentIntent.createdAt` so it remains compatible with older deployments where the field is missing or null.
- The SDK exposes `completed_at` and `cancelled_at` as nullable `PaymentIntent.completedAt` and `PaymentIntent.cancelledAt`; missing and null fields remain null for staggered rollout and historical-data compatibility.
- Merchant and Store summaries expose nullable `imageUrl` values from `image_url`. Missing, null, empty, and whitespace-only values are unavailable.
- Wallet UI owns image selection and load-error fallback in Store, Merchant, local-placeholder order. The SDK does not select a fallback or probe image URLs with HTTP `HEAD` requests.
- Point identity is backend-owned as `merchant_id + point_type + holder_address`. For the POC, `point_type` has a single backend default value. The SDK/app sends only `payerAddress`; it does not send or choose `point_type`.
- Payment chain is not part of point identity.
- `PaymentIntent.points` is nullable for staggered rollout. `points.account` is a pending-only live snapshot with `holder_address`, `available_balance`, and nullable `expiring_soon_lot`; `points.authorization` always carries a pending holder's amount, nullable `maximum_amount`, and revision. Before first submission it has amount `"0"`, revision `0`, and null status; afterward status is `reserved`, `consumed`, or `released`.
- Top-level `reward` is nullable and maps to `PaymentIntent.reward`. After completed token settlement creates a reward lot, it contains the persisted reward recipient, integer-string amount, persisted grant status (`pending`, `available`, or `voided`), and availability time. A remains `points.authorization.holderAddress` while verified token payer B is `confirmedPayments[].fromAddress` and, when present, `reward.recipientAddress`.
- EIP-712 domain salt labels are derived from the SDK environment, not from app input, the link, or the API response. The configured labels are `misepay:prod` for production and `misepay:dev` for development. Before signing, `typedData.domain.salt` is set to `keccak256(UTF-8(label))` as a lowercase, `0x`-prefixed bytes32.
- `pointAmount` is a non-negative integer point string where `1 point = 1 JPY`; it is never scaled using token decimals.
- `amount.gross`, `amount.benefit`, `amount.net`, `amount.pointDiscount`, and `amount.tokenDue` are backend-derived display/accounting values and are not part of point consent. `pointDiscount == benefit` and `tokenDue == net`.
- Each `payment_options[].amount_base_units` is the current expected token payment in token base units, scaled using that asset's decimals.
- Point authorization is independent of chain and payment option. The SDK needs no settlement option to construct it.
- The single EIP-712 domain version `1` message signs `intentId`, `payer`, `pointAmount`, `authorizationRevision`, and `expiresAt`. The SDK signs the current response revision plus one; the first authorization therefore uses revision `1`.
- `authorizePoints` is local SDK logic and MUST NOT call a quote endpoint.
- Any point amount change requires a new signature and the next revision. `applyPoints` always submits the required `authorization_revision` field.
- If current point amount is already `0`, cancellation is a no-op and should not submit.
- On submission, the backend locks canonical state and recomputes current remaining value, available point balance, benefit, net amount, and settlement base units before reserving points.
- A signature remains usable after verified payment state changes only while its exact point amount is within the current remaining value.
- The same holder may change the pending total target, including zero. Another wallet cannot edit it, and clearing to zero releases value without unbinding the holder.
- `provePayment.payerAddress` is optional response-rendering context. The SDK does not infer it from `PaymentIntent.payer` or `PaymentIntent.points`, and neither client nor synchronous API treats it as verified `tx.from`.
- Verified token sender identity comes only from `confirmed_payments[].from_address` after worker/scanner verification of ERC-20 `Transfer.from`.
- After broadcast, proof errors authorize retrying the same hash and polling only; they never authorize resending token funds.

## PaymentIntent Response Shape

When no point holder is bound, omitting `payerAddress` produces explicit
`"points": null` and legacy `"payer": null`:

```json
{
  "version": 1,
  "id": "pi_123",
  "order_id": "order_123",
  "request_uri": "https://api.misepay.app/v1/payment-intents/pi_123",
  "status": "pending",
  "merchant": {
    "name": "Cafe ABC",
    "image_url": "https://cdn.example.com/merchants/cafe-abc.jpg"
  },
  "store": { "name": "Shibuya Store", "image_url": null },
  "points": null,
  "payer": null,
  "amount": {
    "currency": "JPY",
    "gross": "3000",
    "benefit": "0",
    "net": "3000",
    "point_discount": "0",
    "token_due": "3000"
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
  "confirmed_payments": [],
  "actions": {
    "submit_point_authorization": "https://api.misepay.app/v1/payment-intents/pi_123/benefits",
    "submit_payment_proof": "https://api.misepay.app/v1/payment-intents/pi_123/payment-proofs"
  },
  "created_at": "2026-07-06T12:00:00Z",
  "completed_at": null,
  "cancelled_at": null,
  "expires_at": "2026-07-06T12:05:00Z"
}
```

When no holder is bound, supplying `payerAddress` requests preview balance and
authorization values. Once A authorizes points, the same shape remains bound to
A even when connected wallet B supplies later query or proof context:

```json
{
  "version": 1,
  "id": "pi_123",
  "order_id": "order_123",
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
        "max_amount": "3000",
        "revision": 0
      },
      "expiring_soon_lot": {
        "amount": "21000",
        "expires_at": "2026-10-15T00:00:00Z"
      }
    }
  },
  "reward": null,
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
  "confirmed_payments": [],
  "actions": {
    "submit_point_authorization": "https://api.misepay.app/v1/payment-intents/pi_123/benefits",
    "submit_payment_proof": "https://api.misepay.app/v1/payment-intents/pi_123/payment-proofs"
  },
  "created_at": "2026-07-06T12:00:00Z",
  "completed_at": null,
  "cancelled_at": null,
  "expires_at": "2026-07-06T12:05:00Z"
}
```

This response represents a partial-payment state: `1200000000000000000000` token base units have already been verified on-chain, so the current expected payment in `payment_options[0].amount_base_units` is `1800000000000000000000` even though the full gross order amount remains `3000`.

The SDK exposes `authorization.amount` as a string and `authorization.max_amount`
as `authorization.maxAmount`. Both fields are required whenever `payer` is not
null. The maximum is the total authorization target for the current snapshot,
not an incremental allowance. Internal `reserved`, `consumed`, and `released`
benefit statuses remain backend-only.

`expiring_soon_lot` and top-level `reward` are optional display
projections. The SDK parses either an absent or explicit null value as null and
serializes them as `expiring_soon_lot` and `reward`. They are never
signed, never sent in an authorization or proof request, and do not replace
payment receipts or the point ledger. `reward.recipient_address` comes
from persisted settlement truth, not the optional proof `payerAddress`.

Initial fetches, polling responses, and action responses use this same resource
shape. Replace local state with each returned PaymentIntent and use its
`requestUri` for the next poll. When the backend creates a replacement intent
after expiry, use the replacement resource's new `requestUri` to generate the
new QR; do not reuse the expired URI.

The API requires `order_id`, `created_at`, `completed_at`, `cancelled_at`,
`merchant.image_url`, and `store.image_url` on the canonical response. The SDK
intentionally treats them as nullable for staggered rollout compatibility and
serializes unavailable values as null. Payer UI may display `orderId` as the
receipt reference when available; it must not invent a confirmed Order ID when
the field is absent. Terminal UI uses `completedAt` only for `completed` and
`cancelledAt` only for `cancelled`; it does not infer a missing event time from
another timestamp. The SDK keeps Store and Merchant images separate so wallet
UI can retry the Merchant image when the Store image is absent or fails to load.

On token completion, `confirmed_payments` contains allowlisted verified receipt
evidence. `from_address` is additive in the SDK model and parses as nullable for
older backend environments, but a current API receipt supplies it from the
canonical Transaction:

```json
{
  "payer": {
    "address": "0xHolderA...",
    "point": {
      "label": "MisePay Points",
      "balance": { "available": "5000" },
      "authorization": { "amount": "1200", "max_amount": "3000", "revision": 1 }
    }
  },
  "confirmed_payments": [
    {
      "chain_id": 137,
      "asset_symbol": "JPYC",
      "asset_decimals": 18,
      "token_address": "0xJPYCPolygon...",
      "from_address": "0xSenderB...",
      "amount_base_units": "3000000000000000000000",
      "tx_hash": "0x...",
      "log_index": 4,
      "block_timestamp": "2026-08-11T10:00:00Z"
    }
  ]
}
```

This separation is intentional: A owns point consent and B funded the verified
token transfer. Full or surplus token coverage releases A's active reservation
and completes the PaymentIntent; it does not cancel the paid intent. Accepted
and reward value remain capped at gross, while the backend records surplus.

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
    "EIP712Domain": [
      { "name": "name", "type": "string" },
      { "name": "version", "type": "string" },
      { "name": "salt", "type": "bytes32" }
    ],
    "PaymentIntentPointAuthorization": [
      { "name": "intentId", "type": "string" },
      { "name": "payer", "type": "address" },
      { "name": "pointAmount", "type": "uint256" },
      { "name": "authorizationRevision", "type": "uint256" },
      { "name": "expiresAt", "type": "uint256" }
    ]
  },
  "message": {
    "intentId": "pi_123",
    "payer": "0xabc...",
    "pointAmount": "1200",
    "authorizationRevision": "1",
    "expiresAt": 1783339500
  }
}
```

The payer selects a total target of `1200` point units at revision `1` for `pi_123` until the stated expiry. The signature does not bind display/accounting amounts or settlement-token quantities. The backend derives those values from current canonical state when the authorization is submitted.

## Point Authorization Submit Body

```json
{
  "payer_address": "0xabc...",
  "point_amount": "1200",
  "authorization_revision": 1,
  "signature": "0x..."
}
```

## Transaction Hash Submit Body

```json
{
  "chain_id": 137,
  "token_address": "0xJPYCPolygon...",
  "tx_hash": "0x...",
  "payer_address": "0xConnectedWallet..."
}
```

`payer_address` is optional and exists only so the `202 Accepted` response can
render useful wallet context when no holder is bound. At request time the API
does not fetch the transaction receipt, validate this address against A, or use
it as sender evidence. Omitting it does not change verification or settlement.

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
