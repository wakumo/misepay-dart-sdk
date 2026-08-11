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

    test('parses pollable terminal resources with unavailable actions',
        () async {
      for (final status in [
        PaymentIntentStatus.completed,
        PaymentIntentStatus.expired,
        PaymentIntentStatus.cancelled,
        PaymentIntentStatus.reviewRequired,
      ]) {
        final client = MisePayClient(
          allowedOrigins: {'https://api-dev.misepay.app'},
          httpClient: MockClient((request) async {
            return _jsonResponse(_paymentIntentJson(
              status: status.value,
              payer: _payerJson(intentAmount: '2'),
              paymentOptions: const [],
              actions: const {
                'submit_point_authorization': null,
                'submit_payment_proof': null,
              },
            ));
          }),
        );

        final intent = await client.paymentIntents.get(
          requestUri: 'https://api-dev.misepay.app/v1/payment-intents/pi_123',
          payerAddress: '0xabc',
        );

        expect(intent.status, status);
        expect(intent.paymentOptions, isEmpty);
        expect(intent.actions.submitPointAuthorization, isNull);
        expect(intent.actions.submitPaymentProof, isNull);
        expect(intent.requestUri,
            'https://api-dev.misepay.app/v1/payment-intents/pi_123');
        expect(intent.payer?.point.authorization.amount, '2');
        expect(intent.toJson()['actions'], {
          'submit_point_authorization': null,
          'submit_payment_proof': null,
        });
      }
    });
  });

  group('PaymentIntentsClient.authorizePoints', () {
    test('builds PaymentIntentPointAuthorization typed data', () {
      final client = MisePayClient();
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
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
      expect(
          (authorization.typedData['types']
              as Map<String, dynamic>)['EIP712Domain'],
          [
            {'name': 'name', 'type': 'string'},
            {'name': 'version', 'type': 'string'},
            {'name': 'salt', 'type': 'bytes32'},
          ]);
      expect(
          (authorization.typedData['types']
              as Map<String, dynamic>)['PaymentIntentPointAuthorization'],
          [
            {'name': 'intentId', 'type': 'string'},
            {'name': 'payer', 'type': 'address'},
            {'name': 'pointAmount', 'type': 'uint256'},
            {'name': 'expiresAt', 'type': 'uint256'},
          ]);
      expect(authorization.message, {
        'intentId': 'pi_123',
        'payer': '0xabc',
        'pointAmount': '2',
        'expiresAt': 1783339500,
      });
    });

    test('keeps 100 points unscaled for 6- and 18-decimal payment options', () {
      final client = MisePayClient();
      final fixtures = [
        (decimals: 6, baseUnits: '100000000'),
        (decimals: 18, baseUnits: '100000000000000000000'),
      ];

      for (final fixture in fixtures) {
        final intent = PaymentIntent.fromJson(_paymentIntentJson(
          payer:
              _payerJson(intentAmount: '0', available: '500', maxAmount: '500'),
          gross: '200',
          benefit: '100',
          net: '100',
          assetDecimals: fixture.decimals,
          paymentOptionAmountBaseUnits: fixture.baseUnits,
        ));

        final authorization = client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          pointAmount: '100',
        );

        expect(authorization.message, {
          'intentId': 'pi_123',
          'payer': '0xabc',
          'pointAmount': '100',
          'expiresAt': 1783339500,
        });
        expect(intent.paymentOptions.single.assetDecimals, fixture.decimals);
        expect(intent.paymentOptions.single.amountBaseUnits, fixture.baseUnits);
        expect(
            authorization.message.values, isNot(contains(fixture.baseUnits)));
        expect(authorization.pointAmount, '100');
      }
    });

    test('uses development salt for development environment', () {
      final client = MisePayClient(env: MisePayEnv.development);
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
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

      for (final malformedPointAmount in [
        '0',
        '-1',
        '100.0',
        '1,000',
        '+100',
        ' 100'
      ]) {
        expect(
          () => client.paymentIntents.authorizePoints(
            paymentIntent: intent,
            pointAmount: malformedPointAmount,
          ),
          throwsA(isA<MisePayException>()
              .having((error) => error.code, 'code', 'INVALID_POINT_AMOUNT')),
        );
      }
      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: PaymentIntent.fromJson(_paymentIntentJson(
              payer: _payerJson(maxAmount: '20'), gross: '10.5')),
          pointAmount: '11',
        ),
        returnsNormally,
      );
      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          pointAmount: '2',
        ),
        returnsNormally,
      );
      expect(
        () => client.paymentIntents.authorizePoints(
          paymentIntent: PaymentIntent.fromJson(
              _paymentIntentJson(payer: _payerJson(intentAmount: '2'))),
          pointAmount: '2',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'POINT_AMOUNT_UNCHANGED')),
      );
    });

    test('requires point authorization max_amount in payer responses', () {
      final payer = _payerJson();
      (payer['point'] as Map<String, dynamic>)['authorization'] = {
        'amount': '0'
      };

      expect(
        () => PaymentIntent.fromJson(_paymentIntentJson(payer: payer)),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('PaymentIntent serialization', () {
    test('preserves explicit null payer context', () {
      final intent = PaymentIntent.fromJson(_paymentIntentJson());

      expect(intent.payer, isNull);
      expect(intent.toJson(), containsPair('payer', null));
    });

    test('requires request_uri in version 1 payloads', () {
      final json = _paymentIntentJson()..remove('request_uri');

      expect(
        () => PaymentIntent.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('exposes requestUri from the canonical response field', () {
      final intent = PaymentIntent.fromJson(_paymentIntentJson());

      expect(intent.requestUri,
          'https://api-dev.misepay.app/v1/payment-intents/pi_123');
    });

    test('parses and serializes persisted creation and display metadata', () {
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        createdAt: '2026-08-10T04:00:00.009Z',
        merchantImageUrl: 'https://cdn.example.com/merchant.jpg',
        storeImageUrl: 'https://cdn.example.com/store.jpg',
      ));

      expect(intent.createdAt, DateTime.parse('2026-08-10T04:00:00.009Z'));
      expect(intent.merchant.imageUrl, 'https://cdn.example.com/merchant.jpg');
      expect(intent.store.imageUrl, 'https://cdn.example.com/store.jpg');
      expect(intent.toJson()['created_at'], '2026-08-10T04:00:00.009Z');
      expect(intent.toJson()['merchant'], {
        'name': 'Cafe ABC',
        'image_url': 'https://cdn.example.com/merchant.jpg',
      });
      expect(intent.toJson()['store'], {
        'name': 'Shibuya Store',
        'image_url': 'https://cdn.example.com/store.jpg',
      });
    });

    test('accepts older payloads without creation or image metadata', () {
      final json = _paymentIntentJson()..remove('created_at');
      (json['merchant'] as Map<String, dynamic>).remove('image_url');
      (json['store'] as Map<String, dynamic>).remove('image_url');

      final intent = PaymentIntent.fromJson(json);

      expect(intent.createdAt, isNull);
      expect(intent.merchant.imageUrl, isNull);
      expect(intent.store.imageUrl, isNull);
      expect(intent.toJson()['created_at'], isNull);
      expect(intent.toJson()['merchant'], {
        'name': 'Cafe ABC',
        'image_url': null,
      });
      expect(intent.toJson()['store'], {
        'name': 'Shibuya Store',
        'image_url': null,
      });
    });

    test('normalizes null and blank display metadata as unavailable', () {
      final nullIntent = PaymentIntent.fromJson(_paymentIntentJson(
        createdAt: null,
        merchantImageUrl: null,
        storeImageUrl: null,
      ));
      final blankJson = _paymentIntentJson();
      (blankJson['merchant'] as Map<String, dynamic>)['image_url'] = '   ';
      (blankJson['store'] as Map<String, dynamic>)['image_url'] = '';
      final blankIntent = PaymentIntent.fromJson(blankJson);

      expect(nullIntent.createdAt, isNull);
      expect(nullIntent.merchant.imageUrl, isNull);
      expect(nullIntent.store.imageUrl, isNull);
      expect(blankIntent.merchant.imageUrl, isNull);
      expect(blankIntent.store.imageUrl, isNull);
    });

    test('accepts PaymentIntent payload version 1', () {
      final intent = PaymentIntent.fromJson(_paymentIntentJson());

      expect(intent.version, 1);
    });

    test('rejects unsupported PaymentIntent payload versions', () {
      expect(
        () => PaymentIntent.fromJson({..._paymentIntentJson(), 'version': 2}),
        throwsA(isA<MisePayException>().having(
          (error) => error.code,
          'code',
          'UNSUPPORTED_PAYMENT_INTENT_VERSION',
        )),
      );
    });

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
        allowedOrigins: {'https://api-dev.misepay.app'},
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
      expect(updated.payer?.point.authorization.amount, '2');
      expect(updated.status, PaymentIntentStatus.pending);
      expect(updated.requestUri,
          'https://api-dev.misepay.app/v1/payment-intents/pi_123');
    });

    test('submits point authorization in point units for 6-decimal JPYC',
        () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(_paymentIntentJson(
            payer: _payerJson(
                intentAmount: '100', available: '500', maxAmount: '500'),
            gross: '200',
            benefit: '100',
            net: '100',
            assetDecimals: 6,
            paymentOptionAmountBaseUnits: '100000000',
          ));
        }),
      );
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        payer:
            _payerJson(intentAmount: '0', available: '500', maxAmount: '500'),
        gross: '200',
        benefit: '100',
        net: '100',
        assetDecimals: 6,
        paymentOptionAmountBaseUnits: '100000000',
      ));
      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        pointAmount: '100',
      );

      final updated = await client.paymentIntents.applyPoints(
        paymentIntent: intent,
        authorization: authorization,
        signature: '0xsig',
      );

      final payload = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(payload, {
        'payer_address': '0xabc',
        'point_amount': '100',
        'signature': '0xsig',
      });
      expect(payload.values, isNot(contains('100000000')));
      expect(updated.paymentOptions.single.amountBaseUnits, '100000000');
      expect(updated.payer?.point.authorization.amount, '100');
    });

    test('submits transaction hash to action URL', () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(
            {..._paymentIntentJson(payer: _payerJson()), 'status': 'pending'},
            statusCode: 202,
          );
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
      expect(updated.status, PaymentIntentStatus.pending);
    });

    test('rejects point authorization action from an untrusted origin',
        () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(_paymentIntentJson());
        }),
      );
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        payer: _payerJson(),
        actions: {
          'submit_point_authorization':
              'https://evil.example/v1/payment-intents/pi_123/benefits',
          'submit_payment_proof':
              'https://api-dev.misepay.app/v1/payment-intents/pi_123/payment-proofs',
        },
      ));
      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        pointAmount: '2',
      );

      await expectLater(
        client.paymentIntents.applyPoints(
          paymentIntent: intent,
          authorization: authorization,
          signature: '0xsig',
        ),
        throwsA(isA<MisePayException>()
            .having((error) => error.code, 'code', 'UNTRUSTED_REQUEST_ORIGIN')),
      );
      expect(requests, isEmpty);
    });

    test('rejects payment proof action from an untrusted origin', () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
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
          'submit_payment_proof':
              'https://evil.example/v1/payment-intents/pi_123/payment-proofs',
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
            .having((error) => error.code, 'code', 'UNTRUSTED_REQUEST_ORIGIN')),
      );
      expect(requests, isEmpty);
    });

    test('accepts a completed payment proof response', () async {
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          return _jsonResponse({
            ..._paymentIntentJson(payer: _payerJson()),
            'status': 'completed'
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

      expect(updated.status, PaymentIntentStatus.completed);
    });

    test('preserves payment proof reuse errors from the backend', () async {
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'statusCode': 409,
              'message': 'PAYMENT_PROOF_TRANSACTION_ALREADY_USED',
              'error': 'Conflict',
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final intent =
          PaymentIntent.fromJson(_paymentIntentJson(payer: _payerJson()));

      await expectLater(
        client.paymentIntents.provePayment(
          paymentIntent: intent,
          chainId: 137,
          tokenAddress: '0xJPYCPolygon',
          txHash: '0xtx',
        ),
        throwsA(isA<MisePayException>().having(
          (error) => error.code,
          'code',
          'PAYMENT_PROOF_TRANSACTION_ALREADY_USED',
        )),
      );
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
        allowedOrigins: {'https://api-dev.misepay.app'},
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

http.Response _jsonResponse(Map<String, dynamic> json,
        {int statusCode = 200}) =>
    http.Response(
      jsonEncode(json),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _paymentIntentJson({
  Map<String, dynamic>? payer,
  Map<String, dynamic>? actions,
  List<Map<String, dynamic>>? paymentOptions,
  String status = 'pending',
  String? chainName,
  String gross = '10',
  String? benefit,
  String? net,
  int assetDecimals = 18,
  String paymentOptionAmountBaseUnits = '10500000000000000000',
  String? createdAt = '2026-08-10T04:00:00Z',
  String? merchantImageUrl,
  String? storeImageUrl,
}) {
  final json = {
    'version': 1,
    'id': 'pi_123',
    'request_uri': 'https://api-dev.misepay.app/v1/payment-intents/pi_123',
    'status': status,
    'merchant': {'name': 'Cafe ABC', 'image_url': merchantImageUrl},
    'store': {'name': 'Shibuya Store', 'image_url': storeImageUrl},
    'payer': payer,
    'amount': {
      'currency': 'JPY',
      'gross': gross,
      'benefit': benefit ?? (payer == null ? '0' : '2'),
      'net': net ?? (payer == null ? gross : '8')
    },
    'payment_options': paymentOptions ??
        [
          {
            'chain_id': 137,
            if (chainName != null) 'chain_name': chainName,
            'asset_symbol': 'JPYC',
            'asset_decimals': assetDecimals,
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
    'created_at': createdAt,
    'expires_at': '2026-07-06T12:05:00Z',
  };
  return json;
}

Map<String, dynamic> _payerJson({
  String? address = '0xabc',
  String available = '5',
  String intentAmount = '0',
  String maxAmount = '10',
}) =>
    {
      'address': address,
      'point': {
        'label': 'MisePay Points',
        'balance': {'available': available},
        'authorization': {'amount': intentAmount, 'max_amount': maxAmount},
      },
    };
