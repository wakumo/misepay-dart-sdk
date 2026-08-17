import 'payment_intent.dart';
import 'point_authorization.dart';

/// Boundary for PaymentIntent network operations.
abstract interface class PaymentIntentRepository {
  /// Fetches a PaymentIntent from the backend-provided request URI.
  Future<PaymentIntent> getPaymentIntent({
    required String requestUri,
    String? payerAddress,
  });

  /// Submits a signed point authorization to the PaymentIntent action URL.
  Future<PaymentIntent> submitPointAuthorization({
    required PaymentIntent intent,
    required PointAuthorization authorization,
    required String signature,
  });

  /// Submits an on-chain transaction hash to the PaymentIntent action URL.
  Future<PaymentIntent> submitTransactionHash({
    required PaymentIntent intent,
    required int chainId,
    required String tokenAddress,
    required String txHash,
    String? payerAddress,
  });
}
