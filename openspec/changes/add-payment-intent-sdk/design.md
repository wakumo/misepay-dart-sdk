## Context

The SDK is consumed by the Avacus Flutter app but should remain a pure Dart package. The app owns wallet selection, signing, chain switching, and ERC20 transaction submission. The SDK owns MisePay HTTP calls, PaymentIntent model parsing, EIP-712 point authorization construction, and follow-up action submission.

## API Design

```dart
final client = MisePayClient();

final intent = await client.getPaymentIntent(
  requestUri: requestUri,
  payerAddress: payerAddress,
);

final authorization = intent.buildPointAuthorization(pointAmount: '1200');
final signature = await signer.signTypedData(authorization.typedData);

final updatedIntent = await intent.submitPointAuthorization(
  authorization: authorization,
  signature: signature,
);

await updatedIntent.submitTransactionHash(
  chainId: selectedOption.chainId,
  tokenAddress: selectedOption.tokenAddress,
  txHash: txHash,
);
```

## URL Handling

Initial fetch uses `requestUri`. If `payerAddress` is provided, the SDK adds `payer_address` as a query parameter, preserving existing params.

Follow-up calls use `actions` URLs from the response. The SDK must not derive `.../benefits` or `.../payment-proofs` from `requestUri`.

## EIP-712

The SDK builds `PaymentIntentPointAuthorization` locally from the fetched PaymentIntent and selected point amount. The signed message binds intent id, payer address, gross amount, selected point amount, resulting net amount, and PaymentIntent expiry.

There is no quote endpoint in the POC.

## Money And Amounts

All amounts remain strings. Arithmetic for point/net validation uses integer parsing only. The SDK must not use floating point.
