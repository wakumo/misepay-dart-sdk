/// Formats a timestamp for the PaymentIntent JSON wire contract.
String formatUtcTimestamp(DateTime value) {
  final utc = value.toUtc();
  final timestamp = utc.toIso8601String();
  if (utc.millisecond == 0 && utc.microsecond == 0) {
    return timestamp.replaceFirst('.000Z', 'Z');
  }
  return timestamp;
}
