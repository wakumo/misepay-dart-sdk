import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:misepay_sdk/misepay_sdk.dart';
import 'package:misepay_sdk/src/payment_intents/services/point_authorization_service.dart';
import 'package:test/test.dart';

void main() {
  group('MisePayClient.paymentIntents.get', () {
    test('uses built-in production origin when no origin config is provided',
        () async {
      final requestedUris = <Uri>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(_paymentIntentJson());
        }),
      );

      await client.paymentIntents.get(
        requestUri: 'https://apis.misepay.app/v1/payment-intents/pi_123',
      );

      expect(requestedUris.single.origin, 'https://apis.misepay.app');
    });

    test('fetches requestUri as-is when payerAddress is omitted', () async {
      final requestedUris = <Uri>[];
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(_paymentIntentJson());
        }),
      );

      final intent = await client.paymentIntents.get(
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
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(_paymentIntentJson(payer: _payerJson()));
        }),
      );

      final intent = await client.paymentIntents.get(
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
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(
              _paymentIntentJson(payer: _payerJson(address: '0xnew')));
        }),
      );

      await client.paymentIntents.get(
        requestUri:
            'https://api-dev.misepay.app/v1/payment-intents/pi_123?payer_address=0xold',
        payerAddress: '0xnew',
      );

      expect(requestedUris.single.queryParameters, {'payer_address': '0xnew'});
    });

    test('rejects requestUri from untrusted origin before fetching', () async {
      final requestedUris = <Uri>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(_paymentIntentJson());
        }),
      );

      await expectLater(
        client.paymentIntents.get(
          requestUri: 'https://evil.example/v1/payment-intents/pi_123',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'UNTRUSTED_REQUEST_ORIGIN')),
      );
      expect(requestedUris, isEmpty);
    });

    test('allows any requestUri origin when originPolicy is allowAll',
        () async {
      final requestedUris = <Uri>[];
      final client = MisePayClient(
        env: MisePayEnv.development,
        originPolicy: MisePayOriginPolicy.allowAll,
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(_paymentIntentJson());
        }),
      );

      await client.paymentIntents.get(
        requestUri: 'https://local-tunnel.example/v1/payment-intents/pi_123',
      );

      expect(requestedUris.single.origin, 'https://local-tunnel.example');
    });

    test('uses custom allowed origins in development environment', () async {
      final requestedUris = <Uri>[];
      final client = MisePayClient(
        env: MisePayEnv.development,
        allowedOrigins: {'https://dev-apis.misepay.app'},
        httpClient: MockClient((request) async {
          requestedUris.add(request.url);
          return _jsonResponse(_paymentIntentJson());
        }),
      );

      await client.paymentIntents.get(
        requestUri: 'https://dev-apis.misepay.app/v1/payment-intents/pi_123',
      );

      expect(requestedUris.single.origin, 'https://dev-apis.misepay.app');
    });
  });

  group('PaymentIntentsClient.authorizePoints', () {
    test('builds PaymentIntentPointAuthorization typed data', () {
      final client = MisePayClient();
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        paymentOption: intent.paymentOptions.single,
        pointAmount: '2',
      );

      expect(authorization.typedData['primaryType'],
          'PaymentIntentPointAuthorization');
      expect(authorization.typedData['domain'], {
        'name': 'MisePay PaymentIntent',
        'version': '1',
        'salt':
            '0x934a72bcfc23658c976948324c105b63256b1fd78f220a1ac53fba14c85c8502'
      });
      expect(authorization.message, {
        'intentId': 'pi_123',
        'payer': '0xabc',
        'grossAmount': '10500000000000000000',
        'pointAmount': '2000000000000000000',
        'netAmount': '8500000000000000000',
        'expiresAt': 1783339500,
      });
    });

    test('uses the current expected payment amount for net amount', () {
      final client = MisePayClient();
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        payer: _payerJson(),
        paymentOptionAmountBaseUnits: '7000000000000000000',
      ));

      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        paymentOption: intent.paymentOptions.single,
        pointAmount: '2',
      );

      expect(
          authorization.message,
          containsPair(
            'grossAmount',
            '10500000000000000000',
          ));
      expect(
          authorization.message,
          containsPair(
            'netAmount',
            '5000000000000000000',
          ));
    });

    test('uses development salt for development environment', () {
      final client = MisePayClient(env: MisePayEnv.development);
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        paymentOption: intent.paymentOptions.single,
        pointAmount: '2',
      );

      expect(authorization.typedData['domain'], {
        'name': 'MisePay PaymentIntent',
        'version': '1',
        'salt':
            '0x956d16453a66b1c31ac6741fde6c1954711bc88cabafd92ef642c2a8ef219d9d'
      });
    });

    test('hashes a custom domain salt label as Ethereum Keccak-256', () {
      const service = PointAuthorizationService(domainSalt: 'misepay:test');
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      final authorization = service.build(
        intent: intent,
        paymentOption: intent.paymentOptions.single,
        pointAmount: '2',
      );

      expect(authorization.typedData['domain'], {
        'name': 'MisePay PaymentIntent',
        'version': '1',
        'salt':
            '0xb6dce1b502f83af1b70625d604e6c7024247050c92d59830db9305b82da4ee9c'
      });
    });

    test('rejects missing payer context', () {
      final client = MisePayClient();
      final intent = PaymentIntent.fromJson(_paymentIntentJson());

      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          paymentOption: intent.paymentOptions.single,
          pointAmount: '2',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'PAYER_REQUIRED')),
      );
    });

    test('rejects payer context without address', () {
      final client = MisePayClient();
      final intent = PaymentIntent.fromJson(
          _paymentIntentJson(payer: _payerJson(address: null)));

      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          paymentOption: intent.paymentOptions.single,
          pointAmount: '2',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'PAYER_REQUIRED')),
      );
    });

    test('rejects invalid point amounts', () {
      final client = MisePayClient();
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          paymentOption: intent.paymentOptions.single,
          pointAmount: '-1',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'INVALID_POINT_AMOUNT')),
      );
      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: PaymentIntent.fromJson(
              _paymentIntentJson(payer: _payerJson(includeLimits: false))),
          paymentOption: intent.paymentOptions.single,
          pointAmount: '11',
        ),
        throwsA(isA<MisePayException>().having((error) => error.code, 'code',
            'POINT_AMOUNT_EXCEEDS_EXPECTED_PAYMENT')),
      );
      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          paymentOption: intent.paymentOptions.single,
          pointAmount: '2',
        ),
        returnsNormally,
      );
      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: PaymentIntent.fromJson(
              _paymentIntentJson(payer: _payerJson(intentAmount: '2'))),
          paymentOption: intent.paymentOptions.single,
          pointAmount: '2',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'POINT_AMOUNT_UNCHANGED')),
      );
    });

    test('rejects points above the current expected payment', () {
      final client = MisePayClient();
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        payer: _payerJson(includeLimits: false),
        paymentOptionAmountBaseUnits: '1000000000000000000',
      ));

      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          paymentOption: intent.paymentOptions.single,
          pointAmount: '2',
        ),
        throwsA(isA<MisePayException>().having(
          (error) => error.code,
          'code',
          'POINT_AMOUNT_EXCEEDS_EXPECTED_PAYMENT',
        )),
      );
    });

    test('rejects invalid current expected payment amount formats', () {
      final client = MisePayClient();
      final malformedAmounts = ['invalid', '+10', '-0', '0x10', ''];
      final actualCodes = <String, String>{};

      for (final amountBaseUnits in malformedAmounts) {
        final intent = PaymentIntent.fromJson(_paymentIntentJson(
          payer: _payerJson(),
          paymentOptionAmountBaseUnits: amountBaseUnits,
        ));

        try {
          client.paymentIntents.authorizePoints(
            paymentIntent: intent,
            paymentOption: intent.paymentOptions.single,
            pointAmount: '2',
          );
          actualCodes[amountBaseUnits] = 'returned normally';
        } on MisePayException catch (error) {
          actualCodes[amountBaseUnits] = error.code;
        }
      }

      expect(actualCodes, {
        for (final amountBaseUnits in malformedAmounts)
          amountBaseUnits: 'INVALID_EXPECTED_PAYMENT_AMOUNT',
      });
    });

    test('allows point authorization when limits are omitted', () {
      final client = MisePayClient();
      final intent = PaymentIntent.fromJson(
          _paymentIntentJson(payer: _payerJson(includeLimits: false)));

      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          paymentOption: intent.paymentOptions.single,
          pointAmount: '2',
        ),
        returnsNormally,
      );
    });
  });

  group('PaymentIntent serialization', () {
    test('round-trips typed response models to JSON', () {
      final json = _paymentIntentJson(payer: _payerJson());
      final intent = PaymentIntent.fromJson(json);

      expect(intent.toJson(), json);
    });

    test('parses and serializes payment option chain name', () {
      final json = _paymentIntentJson(chainName: 'Polygon');
      final intent = PaymentIntent.fromJson(json);

      expect(intent.paymentOptions.single.chainName, 'Polygon');
      expect(intent.toJson()['payment_options'], [
        containsPair('chain_name', 'Polygon'),
      ]);
    });
  });

  group('PaymentIntent action submissions', () {
    test('submits point authorization to action URL', () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(_paymentIntentJson(
              payer: _payerJson(intentAmount: '2', available: '3')));
        }),
      );
      final intent = PaymentIntent.fromJson(
          _paymentIntentJson(payer: _payerJson(intentAmount: '0')));
      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        paymentOption: intent.paymentOptions.single,
        pointAmount: '2',
      );

      final updated = await client.paymentIntents.applyPoints(
        paymentIntent: intent,
        authorization: authorization,
        signature: '0xsig',
      );

      expect(requests.single.url.toString(),
          'https://api-dev.misepay.app/v1/payment-intents/pi_123/benefits');
      expect(jsonDecode(requests.single.body), {
        'payer_address': '0xabc',
        'point_amount': '2',
        'signature': '0xsig',
      });
      expect(updated.payer?.point.intent.amount, '2');
    });

    test('submits transaction hash to action URL', () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse({
            ..._paymentIntentJson(payer: _payerJson()),
            'status': 'requires_payment'
          });
        }),
      );
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      final updated = await client.paymentIntents.provePayment(
        paymentIntent: intent,
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

    test('fails locally when point authorization action is unavailable',
        () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(_paymentIntentJson());
        }),
      );
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        payer: _payerJson(),
        actions: {
          'submit_point_authorization': null,
          'submit_payment_proof':
              'https://api-dev.misepay.app/v1/payment-intents/pi_123/payment-proofs',
        },
      ));
      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        paymentOption: intent.paymentOptions.single,
        pointAmount: '2',
      );

      await expectLater(
        client.paymentIntents.applyPoints(
          paymentIntent: intent,
          authorization: authorization,
          signature: '0xsig',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'ACTION_UNAVAILABLE')),
      );
      expect(requests, isEmpty);
    });

    test('fails locally when payment proof action is unavailable', () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(_paymentIntentJson());
        }),
      );
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        payer: _payerJson(),
        actions: {
          'submit_point_authorization':
              'https://api-dev.misepay.app/v1/payment-intents/pi_123/benefits',
          'submit_payment_proof': null,
        },
      ));

      await expectLater(
        client.paymentIntents.provePayment(
          paymentIntent: intent,
          chainId: 137,
          tokenAddress: '0xJPYCPolygon',
          txHash: '0xtx',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'ACTION_UNAVAILABLE')),
      );
      expect(requests, isEmpty);
    });

    test('preserves backend machine-readable error codes', () async {
      final client = MisePayClient(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 'invalid_signature',
              'message': 'Invalid point authorization signature.',
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));
      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        paymentOption: intent.paymentOptions.single,
        pointAmount: '2',
      );

      await expectLater(
        client.paymentIntents.applyPoints(
          paymentIntent: intent,
          authorization: authorization,
          signature: '0xbad',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'invalid_signature')),
      );
    });
  });
}

