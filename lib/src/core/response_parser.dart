import 'dart:convert';

import 'package:http/http.dart' as http;

import 'misepay_exception.dart';

Map<String, dynamic> parseJsonObjectResponse(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw MisePayException(
        'HTTP_ERROR', 'MisePay API returned status ${response.statusCode}.');
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}
