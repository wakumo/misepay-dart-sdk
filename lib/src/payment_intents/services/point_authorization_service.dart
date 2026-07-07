import '../../core/integer_string.dart';
import '../../core/misepay_exception.dart';
import '../domain/payment_intent.dart';
import '../domain/payment_option.dart';
import '../domain/point_authorization.dart';

class PointAuthorizationService {
  const PointAuthorizationService();

  PointAuthorization build({
    required PaymentIntent intent,
    required PaymentOption paymentOption,
    required String pointAmount,
  }) {
    final payer = intent.payer;
    final payerAddress = payer?.address;
    if (payerAddress == null) {
      throw MisePayException('PAYER_REQUIRED',
          'Payer context is required to build point authorization.');
    }

    final selectedPointAmount = parseNonNegativeDecimalUnits(
        pointAmount, paymentOption.assetDecimals, 'INVALID_POINT_AMOUNT');
    final currentPointAmount = parseNonNegativeDecimalUnits(
        payer!.point.intent.amount,
        paymentOption.assetDecimals,
        'INVALID_CURRENT_POINT_AMOUNT');
    final maxPointAmount = payer.point.limits?.max == null
        ? null
        : parseNonNegativeDecimalUnits(payer.point.limits!.max,
            paymentOption.assetDecimals, 'INVALID_POINT_LIMIT');
    final grossAmount = parseNonNegativeDecimalUnits(intent.amount.gross,
        paymentOption.assetDecimals, 'INVALID_GROSS_AMOUNT');

    if (maxPointAmount != null && selectedPointAmount > maxPointAmount) {
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
      'payer': payerAddress,
      'grossAmount': grossAmount.toString(),
      'pointAmount': selectedPointAmount.toString(),
      'netAmount': netAmount.toString(),
      'expiresAt': expiresAtSeconds,
    };

    return PointAuthorization(
      payerAddress: payerAddress,
      pointAmount: pointAmount,
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
