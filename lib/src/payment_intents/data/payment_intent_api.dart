import 'package:http/http.dart' as http;

import '../../core/misepay_exception.dart';
import '../../core/response_parser.dart';
import '../domain/payment_intent.dart';
import '../domain/payment_intent_repository.dart';
import '../domain/point_authorization.dart';
import 'payment_intent_payloads.dart';

class PaymentIntentApi implements PaymentIntentRepository {
  PaymentIntentApi({
    required http.Client httpClient,
    Set<String> allowedOrigins = const {},
    bool allowAllOrigins = false,
  })  : _httpClient = httpClient,
        _allowedOrigins = allowedOrigins,
        _allowAllOrigins = allowAllOrigins;

  final http.Client _httpClient;
  final Set<String> _allowedOrigins;
  final bool _allowAllOrigins;

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
    final actionUrl = intent.actions.submitPointAuthorization;
    if (actionUrl == null) {
      throw MisePayException(
          'ACTION_UNAVAILABLE', 'Point authorization action is unavailable.');
    }
    final response = await _httpClient.post(
      Uri.parse(actionUrl),
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
    final actionUrl = intent.actions.submitPaymentProof;
    if (actionUrl == null) {
      throw MisePayException(
          'ACTION_UNAVAILABLE', 'Payment proof action is unavailable.');
    }
    final response = await _httpClient.post(
      Uri.parse(actionUrl),
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
    if (!_allowAllOrigins && !_allowedOrigins.contains(uri.origin)) {
      throw MisePayException('UNTRUSTED_REQUEST_ORIGIN',
          'PaymentIntent requestUri origin is not trusted.');
    }
    if (payerAddress == null) {
      return uri;
    }
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'payer_address': payerAddress,
    });
  }
}
