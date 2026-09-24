import 'dart:convert';
import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'printer_result.dart';

@JS('posThermalPrinter.printRawBytes')
external JSPromise<JSObject> _jsPrintRawBytes(JSString base64Data);

@JS('posThermalPrinter.printSystemReceipt')
external JSPromise<JSObject> _jsPrintSystemReceipt(JSString htmlOrText);

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
        message: 'Successfully printed via Local Serial Bridge!',
        deviceName: 'Receipt Printer (Local Bridge)',
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
      message: 'Successfully printed via Web Serial!',
      deviceName: 'Receipt Printer (Web Serial)',
    );
  } catch (e) {
    return PrinterResult(
      success: false,
      message: 'Web Serial print error: $e',
    );
  }
}

Future<PrinterResult> platformPrintSystem(String receiptText) async {
  try {
    final promise = _jsPrintSystemReceipt(receiptText.toJS);
    await promise.toDart;
    return const PrinterResult(
      success: true,
      message: 'Receipt sent to System Print dialog.',
      deviceName: 'System / Default Printer',
    );
  } catch (e) {
    return PrinterResult(
      success: false,
      message: 'System print error: $e',
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
        message: 'Local Serial Bridge is active & ready!',
        deviceName: 'Receipt Printer (Local Bridge)',
      );
    }
  } catch (_) {}

  // 2. Web Serial API in Edge / Chrome
  try {
    final promise = _jsConnect();
    await promise.toDart;
    return const PrinterResult(
      success: true,
      message: 'Web Serial port connected!',
      deviceName: 'Receipt Printer (Web Serial)',
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
