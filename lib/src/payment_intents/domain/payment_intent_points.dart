import '../../core/misepay_exception.dart';
import 'payer.dart';

/// Persisted lifecycle status of a PaymentIntent point authorization.
enum PointAuthorizationStatus {
  reserved('reserved'),
  consumed('consumed'),
  released('released');

  /// Creates a status with its API JSON value.
  const PointAuthorizationStatus(this.value);

  /// API JSON value for this status.
  final String value;

  /// Parses a status from its API JSON value.
  static PointAuthorizationStatus fromJson(String value) {
    return PointAuthorizationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw MisePayException(
        'UNKNOWN_POINT_AUTHORIZATION_STATUS',
        'Unknown point authorization status: $value',
      ),
    );
  }

  /// Serializes this status to its API JSON value.
  String toJson() => value;
}

/// Canonical loyalty-point context for a PaymentIntent.
class PaymentIntentPoints {
  /// Creates immutable canonical point context.
  const PaymentIntentPoints(
      {required this.account, required this.authorization});

  /// Parses canonical point context from API JSON.
  factory PaymentIntentPoints.fromJson(Map<String, dynamic> json) =>
      PaymentIntentPoints(
        account: json['account'] == null
            ? null
            : PaymentIntentPointAccount.fromJson(
                json['account'] as Map<String, dynamic>),
        authorization: json['authorization'] == null
            ? null
            : PaymentIntentPointAuthorization.fromJson(
                json['authorization'] as Map<String, dynamic>,
              ),
      );

  /// Live account snapshot, unavailable after a PaymentIntent becomes terminal.
  final PaymentIntentPointAccount? account;

  /// Durable authorization history for this PaymentIntent.
  final PaymentIntentPointAuthorization? authorization;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'account': account?.toJson(),
        'authorization': authorization?.toJson(),
      };
}

/// Live loyalty-point account snapshot for a PaymentIntent checkout.
class PaymentIntentPointAccount {
  /// Creates immutable live point-account context.
  const PaymentIntentPointAccount({
    required this.holderAddress,
    required this.label,
    required this.availableBalance,
    this.expiringSoonLot,
    this.nextExpiration,
  });

  /// Parses point-account context from API JSON.
  factory PaymentIntentPointAccount.fromJson(Map<String, dynamic> json) =>
      PaymentIntentPointAccount(
        holderAddress: json['holder_address'] as String,
        label: json['label'] as String,
        availableBalance: json['available_balance'] as String,
        expiringSoonLot: json['expiring_soon_lot'] == null
            ? null
            : PointExpiringSoonLot.fromJson(
                json['expiring_soon_lot'] as Map<String, dynamic>),
        nextExpiration: json['next_expiration'] == null
            ? null
            : PointNextExpiration.fromJson(
                json['next_expiration'] as Map<String, dynamic>),
      );

  /// Point-account holder address.
  final String holderAddress;

  /// Display label for the loyalty program.
  final String label;

  /// Reconciled available balance, represented as an integer string.
  final String availableBalance;

  /// Earliest-expiring usable lot while the PaymentIntent remains pending.
  final PointExpiringSoonLot? expiringSoonLot;

  /// Earliest JST validity date and total points expiring after that date.
  final PointNextExpiration? nextExpiration;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'holder_address': holderAddress,
        'label': label,
        'available_balance': availableBalance,
        'expiring_soon_lot': expiringSoonLot?.toJson(),
        'next_expiration': nextExpiration?.toJson(),
      };
}

/// Aggregated points sharing the earliest expiration date in Japan time.
class PointNextExpiration {
  /// Creates an immutable next-expiration value.
  const PointNextExpiration({
    required this.amount,
    required this.validThrough,
    required this.expiresAt,
  });

  /// Parses a canonical next-expiration response.
  factory PointNextExpiration.fromJson(Map<String, dynamic> json) =>
      PointNextExpiration(
        amount: json['amount'] as String,
        validThrough: json['valid_through'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  /// Total points expiring at this boundary, represented as an integer string.
  final String amount;

  /// Last calendar date on which these points are usable in Asia/Tokyo.
  final String validThrough;

  /// Exclusive expiration instant. Compare the current instant with this value.
  final DateTime expiresAt;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'amount': amount,
        'valid_through': validThrough,
        'expires_at': _formatJstTimestamp(expiresAt),
      };
}

String _formatJstTimestamp(DateTime value) {
  final jst = value.toUtc().add(const Duration(hours: 9));
  String two(int part) => part.toString().padLeft(2, '0');
  String three(int part) => part.toString().padLeft(3, '0');
  return '${jst.year.toString().padLeft(4, '0')}-${two(jst.month)}-${two(jst.day)}'
      'T${two(jst.hour)}:${two(jst.minute)}:${two(jst.second)}.${three(jst.millisecond)}+09:00';
}

/// Current point-authorization state for a PaymentIntent.
class PaymentIntentPointAuthorization {
  /// Creates immutable point-authorization state.
  const PaymentIntentPointAuthorization({
    required this.holderAddress,
    required this.amount,
    required this.maximumAmount,
    required this.revision,
    required this.status,
  });

  /// Parses point-authorization context from API JSON.
  factory PaymentIntentPointAuthorization.fromJson(Map<String, dynamic> json) =>
      PaymentIntentPointAuthorization(
        holderAddress: json['holder_address'] as String,
        amount: json['amount'] as String,
        maximumAmount: json['maximum_amount'] as String?,
        revision: json['revision'] as int,
        status: json['status'] == null
            ? null
            : PointAuthorizationStatus.fromJson(json['status'] as String),
      );

  /// Address that authorized this point target.
  final String holderAddress;

  /// Current selected amount, retained after a persisted authorization releases.
  final String amount;

  /// Current maximum selectable amount while the PaymentIntent is actionable.
  final String? maximumAmount;

  /// Current authorization revision.
  final int revision;

  /// Persisted authorization lifecycle status, or null before first submission.
  final PointAuthorizationStatus? status;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'holder_address': holderAddress,
        'amount': amount,
        'maximum_amount': maximumAmount,
        'revision': revision,
        'status': status?.toJson(),
      };
}
