/// Merchant summary for display in a PaymentIntent checkout.
class Merchant {
  /// Creates an immutable merchant summary.
  const Merchant({required this.name});

  /// Parses a merchant summary from API JSON.
  factory Merchant.fromJson(Map<String, dynamic> json) =>
      Merchant(name: json['name'] as String);

  /// Merchant display name.
  final String name;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {'name': name};
}
