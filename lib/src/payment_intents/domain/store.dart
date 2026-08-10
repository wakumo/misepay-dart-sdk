/// Store summary for display in a PaymentIntent checkout.
class Store {
  /// Creates an immutable store summary.
  const Store({required this.name, this.imageUrl});

  /// Parses a store summary from API JSON.
  factory Store.fromJson(Map<String, dynamic> json) => Store(
        name: json['name'] as String,
        imageUrl: _optionalNonBlankString(json['image_url']),
      );

  /// Store display name.
  final String name;

  /// Canonical public Store image URL when configured.
  final String? imageUrl;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {'name': name, 'image_url': imageUrl};
}

String? _optionalNonBlankString(Object? value) {
  if (value == null) return null;
  final normalized = (value as String).trim();
  return normalized.isEmpty ? null : normalized;
}
