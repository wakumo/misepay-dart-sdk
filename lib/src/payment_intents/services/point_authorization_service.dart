import '../../core/ethereum_keccak.dart';
import '../../core/integer_string.dart';
import '../../core/misepay_exception.dart';
import '../domain/payment_intent.dart';
import '../domain/point_authorization.dart';

class PointAuthorizationService {
  const PointAuthorizationService({this.domainSalt = 'misepay:prod'});

  final String domainSalt;

  PointAuthorization build({
    required PaymentIntent intent,
    required String pointAmount,
  }) {
    final payer = intent.payer;
    final payerAddress = payer?.address;
    if (payerAddress == null) {
      throw MisePayException(
        'PAYER_REQUIRED',
        'Payer context is required to build point authorization.',
      );
    }

    final selectedPointAmount = parseNonNegativeIntegerString(
      pointAmount,
      'INVALID_POINT_AMOUNT',
    );
    final currentPointAmount = parseNonNegativeIntegerString(
      payer!.point.authorization.amount,
      'INVALID_CURRENT_POINT_AMOUNT',
    );
    final maxPointAmount = parseNonNegativeIntegerString(
      payer.point.authorization.maxAmount,
      'INVALID_POINT_LIMIT',
    );

    if (selectedPointAmount > maxPointAmount) {
      throw MisePayException(
        'POINT_AMOUNT_EXCEEDS_MAX',
        'Point amount exceeds maximum selectable amount.',
      );
    }
    if (selectedPointAmount == currentPointAmount) {
      throw MisePayException(
        'POINT_AMOUNT_UNCHANGED',
        'Point amount is unchanged.',
      );
    }

    final currentRevision = payer.point.authorization.revision;
    if (currentRevision < 0) {
      throw MisePayException(
        'INVALID_AUTHORIZATION_REVISION',
        'Point authorization revision must be non-negative.',
      );
    }
    final authorizationRevision = currentRevision + 1;

    final expiresAtSeconds = intent.expiresAt.millisecondsSinceEpoch ~/ 1000;
    final message = <String, Object>{
      'intentId': intent.id,
      'payer': payerAddress,
      'pointAmount': selectedPointAmount.toString(),
      'authorizationRevision': authorizationRevision.toString(),
      'expiresAt': expiresAtSeconds,
    };

    return PointAuthorization(
      payerAddress: payerAddress,
      pointAmount: pointAmount,
      authorizationRevision: authorizationRevision,
      typedData: {
        'domain': {
          'name': 'MisePay PaymentIntent',
          'version': '1',
          'salt': ethereumKeccak256(domainSalt),
        },
        'primaryType': 'PaymentIntentPointAuthorization',
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'version', 'type': 'string'},
            {'name': 'salt', 'type': 'bytes32'},
          ],
          'PaymentIntentPointAuthorization': [
            {'name': 'intentId', 'type': 'string'},
            {'name': 'payer', 'type': 'address'},
            {'name': 'pointAmount', 'type': 'uint256'},
            {'name': 'authorizationRevision', 'type': 'uint256'},
            {'name': 'expiresAt', 'type': 'uint256'},
          ],
        },
        'message': message,
      },
    );
  }
}
