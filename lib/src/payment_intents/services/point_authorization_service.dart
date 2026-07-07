import '../../core/integer_string.dart';
import '../../core/misepay_exception.dart';
import '../domain/payment_intent.dart';
import '../domain/point_authorization.dart';

class PointAuthorizationService {
  const PointAuthorizationService();

  PointAuthorization build({
    required PaymentIntent intent,
    required String pointAmount,
  }) {
    final payer = intent.payer;
    if (payer == null) {
      throw MisePayException('PAYER_REQUIRED',
          'Payer context is required to build point authorization.');
    }

    final selectedPointAmount =
        parseNonNegativeIntegerString(pointAmount, 'INVALID_POINT_AMOUNT');
    final maxPointAmount = BigInt.parse(payer.point.limits.max);
    final currentPointAmount = BigInt.parse(payer.point.intent.amount);
    final grossAmount = BigInt.parse(intent.amount.gross);

    if (selectedPointAmount > maxPointAmount) {
      throw MisePayException('POINT_AMOUNT_EXCEEDS_MAX',
          'Point amount exceeds maximum selectable amount.');
    }
    if (selectedPointAmount == currentPointAmount) {
      throw MisePayException(
          'POINT_AMOUNT_UNCHANGED', 'Point amount is unchanged.');
    }
    if (selectedPointAmount > grossAmount) {
      throw MisePayException(
          'POINT_AMOUNT_EXCEEDS_GROSS', 'Point amount exceeds gross amount.');
    }

    final netAmount = grossAmount - selectedPointAmount;
    final expiresAtSeconds = intent.expiresAt.millisecondsSinceEpoch ~/ 1000;
    final message = <String, Object>{
      'intentId': intent.id,
      'payer': payer.address,
      'grossAmount': grossAmount.toString(),
      'pointAmount': selectedPointAmount.toString(),
      'netAmount': netAmount.toString(),
      'expiresAt': expiresAtSeconds,
    };

    return PointAuthorization(
      payerAddress: payer.address,
      pointAmount: selectedPointAmount.toString(),
      typedData: {
        'domain': {'name': 'MisePay PaymentIntent', 'version': '1'},
        'primaryType': 'PaymentIntentPointAuthorization',
        'types': {
          'PaymentIntentPointAuthorization': [
            {'name': 'intentId', 'type': 'string'},
            {'name': 'payer', 'type': 'address'},
            {'name': 'grossAmount', 'type': 'uint256'},
            {'name': 'pointAmount', 'type': 'uint256'},
            {'name': 'netAmount', 'type': 'uint256'},
            {'name': 'expiresAt', 'type': 'uint256'},
          ],
        },
        'message': message,
      },
    );
  }
}
