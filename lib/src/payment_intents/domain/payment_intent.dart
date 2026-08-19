import '../../core/misepay_exception.dart';
import 'amount_summary.dart';
import 'confirmed_payment.dart';
import 'merchant.dart';
import 'payer.dart';
import 'payment_intent_actions.dart';
import 'payment_intent_status.dart';
import 'payment_option.dart';
import 'store.dart';
import 'utc_timestamp.dart';

/// Typed PaymentIntent response returned by the MisePay API.
class PaymentIntent {
  /// Creates an immutable PaymentIntent value.
  const PaymentIntent({
    required this.version,
    required this.id,
    required this.requestUri,
    required this.status,
    required this.merchant,
    required this.store,
    required this.amount,
    required this.paymentOptions,
    required this.confirmedPayments,
    required this.actions,
    required this.expiresAt,
    this.orderId,
    this.createdAt,
    this.completedAt,
    this.cancelledAt,
    this.payer,
  });

  /// Parses a PaymentIntent from API JSON.
  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int;
    if (version != 1) {
      throw MisePayException(
        'UNSUPPORTED_PAYMENT_INTENT_VERSION',
        'Unsupported PaymentIntent version: $version',
      );
    }

    return PaymentIntent(
      version: version,
      id: json['id'] as String,
      orderId: json['order_id'] as String?,
      requestUri: json['request_uri'] as String,
      status: PaymentIntentStatus.fromJson(json['status'] as String),
      merchant: Merchant.fromJson(json['merchant'] as Map<String, dynamic>),
      store: Store.fromJson(json['store'] as Map<String, dynamic>),
      payer: json['payer'] == null
          ? null
          : Payer.fromJson(json['payer'] as Map<String, dynamic>),
      amount: AmountSummary.fromJson(json['amount'] as Map<String, dynamic>),
      paymentOptions: (json['payment_options'] as List<dynamic>)
          .map((option) =>
              PaymentOption.fromJson(option as Map<String, dynamic>))
          .toList(),
      confirmedPayments:
          (json['confirmed_payments'] as List<dynamic>? ?? const <dynamic>[])
              .map((payment) =>
                  ConfirmedPayment.fromJson(payment as Map<String, dynamic>))
              .toList(),
      actions: PaymentIntentActions.fromJson(
          json['actions'] as Map<String, dynamic>),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  /// SDK payload version.
  final int version;

  /// PaymentIntent identifier.
  final String id;

  /// Linked Order identifier when supplied by the API.
  final String? orderId;

  /// Canonical backend URI for fetching this exact PaymentIntent.
  final String requestUri;

  /// Current PaymentIntent status.
  final PaymentIntentStatus status;

  /// Merchant summary displayed to the payer.
  final Merchant merchant;

  /// Store summary displayed to the payer.
  final Store store;

  /// Payer-specific point context, present only when fetched with payer data.
  final Payer? payer;

  /// Gross, benefit, and net amount summary.
  final AmountSummary amount;

  /// Available on-chain payment options for the net amount.
  final List<PaymentOption> paymentOptions;

  /// Verified inbound token payments linked to this exact PaymentIntent.
  final List<ConfirmedPayment> confirmedPayments;

  /// Backend-provided action URLs for follow-up submissions.
  final PaymentIntentActions actions;

  /// PaymentIntent expiry timestamp.
  final DateTime expiresAt;

  /// Persisted PaymentIntent creation timestamp when supplied by the API.
  final DateTime? createdAt;

  /// Persisted PaymentIntent completion timestamp when supplied by the API.
  final DateTime? completedAt;

  /// Persisted PaymentIntent cancellation timestamp when supplied by the API.
  final DateTime? cancelledAt;

  /// Serializes this typed model back to API-shaped JSON.
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'id': id,
      'order_id': orderId,
      'request_uri': requestUri,
      'status': status.toJson(),
      'merchant': merchant.toJson(),
      'store': store.toJson(),
      'amount': amount.toJson(),
      'payment_options':
          paymentOptions.map((option) => option.toJson()).toList(),
      'confirmed_payments':
          confirmedPayments.map((payment) => payment.toJson()).toList(),
      'actions': actions.toJson(),
      'created_at': createdAt == null ? null : formatUtcTimestamp(createdAt!),
      'completed_at':
          completedAt == null ? null : formatUtcTimestamp(completedAt!),
      'cancelled_at':
          cancelledAt == null ? null : formatUtcTimestamp(cancelledAt!),
      'expires_at': formatUtcTimestamp(expiresAt),
      'payer': payer?.toJson(),
    };
  }
}
