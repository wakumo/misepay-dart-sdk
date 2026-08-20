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
    test(
        'builds the first point authorization from canonical points without legacy payer',
        () {
      final client = MisePayClient();
      final json = _paymentIntentJson(points: _initialPointsJson())
        ..remove('payer');
      final intent = PaymentIntent.fromJson(json);

      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        pointAmount: '2',
      );

      expect(intent.payer, isNull);
      expect(intent.points?.authorization?.status, isNull);
      expect(authorization.payerAddress, '0xHolderA');
      expect(authorization.authorizationRevision, 1);
      expect(authorization.message, {
        'intentId': 'pi_123',
        'payer': '0xHolderA',
        'pointAmount': '2',
        'authorizationRevision': '1',
        'expiresAt': 1783339500,
      });
    });

    test(
        'builds point authorization from canonical points without legacy payer',
        () {
      final client = MisePayClient();
      final json = _paymentIntentJson(points: _pointsJson())..remove('payer');
      final intent = PaymentIntent.fromJson(json);

      final authorization = client.paymentIntents.authorizePoints(
        paymentIntent: intent,
        pointAmount: '2',
      );

      expect(intent.payer, isNull);
      expect(authorization.payerAddress, '0xHolderA');
      expect(authorization.authorizationRevision, 2);
      expect(authorization.message, {
        'intentId': 'pi_123',
        'payer': '0xHolderA',
        'pointAmount': '2',
        'authorizationRevision': '2',
        'expiresAt': 1783339500,
      });
    });

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
            {'name': 'authorizationRevision', 'type': 'uint256'},
            {'name': 'expiresAt', 'type': 'uint256'},
          ]);
      expect(authorization.message, {
        'intentId': 'pi_123',
        'payer': '0xabc',
        'pointAmount': '2',
        'authorizationRevision': '1',
        'expiresAt': 1783339500,
      });
      expect(authorization.authorizationRevision, 1);
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
          'authorizationRevision': '1',
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
        '-1',
        '100.0',
        '1,000',
        '+100',
        ' 100',
        '00',
        '01'
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
        client.paymentIntents
            .authorizePoints(
                paymentIntent: PaymentIntent.fromJson(
                    _paymentIntentJson(payer: _payerJson(intentAmount: '2'))),
                pointAmount: '0')
            .message['pointAmount'],
        '0',
      );
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

    test(
        'signs the next revision for increase, decrease, clear, and reapply targets',
        () {
      final client = MisePayClient();
      final cases = [
        (current: '1', target: '5', revision: 0),
        (current: '5', target: '2', revision: 1),
        (current: '2', target: '0', revision: 2),
        (current: '0', target: '3', revision: 3),
      ];

      for (final transition in cases) {
        final intent = PaymentIntent.fromJson(_paymentIntentJson(
          payer: _payerJson(
            intentAmount: transition.current,
            maxAmount: '5',
            revision: transition.revision,
          ),
        ));

        final authorization = client.paymentIntents.authorizePoints(
          paymentIntent: intent,
          pointAmount: transition.target,
        );

        expect(authorization.pointAmount, transition.target);
        expect(authorization.authorizationRevision, transition.revision + 1);
        expect(authorization.message['authorizationRevision'],
            (transition.revision + 1).toString());
      }
    });
  });

  group('PaymentIntent serialization', () {
    test('parses canonical points and amount aliases without legacy payer', () {
      final json = _paymentIntentJson(points: _pointsJson())..remove('payer');

      final intent = PaymentIntent.fromJson(json);

      expect(intent.payer, isNull);
      expect(intent.toJson()['points'], _pointsJson());
      expect(intent.toJson()['amount'], {
        'currency': 'JPY',
        'gross': '10',
        'benefit': '0',
        'net': '10',
        'point_discount': '0',
        'token_due': '10',
      });
    });

    test('accepts absent and null canonical points for staggered rollout', () {
      final absentJson = _paymentIntentJson()..remove('points');
      final nullJson = _paymentIntentJson()..['points'] = null;

      final absentIntent = PaymentIntent.fromJson(absentJson);
      final nullIntent = PaymentIntent.fromJson(nullJson);

      expect(absentIntent.toJson()['points'], isNull);
      expect(nullIntent.toJson()['points'], isNull);
    });

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

    test('parses and serializes the linked Order ID', () {
      final intent = PaymentIntent.fromJson(_paymentIntentJson());

      expect(intent.orderId, 'order_123');
      expect(intent.toJson()['order_id'], 'order_123');
    });

    test('accepts older payloads without the linked Order ID', () {
      final json = _paymentIntentJson()..remove('order_id');

      final intent = PaymentIntent.fromJson(json);

      expect(intent.orderId, isNull);
      expect(intent.toJson()['order_id'], isNull);
    });

    test('parses point-holder expiry and top-level reward context', () {
      final payer = _payerJson();
      final point = payer['point'] as Map<String, dynamic>;
      point['expiring_soon_lot'] = {
        'amount': '21000',
        'expires_at': '2026-10-15T00:00:00Z',
      };
      final json = _paymentIntentJson(payer: payer);
      json['reward'] = {
        'recipient_address': '0xTokenPayerB',
        'amount': '920',
        'status': 'pending',
        'available_at': '2026-11-25T12:02:00Z',
      };

      final intent = PaymentIntent.fromJson(json);

      expect(intent.payer?.point.expiringSoonLot?.amount, '21000');
      expect(
        intent.payer?.point.expiringSoonLot?.expiresAt,
        DateTime.parse('2026-10-15T00:00:00Z'),
      );
      expect(intent.payer?.address, '0xabc');
      expect(intent.reward?.recipientAddress, '0xTokenPayerB');
      expect(intent.reward?.amount, '920');
      expect(intent.reward?.status, RewardStatus.pending);
      expect(
        intent.reward?.availableAt,
        DateTime.parse('2026-11-25T12:02:00Z'),
      );
      json['points'] = null;
      expect(intent.toJson(), json);
    });

    test('parses an available top-level reward', () {
      final json = _paymentIntentJson();
      json['reward'] = {
        'recipient_address': '0xTokenPayerB',
        'amount': '920',
        'status': 'available',
        'available_at': '2026-11-25T12:02:00Z',
      };
      json['points'] = null;

      final intent = PaymentIntent.fromJson(json);

      expect(intent.reward?.status, RewardStatus.available);
      expect(intent.toJson(), json);
    });

    test('accepts absent and null reward context for staggered rollout', () {
      final absentPayer = _payerJson();
      final absentPoint = Map<String, dynamic>.from(
        absentPayer['point'] as Map<String, dynamic>,
      );
      absentPayer['point'] = absentPoint;
      absentPoint.remove('expiring_soon_lot');
      final nullPayer = _payerJson();
      final nullPoint = Map<String, dynamic>.from(
        nullPayer['point'] as Map<String, dynamic>,
      );
      nullPayer['point'] = nullPoint;
      nullPoint['expiring_soon_lot'] = null;
      final absentJson = _paymentIntentJson(payer: absentPayer)
        ..remove('reward');
      final nullJson = _paymentIntentJson(payer: nullPayer)..['reward'] = null;

      final absentIntent = PaymentIntent.fromJson(absentJson);
      final nullIntent = PaymentIntent.fromJson(nullJson);

      expect(absentIntent.payer?.point.expiringSoonLot, isNull);
      expect(nullIntent.payer?.point.expiringSoonLot, isNull);
      expect(absentIntent.reward, isNull);
      expect(nullIntent.reward, isNull);
      expect(
          (absentIntent.toJson()['payer'] as Map<String, dynamic>)['point'], {
        ...absentPoint,
        'expiring_soon_lot': null,
      });
      expect(absentIntent.toJson()['reward'], isNull);
    });

    test('defaults missing confirmed payment history to an empty list', () {
      final json = _paymentIntentJson()..remove('confirmed_payments');

      final intent = PaymentIntent.fromJson(json);

      expect(intent.confirmedPayments, isEmpty);
      expect(intent.toJson()['confirmed_payments'], isEmpty);
    });

    test('parses point-only completion with empty confirmed payment history',
        () {
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        status: 'completed',
        paymentOptions: [],
        confirmedPayments: [],
        gross: '15',
        benefit: '15',
        net: '0',
      ));

      expect(intent.paymentOptions, isEmpty);
      expect(intent.confirmedPayments, isEmpty);
    });

    test('parses and serializes exact confirmed payment fields', () {
      final receipt = _confirmedPaymentJson(
        chainId: 97,
        fromAddress: '0xSenderB',
        txHash:
            '0x1111111111111111111111111111111111111111111111111111111111111111',
        logIndex: 0,
        blockTimestamp: '2026-08-11T10:00:00Z',
      );

      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        status: 'completed',
        paymentOptions: [],
        confirmedPayments: [receipt],
      ));
      final confirmedPayment = intent.confirmedPayments.single;

      expect(confirmedPayment.chainId, 97);
      expect(confirmedPayment.assetSymbol, 'JPYC');
      expect(confirmedPayment.assetDecimals, 18);
      expect(confirmedPayment.tokenAddress, '0x409eToken');
      expect(confirmedPayment.fromAddress, '0xSenderB');
      expect(confirmedPayment.amountBaseUnits, '15000000000000000000');
      expect(confirmedPayment.txHash,
          '0x1111111111111111111111111111111111111111111111111111111111111111');
      expect(confirmedPayment.logIndex, 0);
      expect(confirmedPayment.blockTimestamp,
          DateTime.parse('2026-08-11T10:00:00Z'));
      expect(intent.toJson()['confirmed_payments'], [receipt]);
    });

    test('keeps sender additive for older confirmed payment payloads', () {
      final receipt = _confirmedPaymentJson(
        chainId: 137,
        txHash:
            '0x2222222222222222222222222222222222222222222222222222222222222222',
        logIndex: 1,
        blockTimestamp: '2026-08-11T10:00:00Z',
      )..remove('from_address');

      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        status: 'completed',
        paymentOptions: [],
        payer: _payerJson(address: '0xHolderA'),
        confirmedPayments: [receipt],
      ));

      expect(intent.payer?.address, '0xHolderA');
      expect(intent.confirmedPayments.single.fromAddress, isNull);
      expect(intent.toJson()['confirmed_payments'], [
        {...receipt, 'from_address': null},
      ]);
    });

    test('round-trips multiple confirmed payments in API order', () {
      final receipts = [
        _confirmedPaymentJson(
          chainId: 56,
          txHash:
              '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          logIndex: 7,
          blockTimestamp: '2026-08-11T09:59:00Z',
        ),
        _confirmedPaymentJson(
          chainId: 1,
          txHash:
              '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          logIndex: 2,
          blockTimestamp: '2026-08-11T10:00:00Z',
        ),
      ];

      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        status: 'completed',
        paymentOptions: [],
        confirmedPayments: receipts,
      ));

      expect(intent.confirmedPayments.map((payment) => payment.chainId),
          orderedEquals([56, 1]));
      expect(intent.confirmedPayments.last.amountBaseUnits,
          '15000000000000000000');
      expect(intent.toJson()['confirmed_payments'], receipts);
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

    test('parses and serializes terminal timestamps', () {
      final intent = PaymentIntent.fromJson(_paymentIntentJson(
        status: 'completed',
        completedAt: '2026-08-11T03:04:05.006Z',
        cancelledAt: '2026-08-11T04:05:06.007Z',
      ));

      expect(intent.completedAt, DateTime.parse('2026-08-11T03:04:05.006Z'));
      expect(intent.cancelledAt, DateTime.parse('2026-08-11T04:05:06.007Z'));
      expect(intent.toJson()['completed_at'], '2026-08-11T03:04:05.006Z');
      expect(intent.toJson()['cancelled_at'], '2026-08-11T04:05:06.007Z');
    });

    test('accepts missing and null terminal timestamps', () {
      final missingJson = _paymentIntentJson()
        ..remove('completed_at')
        ..remove('cancelled_at');
      final missingIntent = PaymentIntent.fromJson(missingJson);
      final nullIntent = PaymentIntent.fromJson(_paymentIntentJson(
        completedAt: null,
        cancelledAt: null,
      ));

      expect(missingIntent.completedAt, isNull);
      expect(missingIntent.cancelledAt, isNull);
      expect(nullIntent.completedAt, isNull);
      expect(nullIntent.cancelledAt, isNull);
      expect(missingIntent.toJson()['completed_at'], isNull);
      expect(missingIntent.toJson()['cancelled_at'], isNull);
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
      final expectedPayer = Map<String, dynamic>.from(
        json['payer'] as Map<String, dynamic>,
      );
      final expectedPoint = Map<String, dynamic>.from(
        expectedPayer['point'] as Map<String, dynamic>,
      );
      expectedPayer['point'] = expectedPoint;
      expectedPoint['expiring_soon_lot'] = null;
      json['payer'] = expectedPayer;
      json['points'] = null;
      json['reward'] = null;

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
        'authorization_revision': 1,
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
        'authorization_revision': 1,
        'signature': '0xsig',
      });
      expect(payload.values, isNot(contains('100000000')));
      expect(updated.paymentOptions.single.amountBaseUnits, '100000000');
      expect(updated.payer?.point.authorization.amount, '100');
    });

    test('submits connected wallet B only as optional proof response context',
        () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(
            _paymentIntentJson(
              payer: _payerJson(address: '0xHolderA'),
              status: 'completed',
              paymentOptions: [],
              confirmedPayments: [
                _confirmedPaymentJson(
                  chainId: 137,
                  fromAddress: '0xSenderB',
                  txHash: '0xtx',
                  logIndex: 4,
                  blockTimestamp: '2026-08-11T10:00:00Z',
                ),
              ],
            ),
            statusCode: 202,
          );
        }),
      );
      final intent = PaymentIntent.fromJson(
        _paymentIntentJson(payer: _payerJson(address: '0xHolderA')),
      );

      final updated = await client.paymentIntents.provePayment(
        paymentIntent: intent,
        chainId: 137,
        tokenAddress: '0xJPYCPolygon',
        txHash: '0xtx',
        payerAddress: '0xConnectedB',
      );

      expect(requests.single.url.toString(),
          'https://api-dev.misepay.app/v1/payment-intents/pi_123/payment-proofs');
      expect(jsonDecode(requests.single.body), {
        'chain_id': 137,
        'token_address': '0xJPYCPolygon',
        'tx_hash': '0xtx',
        'payer_address': '0xConnectedB',
      });
      expect(updated.payer?.address, '0xHolderA');
      expect(updated.confirmedPayments.single.fromAddress, '0xSenderB');
    });

    test('does not infer proof payer context from the bound point holder',
        () async {
      final requests = <http.Request>[];
      final client = MisePayClient(
        allowedOrigins: {'https://api-dev.misepay.app'},
        httpClient: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(
            _paymentIntentJson(payer: _payerJson(address: '0xHolderA')),
            statusCode: 202,
          );
        }),
      );
      final intent = PaymentIntent.fromJson(
        _paymentIntentJson(payer: _payerJson(address: '0xHolderA')),
      );

      await client.paymentIntents.provePayment(
        paymentIntent: intent,
        chainId: 137,
        tokenAddress: '0xJPYCPolygon',
        txHash: '0xtx',
      );

      expect(jsonDecode(requests.single.body), {
        'chain_id': 137,
        'token_address': '0xJPYCPolygon',
        'tx_hash': '0xtx',
      });
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
  Map<String, dynamic>? points,
  Map<String, dynamic>? actions,
  List<Map<String, dynamic>>? paymentOptions,
  List<Map<String, dynamic>>? confirmedPayments,
  String status = 'pending',
  String? chainName,
  String gross = '10',
  String? benefit,
  String? net,
  int assetDecimals = 18,
  String paymentOptionAmountBaseUnits = '10500000000000000000',
  String? createdAt = '2026-08-10T04:00:00Z',
  String? completedAt,
  String? cancelledAt,
  String? merchantImageUrl,
  String? storeImageUrl,
}) {
  final json = {
    'version': 1,
    'id': 'pi_123',
    'order_id': 'order_123',
    'request_uri': 'https://api-dev.misepay.app/v1/payment-intents/pi_123',
    'status': status,
    'merchant': {'name': 'Cafe ABC', 'image_url': merchantImageUrl},
    'store': {'name': 'Shibuya Store', 'image_url': storeImageUrl},
    'payer': payer,
    if (points != null) 'points': points,
    'amount': {
      'currency': 'JPY',
      'gross': gross,
      'benefit': benefit ?? (payer == null ? '0' : '2'),
      'net': net ?? (payer == null ? gross : '8'),
      'point_discount': benefit ?? (payer == null ? '0' : '2'),
      'token_due': net ?? (payer == null ? gross : '8'),
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
    'confirmed_payments': confirmedPayments ?? [],
    'actions': actions ??
        {
          'submit_point_authorization':
              'https://api-dev.misepay.app/v1/payment-intents/pi_123/benefits',
          'submit_payment_proof':
              'https://api-dev.misepay.app/v1/payment-intents/pi_123/payment-proofs',
        },
    'created_at': createdAt,
    'completed_at': completedAt,
    'cancelled_at': cancelledAt,
    'expires_at': '2026-07-06T12:05:00Z',
  };
  return json;
}

Map<String, dynamic> _confirmedPaymentJson({
  required int chainId,
  required String txHash,
  required int logIndex,
  required String blockTimestamp,
  String fromAddress = '0xSender',
}) =>
    {
      'chain_id': chainId,
      'asset_symbol': 'JPYC',
      'asset_decimals': 18,
      'token_address': '0x409eToken',
      'from_address': fromAddress,
      'amount_base_units': '15000000000000000000',
      'tx_hash': txHash,
      'log_index': logIndex,
      'block_timestamp': blockTimestamp,
    };

Map<String, dynamic> _payerJson({
  String? address = '0xabc',
  String available = '5',
  String intentAmount = '0',
  String maxAmount = '10',
  int revision = 0,
}) =>
    {
      'address': address,
      'point': {
        'label': 'MisePay Points',
        'balance': {'available': available},
        'authorization': {
          'amount': intentAmount,
          'max_amount': maxAmount,
          'revision': revision
        },
      },
    };

Map<String, dynamic> _pointsJson() => {
      'account': {
        'holder_address': '0xHolderA',
        'label': 'MisePay Points',
        'available_balance': '5',
        'expiring_soon_lot': {
          'amount': '5',
          'expires_at': '2026-10-15T00:00:00Z',
        },
      },
      'authorization': {
        'holder_address': '0xHolderA',
        'amount': '1',
        'maximum_amount': '5',
        'revision': 1,
        'status': 'reserved',
      },
    };

Map<String, dynamic> _initialPointsJson() => {
      'account': {
        'holder_address': '0xHolderA',
        'label': 'MisePay Points',
        'available_balance': '5',
        'expiring_soon_lot': null,
      },
      'authorization': {
        'holder_address': '0xHolderA',
        'amount': '0',
        'maximum_amount': '5',
        'revision': 0,
        'status': null,
      },
    };
