/// On-chain payment option for paying a PaymentIntent net amount.
class PaymentOption {
  /// Creates an immutable payment option.
  const PaymentOption({
    required this.chainId,
    required this.assetSymbol,
    required this.assetDecimals,
    required this.tokenAddress,
    required this.recipientAddress,
    required this.amountBaseUnits,
    this.chainName,
  });

  /// Parses a payment option from API JSON.
  factory PaymentOption.fromJson(Map<String, dynamic> json) => PaymentOption(
        chainId: json['chain_id'] as int,
        chainName: json['chain_name'] as String?,
        assetSymbol: json['asset_symbol'] as String,
        assetDecimals: json['asset_decimals'] as int,
        tokenAddress: json['token_address'] as String,
        recipientAddress: json['recipient_address'] as String,
        amountBaseUnits: json['amount_base_units'] as String,
      );

  /// Chain id where this payment option can be paid.
  final int chainId;

  /// Optional display name for the chain.
  final String? chainName;

  /// Token or asset symbol.
  final String assetSymbol;

  /// Token decimals.
  final int assetDecimals;

  /// Token contract address.
  final String tokenAddress;

  /// Recipient wallet address for the payment.
  final String recipientAddress;

  /// Net payable token amount in base units, represented as an integer string.
  final String amountBaseUnits;

  /// Serializes this value back to API-shaped JSON.
  Map<String, dynamic> toJson() => {
        'chain_id': chainId,
        if (chainName != null) 'chain_name': chainName,
        'asset_symbol': assetSymbol,
        'asset_decimals': assetDecimals,
        'token_address': tokenAddress,
        'recipient_address': recipientAddress,
        'amount_base_units': amountBaseUnits,
      };
}
