import 'package:http/http.dart' as http;

import '../../core/response_parser.dart';
import '../domain/payment_intent.dart';
import '../domain/payment_intent_repository.dart';
import '../domain/point_authorization.dart';
import 'payment_intent_payloads.dart';

class PaymentIntentApi implements PaymentIntentRepository {
  PaymentIntentApi({required http.Client httpClient})
      : _httpClient = httpClient;

  final http.Client _httpClient;

  @override
  Future<PaymentIntent> getPaymentIntent({
    required String requestUri,
    String? payerAddress,
  }) async {
    final response = await _httpClient.get(_buildRequestUri(
      requestUri: requestUri,
      payerAddress: payerAddress,
    ));
    return PaymentIntent.fromJson(parseJsonObjectResponse(response));
  }

  @override
  Future<PaymentIntent> submitPointAuthorization({
    required PaymentIntent intent,
    required PointAuthorization authorization,
    required String signature,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(intent.actions.submitPointAuthorization),
      headers: {'content-type': 'application/json'},
      body: pointAuthorizationPayload(
        authorization: authorization,
        signature: signature,
      ),
    );
    return PaymentIntent.fromJson(parseJsonObjectResponse(response));
  }

  @override
  Future<PaymentIntent> submitTransactionHash({
    required PaymentIntent intent,
    required int chainId,
    required String tokenAddress,
    required String txHash,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(intent.actions.submitPaymentProof),
      headers: {'content-type': 'application/json'},
      body: paymentProofPayload(
        chainId: chainId,
        tokenAddress: tokenAddress,
        txHash: txHash,
      ),
    );
    return PaymentIntent.fromJson(parseJsonObjectResponse(response));
  }

  Uri _buildRequestUri({required String requestUri, String? payerAddress}) {
    final uri = Uri.parse(requestUri);
    if (payerAddress == null) {
      return uri;
    }
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'payer_address': payerAddress,
    });
  }
}
