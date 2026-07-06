import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:misepay_sdk/misepay_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('MisePayClient.getPaymentIntent', () {
    test('fetches requestUri as-is when payerAddress is omitted', () async {
      final requestedUris = <Uri>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(_paymentIntentJson());
        }),
      );

      final intent = await client.getPaymentIntent(
        requestUri:
            'https://api-dev.misepay.app/v1/payment-intents/pi_123?locale=ja',
      );

      expect(requestedUris.single.toString(),
          'https://api-dev.misepay.app/v1/payment-intents/pi_123?locale=ja');
      expect(intent.id, 'pi_123');
      expect(intent.payer, isNull);
    });

    test('adds payer_address while preserving existing query params', () async {
      final requestedUris = <Uri>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(_paymentIntentJson(payer: _payerJson()));
        }),
      );

      final intent = await client.getPaymentIntent(
        requestUri:
            'https://api-dev.misepay.app/v1/payment-intents/pi_123?locale=ja',
        payerAddress: '0xabc',
      );

      expect(requestedUris.single.queryParameters,
          {'locale': 'ja', 'payer_address': '0xabc'});
      expect(intent.payer?.address, '0xabc');
    });

    test('replaces an existing payer_address query param', () async {
      final requestedUris = <Uri>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(
              _paymentIntentJson(payer: _payerJson(address: '0xnew')));
        }),
      );

      await client.getPaymentIntent(
        requestUri:
            'https://api-dev.misepay.app/v1/payment-intents/pi_123?payer_address=0xold',
        payerAddress: '0xnew',
      );

      expect(requestedUris.single.queryParameters, {'payer_address': '0xnew'});
    });
  });

  group('PaymentIntent.buildPointAuthorization', () {
    test('builds PaymentIntentPointAuthorization typed data', () {
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      final authorization = intent.buildPointAuthorization(pointAmount: '1200');

      expect(authorization.typedData['primaryType'],
          'PaymentIntentPointAuthorization');
      expect(authorization.typedData['domain'],
          {'name': 'MisePay PaymentIntent', 'version': '1'});
      expect(authorization.message, {
        'intentId': 'pi_123',
        'payer': '0xabc',
        'grossAmount': '3000',
        'pointAmount': '1200',
        'netAmount': '1800',
        'expiresAt': 1783339500,
      });
    });

    test('rejects missing payer context', () {
      final intent = PaymentIntent.fromJson(_paymentIntentJson());

      expect(
        () => intent.buildPointAuthorization(pointAmount: '1200'),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'PAYER_REQUIRED')),
      );
    });

    test('rejects invalid point amounts', () {
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      expect(
        () => intent.buildPointAuthorization(pointAmount: '-1'),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'INVALID_POINT_AMOUNT')),
      );
      expect(
        () => intent.buildPointAuthorization(pointAmount: '3001'),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'POINT_AMOUNT_EXCEEDS_MAX')),
      );
      expect(
        () => intent.buildPointAuthorization(pointAmount: '1200'),
        returnsNormally,
      );
      expect(
        () => PaymentIntent.fromJson(
                _paymentIntentJson(payer: _payerJson(intentAmount: '1200')))
            .buildPointAuthorization(pointAmount: '1200'),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'POINT_AMOUNT_UNCHANGED')),
      );
    });
  });

  group('PaymentIntent action submissions', () {
    test('submits point authorization to action URL', () async {
      final requests = <http.Request>[];
      final intent = PaymentIntent.fromJson(
        _paymentIntentJson(
          payer: _payerJson(intentAmount: '0'),
          httpClient: MockClient((request) async {
            requests.add(request);
            return _jsonResponse(_paymentIntentJson(
                payer: _payerJson(intentAmount: '1200', available: '3800')));
          }),
        ),
      );
      final authorization = intent.buildPointAuthorization(pointAmount: '1200');

      final updated = await intent.submitPointAuthorization(
        authorization: authorization,
        signature: '0xsig',
      );

      expect(requests.single.url.toString(),
          'https://api-dev.misepay.app/v1/payment-intents/pi_123/benefits');
      expect(jsonDecode(requests.single.body), {
        'payer_address': '0xabc',
        'point_amount': '1200',
        'signature': '0xsig',
      });
      expect(updated.payer?.point.intent.amount, '1200');
    });

    test('submits transaction hash to action URL', () async {
      final requests = <http.Request>[];
      final intent = PaymentIntent.fromJson(
        _paymentIntentJson(
          payer: _payerJson(),
          httpClient: MockClient((request) async {
            requests.add(request);
            return _jsonResponse({
              ..._paymentIntentJson(payer: _payerJson()),
              'status': 'requires_payment'
            });
          }),
        ),
      );

      final updated = await intent.submitTransactionHash(
        chainId: 137,
        tokenAddress: '0xJPYCPolygon',
        txHash: '0xtx',
      );

      expect(requests.single.url.toString(),
          'https://api-dev.misepay.app/v1/payment-intents/pi_123/payment-proofs');
      expect(jsonDecode(requests.single.body), {
        'chain_id': 137,
        'token_address': '0xJPYCPolygon',
        'tx_hash': '0xtx',
      });
      expect(updated.status, PaymentIntentStatus.requiresPayment);
    });
  });
}

http.Response _jsonResponse(Map<String, dynamic> json) => http.Response(
      jsonEncode(json),
      200,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _paymentIntentJson(
    {Map<String, dynamic>? payer, http.Client? httpClient}) {
  final json = {
    'version': 1,
    'id': 'pi_123',
    'status': 'pending',
    'merchant': {'name': 'Cafe ABC'},
    'store': {'name': 'Shibuya Store'},
    'amount': {
      'currency': 'JPY',
      'gross': '3000',
      'benefit': payer == null ? '0' : '1200',
      'net': payer == null ? '3000' : '1800'
    },
    'payment_options': [
      {
        'chain_id': 137,
        'chain_name': 'Polygon',
        'asset_symbol': 'JPYC',
        'asset_decimals': 18,
        'token_address': '0xJPYCPolygon',
        'recipient_address': '0xMerchantPolygon',
        'amount_base_units':
            payer == null ? '3000000000000000000000' : '1800000000000000000000',
      },
    ],
    'actions': {
      'submit_point_authorization':
          'https://api-dev.misepay.app/v1/payment-intents/pi_123/benefits',
      'submit_payment_proof':
          'https://api-dev.misepay.app/v1/payment-intents/pi_123/payment-proofs',
    },
    'expires_at': '2026-07-06T12:05:00Z',
  };
  if (payer != null) {
    json['payer'] = payer;
  }
  if (httpClient != null) {
    json['__http_client'] = httpClient;
  }
  return json;
}

Map<String, dynamic> _payerJson(
        {String address = '0xabc',
        String available = '5000',
        String intentAmount = '0'}) =>
    {
      'address': address,
      'point': {
        'label': 'MisePay Points',
        'balance': {'available': available},
        'intent': {'amount': intentAmount},
        'limits': {'max': '3000'},
      },
    };
