import 'misepay_exception.dart';

BigInt parseNonNegativeIntegerString(String value, String errorCode) {
  if (value.isEmpty || !_digitsOnly(value)) {
    throw MisePayException(
        errorCode, 'Expected a non-negative integer string.');
  }
  return BigInt.parse(value);
}

BigInt parseNonNegativeDecimalUnits(
    String value, int decimals, String errorCode) {
  if (decimals < 0) {
    throw MisePayException(errorCode, 'Expected non-negative decimals.');
  }

  final parts = value.split('.');
  if (parts.length > 2 || parts[0].isEmpty) {
    throw MisePayException(
        errorCode, 'Expected a non-negative decimal string.');
  }

  final whole = parts[0];
  final fractional = parts.length == 2 ? parts[1] : '';
  if (!_digitsOnly(whole) || !_digitsOnly(fractional)) {
    throw MisePayException(
        errorCode, 'Expected a non-negative decimal string.');
  }
  if (fractional.length > decimals) {
    throw MisePayException(
        errorCode, 'Decimal precision exceeds asset decimals.');
  }

  final normalized = whole + fractional.padRight(decimals, '0');
  return BigInt.parse(normalized);
}

bool _digitsOnly(String value) {
  for (var i = 0; i < value.length; i++) {
    final code = value.codeUnitAt(i);
    if (code < 48 || code > 57) return false;
  }
  return true;
}
