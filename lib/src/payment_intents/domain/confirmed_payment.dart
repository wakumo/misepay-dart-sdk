/// Verified on-chain payment receipt linked to a PaymentIntent.
class ConfirmedPayment {
  /// Creates an immutable confirmed payment value.
  const ConfirmedPayment({
    required this.chainId,
    required this.assetSymbol,
    required this.assetDecimals,
    required this.tokenAddress,
    required this.amountBaseUnits,
    required this.txHash,
    required this.logIndex,
    required this.blockTimestamp,
  });

  /// Parses confirmed payment evidence from API JSON.
  factory ConfirmedPayment.fromJson(Map<String, dynamic> json) {
    return ConfirmedPayment(
      chainId: json['chain_id'] as int,
      assetSymbol: json['asset_symbol'] as String,
      assetDecimals: json['asset_decimals'] as int,
      tokenAddress: json['token_address'] as String,
      amountBaseUnits: json['amount_base_units'] as String,
      txHash: json['tx_hash'] as String,
      logIndex: json['log_index'] as int,
      blockTimestamp: DateTime.parse(json['block_timestamp'] as String),
    );
  }

  /// Blockchain chain ID that confirmed the transfer.
  final int chainId;

  /// Canonical token symbol at confirmation time.
  final String assetSymbol;

  /// Token decimals used to interpret [amountBaseUnits].
  final int assetDecimals;

  /// Token contract address used by the transfer.
  final String tokenAddress;

  /// Exact token amount in base units.
  ///
  /// Never convert this value to floating point.
  final String amountBaseUnits;

  /// Canonical transaction hash.
  final String txHash;

  /// Transfer-log index within the transaction receipt.
  final int logIndex;

  /// Timestamp of the block containing the confirmed transfer.
  final DateTime blockTimestamp;

  /// Serializes this receipt back to the API field allowlist.
  Map<String, dynamic> toJson() {
    return {
      'chain_id': chainId,
      'asset_symbol': assetSymbol,
      'asset_decimals': assetDecimals,
      'token_address': tokenAddress,
      'amount_base_units': amountBaseUnits,
      'tx_hash': txHash,
      'log_index': logIndex,
      'block_timestamp': _formatUtcTimestamp(blockTimestamp),
    };
  }
}

String _formatUtcTimestamp(DateTime value) {
  final utc = value.toUtc();
  final timestamp = utc.toIso8601String();
  if (utc.millisecond == 0 && utc.microsecond == 0) {
    return timestamp.replaceFirst('.000Z', 'Z');
  }
  return timestamp;
}
