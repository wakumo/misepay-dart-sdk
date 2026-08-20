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
      );

  /// Point-account holder address.
  final String holderAddress;

  /// Display label for the loyalty program.
  final String label;

  /// Reconciled available balance, represented as an integer string.
  final String availableBalance;

  /// Earliest-expiring usable lot while the PaymentIntent remains pending.
  final PointExpiringSoonLot? expiringSoonLot;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'holder_address': holderAddress,
        'label': label,
        'available_balance': availableBalance,
        'expiring_soon_lot': expiringSoonLot?.toJson(),
      };
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
