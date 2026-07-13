/// MisePay environment used for trusted origin and signing-domain defaults.
enum MisePayEnv {
  /// Production MisePay environment.
  production,

  /// Development or non-production MisePay environment.
  development,
}

/// Origin validation policy for PaymentIntent request URIs.
enum MisePayOriginPolicy {
  /// Validate request URI origins against the environment allowlist.
  allowListed,

  /// Accept any request URI origin. Intended for development builds only.
  allowAll,
}

extension MisePayEnvDefaults on MisePayEnv {
  Set<String> get defaultAllowedOrigins => switch (this) {
        MisePayEnv.production => {'https://apis.misepay.app'},
        MisePayEnv.development => const <String>{},
      };

  String get domainSalt => switch (this) {
        MisePayEnv.production => 'misepay:prod',
        MisePayEnv.development => 'misepay:dev',
      };
}
