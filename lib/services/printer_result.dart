class PrinterResult {
  final bool success;
  final String message;
  final String? deviceName;

  const PrinterResult({
    required this.success,
    required this.message,
    this.deviceName,
  });
}
