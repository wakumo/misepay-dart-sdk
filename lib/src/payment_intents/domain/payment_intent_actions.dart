/// Backend-provided action URLs for PaymentIntent follow-up requests.
class PaymentIntentActions {
  /// Creates immutable PaymentIntent action URLs.
  const PaymentIntentActions({
    required this.submitPointAuthorization,
    required this.submitPaymentProof,
  });

  /// Parses action URLs from API JSON.
  factory PaymentIntentActions.fromJson(Map<String, dynamic> json) =>
      PaymentIntentActions(
        submitPointAuthorization: json['submit_point_authorization'] as String,
        submitPaymentProof: json['submit_payment_proof'] as String,
      );

  /// URL for submitting a signed point authorization.
  final String submitPointAuthorization;

  /// URL for submitting an on-chain payment proof transaction hash.
  final String submitPaymentProof;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'submit_point_authorization': submitPointAuthorization,
        'submit_payment_proof': submitPaymentProof,
      };
}
