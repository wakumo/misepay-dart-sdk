import 'misepay_exception.dart';

BigInt parseNonNegativeIntegerString(String value, String errorCode) {
  final parsed = BigInt.tryParse(value);
  if (parsed == null || parsed < BigInt.zero) {
    throw MisePayException(
        errorCode, 'Expected a non-negative integer string.');
  }
  return parsed;
}
