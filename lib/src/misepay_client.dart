import 'package:http/http.dart' as http;

import 'misepay_environment.dart';
import 'payment_intents/data/payment_intent_api.dart';
import 'payment_intents/domain/payment_intent_repository.dart';
import 'payment_intents/payment_intents_client.dart';
import 'payment_intents/services/point_authorization_service.dart';

/// Public facade for MisePay PaymentIntent checkout operations.
class MisePayClient {
  /// Creates a client with an optional HTTP client or repository override.
  ///
  /// Most apps should pass no arguments. Tests can inject [httpClient] or a
  /// custom [paymentIntentRepository].
  MisePayClient({
    http.Client? httpClient,
    PaymentIntentRepository? paymentIntentRepository,
    MisePayEnv env = MisePayEnv.production,
    MisePayOriginPolicy originPolicy = MisePayOriginPolicy.allowListed,
    Set<String> allowedOrigins = const {},
  }) : paymentIntents = PaymentIntentsClient(
          repository: paymentIntentRepository ??
              PaymentIntentApi(
                httpClient: httpClient ?? http.Client(),
                allowedOrigins: allowedOrigins.isEmpty
                    ? env.defaultAllowedOrigins
                    : allowedOrigins,
                allowAllOrigins: originPolicy == MisePayOriginPolicy.allowAll,
              ),
          pointAuthorizationService:
              PointAuthorizationService(domainSalt: env.domainSalt),
        );

  /// PaymentIntent resource operations.
  final PaymentIntentsClient paymentIntents;
}
