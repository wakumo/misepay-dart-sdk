import 'dart:convert';

import 'package:http/http.dart' as http;

class MisePayException implements Exception {
  MisePayException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'MisePayException($code): $message';
}

enum PaymentIntentStatus {
  pending('pending'),
  requiresPayment('requires_payment'),
  completed('completed'),
  expired('expired'),
  cancelled('cancelled'),
  reviewRequired('review_required');

  const PaymentIntentStatus(this.value);

  final String value;

  static PaymentIntentStatus fromJson(String value) {
    return PaymentIntentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw MisePayException(
          'UNKNOWN_STATUS', 'Unknown PaymentIntent status: $value'),
    );
  }
}

class PaymentIntent {
  PaymentIntent({
    required this.version,
    required this.id,
    required this.status,
    required this.merchant,
    required this.store,
    required this.amount,
    required this.paymentOptions,
    required this.actions,
    required this.expiresAt,
    required http.Client httpClient,
    this.payer,
  }) : _httpClient = httpClient;

  factory PaymentIntent.fromJson(Map<String, dynamic> json,
      {http.Client? httpClient}) {
    final embeddedClient = json['__http_client'];
    return PaymentIntent(
      version: json['version'] as int,
      id: json['id'] as String,
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
      actions: PaymentIntentActions.fromJson(
          json['actions'] as Map<String, dynamic>),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      httpClient: httpClient ??
          (embeddedClient is http.Client ? embeddedClient : http.Client()),
    );
  }

  final int version;
  final String id;
  final PaymentIntentStatus status;
  final Merchant merchant;
  final Store store;
  final Payer? payer;
  final AmountSummary amount;
  final List<PaymentOption> paymentOptions;
  final PaymentIntentActions actions;
  final DateTime expiresAt;
  final http.Client _httpClient;

  PointAuthorization buildPointAuthorization({required String pointAmount}) {
    final payer = this.payer;
    if (payer == null) {
      throw MisePayException('PAYER_REQUIRED',
          'Payer context is required to build point authorization.');
    }

    final selectedPointAmount =
        _parseNonNegativeInt(pointAmount, 'INVALID_POINT_AMOUNT');
    final maxPointAmount = BigInt.parse(payer.point.limits.max);
    final currentPointAmount = BigInt.parse(payer.point.intent.amount);
    final grossAmount = BigInt.parse(amount.gross);

    if (selectedPointAmount > maxPointAmount) {
      throw MisePayException('POINT_AMOUNT_EXCEEDS_MAX',
          'Point amount exceeds maximum selectable amount.');
    }
    if (selectedPointAmount == currentPointAmount) {
      throw MisePayException(
          'POINT_AMOUNT_UNCHANGED', 'Point amount is unchanged.');
    }
    if (selectedPointAmount > grossAmount) {
      throw MisePayException(
          'POINT_AMOUNT_EXCEEDS_GROSS', 'Point amount exceeds gross amount.');
    }

    final netAmount = grossAmount - selectedPointAmount;
    final expiresAtSeconds = expiresAt.millisecondsSinceEpoch ~/ 1000;
    final message = <String, Object>{
      'intentId': id,
      'payer': payer.address,
      'grossAmount': grossAmount.toString(),
      'pointAmount': selectedPointAmount.toString(),
      'netAmount': netAmount.toString(),
      'expiresAt': expiresAtSeconds,
    };

    return PointAuthorization(
      payerAddress: payer.address,
      pointAmount: selectedPointAmount.toString(),
      typedData: {
        'domain': {'name': 'MisePay PaymentIntent', 'version': '1'},
        'primaryType': 'PaymentIntentPointAuthorization',
        'types': {
          'PaymentIntentPointAuthorization': [
            {'name': 'intentId', 'type': 'string'},
            {'name': 'payer', 'type': 'address'},
            {'name': 'grossAmount', 'type': 'uint256'},
            {'name': 'pointAmount', 'type': 'uint256'},
            {'name': 'netAmount', 'type': 'uint256'},
            {'name': 'expiresAt', 'type': 'uint256'},
          ],
        },
        'message': message,
      },
    );
  }

  Future<PaymentIntent> submitPointAuthorization({
    required PointAuthorization authorization,
    required String signature,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(actions.submitPointAuthorization),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'payer_address': authorization.payerAddress,
        'point_amount': authorization.pointAmount,
        'signature': signature,
      }),
    );
    return _parsePaymentIntentResponse(response, _httpClient);
  }

  Future<PaymentIntent> submitTransactionHash({
    required int chainId,
    required String tokenAddress,
    required String txHash,
  }) async {
    final response = await _httpClient.post(
      Uri.parse(actions.submitPaymentProof),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'chain_id': chainId,
        'token_address': tokenAddress,
        'tx_hash': txHash,
      }),
    );
    return _parsePaymentIntentResponse(response, _httpClient);
  }
}