http.Response _jsonResponse(Map<String, dynamic> json) => http.Response(
      jsonEncode(json),
      200,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _paymentIntentJson({
  Map<String, dynamic>? payer,
  Map<String, dynamic>? actions,
  String? chainName,
  String paymentOptionAmountBaseUnits = '10500000000000000000',
}) {
  final json = {
    'version': 1,
    'id': 'pi_123',
    'status': 'pending',
    'merchant': {'name': 'Cafe ABC'},
    'store': {'name': 'Shibuya Store'},
    'amount': {
      'currency': 'JPY',
      'gross': '10.5',
      'benefit': payer == null ? '0' : '2',
      'net': payer == null ? '10.5' : '8.5'
    },
    'payment_options': [
      {
        'chain_id': 137,
        if (chainName != null) 'chain_name': chainName,
        'asset_symbol': 'JPYC',
        'asset_decimals': 18,
        'token_address': '0xJPYCPolygon',
        'recipient_address': '0xMerchantPolygon',
        'amount_base_units': paymentOptionAmountBaseUnits,
      },
    ],
    'actions': actions ??
        {
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
  return json;
}

Map<String, dynamic> _payerJson({
  String? address = '0xabc',
  String available = '5',
  String intentAmount = '0',
  bool includeLimits = true,
}) =>
    {
      'address': address,
      'point': {
        'label': 'MisePay Points',
        'balance': {'available': available},
        'intent': {'amount': intentAmount},
        if (includeLimits) 'limits': {'max': '10.5'},
      },
    };
