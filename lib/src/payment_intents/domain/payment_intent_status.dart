import '../../core/misepay_exception.dart';

/// PaymentIntent lifecycle status.
enum PaymentIntentStatus {
  pending('pending'),
  requiresPayment('requires_payment'),
  completed('completed'),
  expired('expired'),
  cancelled('cancelled'),
  reviewRequired('review_required');

  /// Creates a status with its API JSON value.
  const PaymentIntentStatus(this.value);

  /// API JSON value for this status.
  final String value;

  /// Parses a status from its API JSON value.
  static PaymentIntentStatus fromJson(String value) {
    return PaymentIntentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw MisePayException(
          'UNKNOWN_STATUS', 'Unknown PaymentIntent status: $value'),
    );
  }

  /// Serializes this status to its API JSON value.
  String toJson() => value;
}
