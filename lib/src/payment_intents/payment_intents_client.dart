import 'domain/payment_intent.dart';
import 'domain/payment_intent_repository.dart';
import 'domain/point_authorization.dart';
import '../core/misepay_exception.dart';
import 'services/point_authorization_service.dart';

/// Resource client for PaymentIntent checkout operations.
class PaymentIntentsClient {
  /// Creates a PaymentIntent resource client.
  const PaymentIntentsClient({
    required PaymentIntentRepository repository,
    PointAuthorizationService pointAuthorizationService =
        const PointAuthorizationService(),
  })  : _repository = repository,
        _pointAuthorizationService = pointAuthorizationService;

  final PaymentIntentRepository _repository;
  final PointAuthorizationService _pointAuthorizationService;

  /// Fetches a PaymentIntent from the backend-provided [requestUri].
  ///
  /// When [payerAddress] is provided, it is sent as the `payer_address` query
  /// parameter while preserving existing query parameters on [requestUri].
  Future<PaymentIntent> get({
    required String requestUri,
    String? payerAddress,
  }) {
    return _repository.getPaymentIntent(
      requestUri: requestUri,
      payerAddress: payerAddress,
    );
  }

  /// Builds EIP-712 point authorization typed data for [paymentIntent].
  ///
  /// [pointAmount] must be a non-negative integer string. The full
  /// [paymentIntent] is required because validation uses canonical point-holder
  /// context, point limits, current point selection, and expiry data.
  PointAuthorization authorizePoints({
    required PaymentIntent paymentIntent,
    required String pointAmount,
  }) {
    return _pointAuthorizationService.build(
      intent: paymentIntent,
      pointAmount: pointAmount,
    );
  }

  /// Submits a signed point authorization to [paymentIntent]'s action URL.
  Future<PaymentIntent> applyPoints({
    required PaymentIntent paymentIntent,
    required PointAuthorization authorization,
    required String signature,
  }) {
    _assertAuthorizationHolderMatches(paymentIntent, authorization);
    return _repository.submitPointAuthorization(
      intent: paymentIntent,
      authorization: authorization,
      signature: signature,
    );
  }

  /// Submits an on-chain payment transaction hash to [paymentIntent]'s action URL.
  ///
  /// [payerAddress] is optional response-rendering context. It is not verified
  /// sender evidence and is independent of the PaymentIntent point holder.
  Future<PaymentIntent> provePayment({
    required PaymentIntent paymentIntent,
    required int chainId,
    required String tokenAddress,
    required String txHash,
    String? payerAddress,
  }) {
    return _repository.submitTransactionHash(
      intent: paymentIntent,
      chainId: chainId,
      tokenAddress: tokenAddress,
      txHash: txHash,
      payerAddress: payerAddress,
    );
  }

  void _assertAuthorizationHolderMatches(
    PaymentIntent paymentIntent,
    PointAuthorization authorization,
  ) {
    final holderAddress = paymentIntent.points?.authorization?.holderAddress ??
        paymentIntent.payer?.address;
    if (holderAddress != null &&
        holderAddress.toLowerCase() !=
            authorization.payerAddress.toLowerCase()) {
      throw MisePayException(
        'POINT_AUTHORIZATION_HOLDER_MISMATCH',
        'Point authorization payer does not match the PaymentIntent point holder.',
      );
    }
  }
}
