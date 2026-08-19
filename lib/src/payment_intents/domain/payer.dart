import 'utc_timestamp.dart';

/// Payer-specific context returned when a PaymentIntent is fetched with a payer.
class Payer {
  /// Creates an immutable payer context.
  const Payer({required this.address, required this.point});

  /// Parses payer context from API JSON.
  factory Payer.fromJson(Map<String, dynamic> json) => Payer(
        address: json['address'] as String?,
        point: PayerPoint.fromJson(json['point'] as Map<String, dynamic>),
      );

  /// Payer wallet address.
  final String? address;

  /// Payer point balance, selected amount, and selection limits.
  final PayerPoint point;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'address': address,
        'point': point.toJson(),
      };
}

/// Point context for a payer on a PaymentIntent.
class PayerPoint {
  /// Creates an immutable point context.
  const PayerPoint({
    required this.label,
    required this.balance,
    required this.authorization,
    this.expiringSoonLot,
    this.pendingReward,
  });

  /// Parses point context from API JSON.
  factory PayerPoint.fromJson(Map<String, dynamic> json) => PayerPoint(
        label: json['label'] as String,
        balance: PointBalance.fromJson(json['balance'] as Map<String, dynamic>),
        authorization: PointAuthorizationContext.fromJson(
            json['authorization'] as Map<String, dynamic>),
        expiringSoonLot: json['expiring_soon_lot'] == null
            ? null
            : PointExpiringSoonLot.fromJson(
                json['expiring_soon_lot'] as Map<String, dynamic>),
        pendingReward: json['pending_reward'] == null
            ? null
            : PendingPointReward.fromJson(
                json['pending_reward'] as Map<String, dynamic>),
      );

  /// Display label for the point program.
  final String label;

  /// Current available point balance.
  final PointBalance balance;

  /// Point authorization values for this PaymentIntent.
  final PointAuthorizationContext authorization;

  /// Earliest-expiring usable point lot while the PaymentIntent is pending.
  final PointExpiringSoonLot? expiringSoonLot;

  /// Pending Order reward available to the payer after completion.
  final PendingPointReward? pendingReward;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'label': label,
        'balance': balance.toJson(),
        'authorization': authorization.toJson(),
        'expiring_soon_lot': expiringSoonLot?.toJson(),
        'pending_reward': pendingReward?.toJson(),
      };
}

/// Remaining amount and expiry of the payer's earliest-expiring usable lot.
class PointExpiringSoonLot {
  /// Creates immutable expiring point-lot display context.
  const PointExpiringSoonLot({required this.amount, required this.expiresAt});

  /// Parses point-lot display context from API JSON.
  factory PointExpiringSoonLot.fromJson(Map<String, dynamic> json) =>
      PointExpiringSoonLot(
        amount: json['amount'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  /// Remaining points in the lot represented as an integer string.
  final String amount;

  /// UTC time when the lot expires.
  final DateTime expiresAt;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'amount': amount,
        'expires_at': formatUtcTimestamp(expiresAt),
      };
}

/// Earned Order reward that has not reached its availability time.
class PendingPointReward {
  /// Creates immutable pending reward display context.
  const PendingPointReward({required this.amount, required this.availableAt});

  /// Parses pending reward display context from API JSON.
  factory PendingPointReward.fromJson(Map<String, dynamic> json) =>
      PendingPointReward(
        amount: json['amount'] as String,
        availableAt: DateTime.parse(json['available_at'] as String),
      );

  /// Earned points represented as an integer string.
  final String amount;

  /// UTC time when the reward becomes available.
  final DateTime availableAt;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'amount': amount,
        'available_at': formatUtcTimestamp(availableAt),
      };
}

/// Available point balance for a payer.
class PointBalance {
  /// Creates an immutable point balance.
  const PointBalance({required this.available});

  /// Parses point balance from API JSON.
  factory PointBalance.fromJson(Map<String, dynamic> json) =>
      PointBalance(available: json['available'] as String);

  /// Available points represented as an integer string.
  final String available;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {'available': available};
}

/// Point authorization values for a PaymentIntent.
class PointAuthorizationContext {
  /// Creates immutable point authorization values.
  const PointAuthorizationContext({
    required this.amount,
    required this.maxAmount,
    required this.revision,
  });

  /// Parses point authorization values from API JSON.
  factory PointAuthorizationContext.fromJson(Map<String, dynamic> json) =>
      PointAuthorizationContext(
        amount: json['amount'] as String,
        maxAmount: json['max_amount'] as String,
        revision: json['revision'] as int,
      );

  /// Point amount currently authorized for this PaymentIntent.
  final String amount;

  /// Total maximum point authorization target for the current snapshot.
  final String maxAmount;

  /// Revision of the currently accepted point authorization.
  final int revision;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'amount': amount,
        'max_amount': maxAmount,
        'revision': revision,
      };
}
