/// Payer-specific context returned when a PaymentIntent is fetched with a payer.
class Payer {
  /// Creates an immutable payer context.
  const Payer({required this.address, required this.point});

  /// Parses payer context from API JSON.
  factory Payer.fromJson(Map<String, dynamic> json) => Payer(
        address: json['address'] as String,
        point: PayerPoint.fromJson(json['point'] as Map<String, dynamic>),
      );

  /// Payer wallet address.
  final String address;

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
    required this.intent,
    required this.limits,
  });

  /// Parses point context from API JSON.
  factory PayerPoint.fromJson(Map<String, dynamic> json) => PayerPoint(
        label: json['label'] as String,
        balance: PointBalance.fromJson(json['balance'] as Map<String, dynamic>),
        intent: PointIntent.fromJson(json['intent'] as Map<String, dynamic>),
        limits: PointLimits.fromJson(json['limits'] as Map<String, dynamic>),
      );

  /// Display label for the point program.
  final String label;

  /// Current available point balance.
  final PointBalance balance;

  /// Point amount currently selected for this PaymentIntent.
  final PointIntent intent;

  /// Selection limits for this PaymentIntent.
  final PointLimits limits;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'label': label,
        'balance': balance.toJson(),
        'intent': intent.toJson(),
        'limits': limits.toJson(),
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

/// Point amount selected for a PaymentIntent.
class PointIntent {
  /// Creates an immutable selected point amount.
  const PointIntent({required this.amount});

  /// Parses selected point amount from API JSON.
  factory PointIntent.fromJson(Map<String, dynamic> json) =>
      PointIntent(amount: json['amount'] as String);

  /// Selected point amount represented as an integer string.
  final String amount;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {'amount': amount};
}

/// Point selection limits for a PaymentIntent.
class PointLimits {
  /// Creates immutable point limits.
  const PointLimits({required this.max});

  /// Parses point limits from API JSON.
  factory PointLimits.fromJson(Map<String, dynamic> json) =>
      PointLimits(max: json['max'] as String);

  /// Maximum selectable point amount represented as an integer string.
  final String max;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {'max': max};
}
