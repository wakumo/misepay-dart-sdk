/// Exception thrown by SDK validation and HTTP response handling.
class MisePayException implements Exception {
  /// Creates an exception with a stable machine-readable [code] and message.
  MisePayException(this.code, this.message);

  /// Stable machine-readable error code.
  final String code;

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'MisePayException($code): $message';
}
