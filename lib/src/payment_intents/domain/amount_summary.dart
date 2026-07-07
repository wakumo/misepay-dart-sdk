/// Gross, benefit, and net amount summary for a PaymentIntent.
class AmountSummary {
  /// Creates an immutable amount summary.
  const AmountSummary({
    required this.currency,
    required this.gross,
    required this.benefit,
    required this.net,
  });

  /// Parses an amount summary from API JSON.
  factory AmountSummary.fromJson(Map<String, dynamic> json) => AmountSummary(
        currency: json['currency'] as String,
        gross: json['gross'] as String,
        benefit: json['benefit'] as String,
        net: json['net'] as String,
      );

  /// Currency code, such as `JPY`.
  final String currency;

  /// Gross amount before benefits, represented as an integer string.
  final String gross;

  /// Applied benefit or point amount, represented as an integer string.
  final String benefit;

  /// Net payable amount after benefits, represented as an integer string.
  final String net;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'currency': currency,
        'gross': gross,
        'benefit': benefit,
        'net': net,
      };
}
