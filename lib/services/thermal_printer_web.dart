import 'dart:convert';
import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'printer_result.dart';

@JS('posThermalPrinter.printRawBytes')
external JSPromise<JSObject> _jsPrintRawBytes(JSString base64Data);

@JS('posThermalPrinter.connect')
external JSPromise<JSObject> _jsConnect();

Future<PrinterResult> platformPrint58mm(List<int> bytes) async {
  final base64Payload = base64Encode(bytes);

  // 1. Check if local Python bridge server is running on localhost:5858
  try {
    final response = await http
        .post(
          Uri.parse('http://127.0.0.1:5858/print'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'payload': base64Payload}),
        )
        .timeout(const Duration(milliseconds: 2500));

    if (response.statusCode == 200) {
      return const PrinterResult(
        success: true,
        message: 'Successfully printed to JP58H-0A4B via Local COM4 Bridge!',
        deviceName: 'JP58H-0A4B (Local Bridge / COM4)',
      );
    }
  } catch (_) {
    // Local bridge not active, proceed to Web Serial API
  }

  // 2. Web Serial API in Microsoft Edge / Google Chrome
  try {
    final promise = _jsPrintRawBytes(base64Payload.toJS);
    await promise.toDart;
    return const PrinterResult(
      success: true,
      message: 'Successfully printed via Edge Web Serial directly to JP58H-0A4B!',
      deviceName: 'JP58H-0A4B (Edge Web Serial)',
    );
  } catch (e) {
    return PrinterResult(
      success: false,
      message: 'Edge Web Serial: $e. You can also run "python scripts/printer_bridge_server.py".',
    );
  }
}

Future<PrinterResult> platformConnectPrinter() async {
  // 1. Try local Python bridge server
  try {
    final resp = await http
        .get(Uri.parse('http://127.0.0.1:5858/'))
        .timeout(const Duration(milliseconds: 1500));
    if (resp.statusCode == 200) {
      return const PrinterResult(
        success: true,
        message: 'Local Python COM4 Bridge is active & ready!',
        deviceName: 'JP58H-0A4B (COM4)',
      );
    }
  } catch (_) {}

  // 2. Web Serial API in Edge
  try {
    final promise = _jsConnect();
    await promise.toDart;
    return const PrinterResult(
      success: true,
      message: 'Web Serial port connected at 9600 baud!',
      deviceName: 'JP58H-0A4B (COM4 / Bluetooth)',
    );
  } catch (e) {
    return PrinterResult(
      success: false,
      message: 'Could not connect via Web Serial: $e',
    );
  }
}

Future<List<Map<String, String>>> platformGetPairedPrinters() async {
  return [];
}
