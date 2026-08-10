/// Merchant summary for display in a PaymentIntent checkout.
class Merchant {
  /// Creates an immutable merchant summary.
  const Merchant({required this.name, this.imageUrl});

  /// Parses a merchant summary from API JSON.
  factory Merchant.fromJson(Map<String, dynamic> json) => Merchant(
        name: json['name'] as String,
        imageUrl: _optionalNonBlankString(json['image_url']),
      );

  /// Merchant display name.
  final String name;

  /// Canonical public Merchant image URL when configured.
  final String? imageUrl;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {'name': name, 'image_url': imageUrl};
}

String? _optionalNonBlankString(Object? value) {
  if (value == null) return null;
  final normalized = (value as String).trim();
  return normalized.isEmpty ? null : normalized;
}
