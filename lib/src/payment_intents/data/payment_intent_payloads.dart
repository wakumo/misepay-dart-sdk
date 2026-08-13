import 'dart:convert';

import '../domain/point_authorization.dart';

String pointAuthorizationPayload({
  required PointAuthorization authorization,
  required String signature,
}) {
  return jsonEncode({
    'payer_address': authorization.payerAddress,
    'point_amount': authorization.pointAmount,
    'authorization_revision': authorization.authorizationRevision,
    'signature': signature,
  });
}

String paymentProofPayload({
  required int chainId,
  required String tokenAddress,
  required String txHash,
  String? payerAddress,
}) {
  return jsonEncode({
    'chain_id': chainId,
    'token_address': tokenAddress,
    'tx_hash': txHash,
    if (payerAddress != null) 'payer_address': payerAddress,
  });
}
