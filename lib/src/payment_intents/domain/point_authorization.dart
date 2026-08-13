/// EIP-712 point authorization payload to be signed by the payer.
class PointAuthorization {
  /// Creates an immutable point authorization.
  const PointAuthorization({
    required this.payerAddress,
    required this.pointAmount,
    required this.authorizationRevision,
    required this.typedData,
  });

  /// Payer wallet address that must sign [typedData].
  final String payerAddress;

  /// Selected point amount represented as an integer string.
  final String pointAmount;

  /// Next authorization revision signed by the payer.
  final int authorizationRevision;

  /// EIP-712 typed data to pass to the wallet signer.
  final Map<String, Object?> typedData;

  /// Convenience accessor for the typed data message object.
  Map<String, Object?> get message =>
      typedData['message']! as Map<String, Object?>;
}
