import '../../core/misepay_exception.dart';
import 'utc_timestamp.dart';

/// Lifecycle status of a reward from a completed token payment.
enum RewardStatus {
  pending('pending'),
  available('available'),
  voided('voided');

  /// Creates a status with its API JSON value.
  const RewardStatus(this.value);

  /// API JSON value for this status.
  final String value;

  /// Parses a status from its API JSON value.
  static RewardStatus fromJson(String value) {
    return RewardStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw MisePayException(
        'UNKNOWN_REWARD_STATUS',
        'Unknown reward status: $value',
      ),
    );
  }

  /// Serializes this status to its API JSON value.
  String toJson() => value;
}

/// Reward for the verified token payer of a completed Order.
class Reward {
  /// Creates immutable reward context.
  const Reward({
    required this.recipientAddress,
    required this.amount,
    required this.status,
    required this.availableAt,
  });

  /// Parses reward context from API JSON.
  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        recipientAddress: json['recipient_address'] as String,
        amount: json['amount'] as String,
        status: RewardStatus.fromJson(json['status'] as String),
        availableAt: DateTime.parse(json['available_at'] as String),
      );

  /// Wallet that earned the reward by sending the verified token payment.
  final String recipientAddress;

  /// Earned points represented as an integer string.
  final String amount;

  /// Current reward lifecycle status.
  final RewardStatus status;

  /// UTC time when the reward becomes available.
  final DateTime availableAt;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'recipient_address': recipientAddress,
        'amount': amount,
        'status': status.toJson(),
        'available_at': formatUtcTimestamp(availableAt),
      };
}
