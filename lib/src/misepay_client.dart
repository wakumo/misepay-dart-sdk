import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class MisePayClient {
  MisePayClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<PaymentIntent> getPaymentIntent({
    required String requestUri,
    String? payerAddress,
  }) async {
    final uri = _buildRequestUri(requestUri, payerAddress);
    final response = await _httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MisePayException(
          'HTTP_ERROR', 'MisePay API returned status ${response.statusCode}.');
    }
    return PaymentIntent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
        httpClient: _httpClient);
  }

  Uri _buildRequestUri(String requestUri, String? payerAddress) {
    final uri = Uri.parse(requestUri);
    if (payerAddress == null) {
      return uri;
    }
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'payer_address': payerAddress
    });
  }
}
