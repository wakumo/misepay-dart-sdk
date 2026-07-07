/// Store summary for display in a PaymentIntent checkout.
class Store {
  /// Creates an immutable store summary.
  const Store({required this.name});

  /// Parses a store summary from API JSON.
  factory Store.fromJson(Map<String, dynamic> json) =>
      Store(name: json['name'] as String);

  /// Store display name.
  final String name;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {'name': name};
}
