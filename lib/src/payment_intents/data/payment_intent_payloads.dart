import 'dart:convert';

import '../domain/point_authorization.dart';

String pointAuthorizationPayload({
  required PointAuthorization authorization,
  required String signature,
}) {
  return jsonEncode({
    'payer_address': authorization.payerAddress,
    'point_amount': authorization.pointAmount,
    'signature': signature,
  });
}

String paymentProofPayload({
  required int chainId,
  required String tokenAddress,
  required String txHash,
}) {
  return jsonEncode({
    'chain_id': chainId,
    'token_address': tokenAddress,
    'tx_hash': txHash,
  });
}
