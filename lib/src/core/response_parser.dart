import 'dart:convert';

import 'package:http/http.dart' as http;

import 'misepay_exception.dart';

Map<String, dynamic> parseJsonObjectResponse(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    final error = _tryParseError(response.body);
    throw MisePayException(error.$1,
        error.$2 ?? 'MisePay API returned status ${response.statusCode}.');
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}

(String, String?) _tryParseError(String body) {
  try {
    final json = jsonDecode(body);
    if (json is Map<String, dynamic>) {
      final code = json['code'];
      final message = json['message'];
      if (code is String && code.isNotEmpty) {
        return (code, message is String ? message : null);
      }
      if (message is String && _isMachineReadableCode(message)) {
        return (message, message);
      }
      if (message is List) {
        final validationCode = message.whereType<String>().firstWhere(
              _isMachineReadableCode,
              orElse: () => '',
            );
        if (validationCode.isNotEmpty) {
          return (validationCode, validationCode);
        }
      }
    }
  } on FormatException {
    return ('HTTP_ERROR', null);
  }
  return ('HTTP_ERROR', null);
}

bool _isMachineReadableCode(String value) =>
    RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(value);
