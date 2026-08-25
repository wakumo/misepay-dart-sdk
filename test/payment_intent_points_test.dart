import 'package:misepay_sdk/misepay_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('PaymentIntentPointAccount nextExpiration', () {
    test('parses and serializes the canonical JST expiration', () {
      final account = PaymentIntentPointAccount.fromJson({
        'holder_address': '0xabc',
        'label': 'MisePay Points',
        'available_balance': '5000',
        'expiring_soon_lot': null,
        'next_expiration': {
          'amount': '2100',
          'valid_through': '2026-10-15',
          'expires_at': '2026-10-16T00:00:00+09:00',
        },
      });

      expect(account.nextExpiration?.amount, '2100');
      expect(account.nextExpiration?.validThrough, '2026-10-15');
      expect(account.nextExpiration?.expiresAt,
          DateTime.parse('2026-10-15T15:00:00Z'));
      expect(account.toJson()['next_expiration'], {
        'amount': '2100',
        'valid_through': '2026-10-15',
        'expires_at': '2026-10-16T00:00:00.000+09:00',
      });
    });

    test('accepts absent and null fields', () {
      Map<String, dynamic> json([Object? value = const Object()]) => {
            'holder_address': '0xabc',
            'label': 'MisePay Points',
            'available_balance': '0',
            'expiring_soon_lot': null,
            if (value is! Object) 'next_expiration': value,
          };

      expect(PaymentIntentPointAccount.fromJson(json()).nextExpiration, isNull);
      expect(PaymentIntentPointAccount.fromJson(json(null)).nextExpiration,
          isNull);
    });

    test('does not add next_expiration to legacy payer JSON', () {
      final payerPoint = PayerPoint.fromJson({
        'label': 'MisePay Points',
        'balance': {'available': '0'},
        'authorization': {'amount': '0', 'max_amount': '0', 'revision': 1},
        'expiring_soon_lot': null,
        'next_expiration': null,
      });
      expect(payerPoint.toJson(), isNot(contains('next_expiration')));
    });
  });
}