class Merchant {
  Merchant({required this.name});

  factory Merchant.fromJson(Map<String, dynamic> json) =>
      Merchant(name: json['name'] as String);

  final String name;
}

class Store {
  Store({required this.name});

  factory Store.fromJson(Map<String, dynamic> json) =>
      Store(name: json['name'] as String);

  final String name;
}

class Payer {
  Payer({required this.address, required this.point});

  factory Payer.fromJson(Map<String, dynamic> json) => Payer(
        address: json['address'] as String,
        point: PayerPoint.fromJson(json['point'] as Map<String, dynamic>),
      );

  final String address;
  final PayerPoint point;
}

class PayerPoint {
  PayerPoint(
      {required this.label,
      required this.balance,
      required this.intent,
      required this.limits});

  factory PayerPoint.fromJson(Map<String, dynamic> json) => PayerPoint(
        label: json['label'] as String,
        balance: PointBalance.fromJson(json['balance'] as Map<String, dynamic>),
        intent: PointIntent.fromJson(json['intent'] as Map<String, dynamic>),
        limits: PointLimits.fromJson(json['limits'] as Map<String, dynamic>),
      );

  final String label;
  final PointBalance balance;
  final PointIntent intent;
  final PointLimits limits;
}

class PointBalance {
  PointBalance({required this.available});

  factory PointBalance.fromJson(Map<String, dynamic> json) =>
      PointBalance(available: json['available'] as String);

  final String available;
}

class PointIntent {
  PointIntent({required this.amount});

  factory PointIntent.fromJson(Map<String, dynamic> json) =>
      PointIntent(amount: json['amount'] as String);

  final String amount;
}

class PointLimits {
  PointLimits({required this.max});

  factory PointLimits.fromJson(Map<String, dynamic> json) =>
      PointLimits(max: json['max'] as String);

  final String max;
}

class AmountSummary {
  AmountSummary(
      {required this.currency,
      required this.gross,
      required this.benefit,
      required this.net});

  factory AmountSummary.fromJson(Map<String, dynamic> json) => AmountSummary(
        currency: json['currency'] as String,
        gross: json['gross'] as String,
        benefit: json['benefit'] as String,
        net: json['net'] as String,
      );

  final String currency;
  final String gross;
  final String benefit;
  final String net;
}

class PaymentOption {
  PaymentOption({
    required this.chainId,
    required this.chainName,
    required this.assetSymbol,
    required this.assetDecimals,
    required this.tokenAddress,
    required this.recipientAddress,
    required this.amountBaseUnits,
  });

  factory PaymentOption.fromJson(Map<String, dynamic> json) => PaymentOption(
        chainId: json['chain_id'] as int,
        chainName: json['chain_name'] as String,
        assetSymbol: json['asset_symbol'] as String,
        assetDecimals: json['asset_decimals'] as int,
        tokenAddress: json['token_address'] as String,
        recipientAddress: json['recipient_address'] as String,
        amountBaseUnits: json['amount_base_units'] as String,
      );

  final int chainId;
  final String chainName;
  final String assetSymbol;
  final int assetDecimals;
  final String tokenAddress;
  final String recipientAddress;
  final String amountBaseUnits;
}

class PaymentIntentActions {
  PaymentIntentActions(
      {required this.submitPointAuthorization,
      required this.submitPaymentProof});

  factory PaymentIntentActions.fromJson(Map<String, dynamic> json) =>
      PaymentIntentActions(
        submitPointAuthorization: json['submit_point_authorization'] as String,
        submitPaymentProof: json['submit_payment_proof'] as String,
      );

  final String submitPointAuthorization;
  final String submitPaymentProof;
}

class PointAuthorization {
  PointAuthorization(
      {required this.payerAddress,
      required this.pointAmount,
      required this.typedData});

  final String payerAddress;
  final String pointAmount;
  final Map<String, Object?> typedData;

  Map<String, Object?> get message =>
      typedData['message']! as Map<String, Object?>;
}

PaymentIntent _parsePaymentIntentResponse(
    http.Response response, http.Client httpClient) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw MisePayException(
        'HTTP_ERROR', 'MisePay API returned status ${response.statusCode}.');
  }
  return PaymentIntent.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      httpClient: httpClient);
}

BigInt _parseNonNegativeInt(String value, String errorCode) {
  final parsed = BigInt.tryParse(value);
  if (parsed == null || parsed < BigInt.zero) {
    throw MisePayException(
        errorCode, 'Expected a non-negative integer string.');
  }
  return parsed;
}
