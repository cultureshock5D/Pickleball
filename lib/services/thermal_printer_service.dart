import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'printer_result.dart';
import 'thermal_printer_io.dart' if (dart.library.js_interop) 'thermal_printer_web.dart';

export 'printer_result.dart';

class ThermalPrinterService {
  /// Test hook to mock printing during automated testing
  @visibleForTesting
  static Future<PrinterResult> Function(List<int> bytes)? testPrintHandler;

  /// Currently connected or targeted printer device name
  static String activeTargetPrinterName = _defaultTargetPrinterName;

  static String get _defaultTargetPrinterName {
    if (kIsWeb) {
      return 'Receipt Printer (Web Serial / System)';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'POS-58 (Bluetooth SPP)';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      return 'POS-58 (COM Port / System)';
    }
    return 'POS-58 Thermal / System';
  }

  /// Check and connect to available thermal / POS printer.
  static Future<PrinterResult> connectPrinter() async {
    final result = await platformConnectPrinter();
    if (result.success && result.deviceName != null && result.deviceName!.isNotEmpty) {
      activeTargetPrinterName = result.deviceName!;
    }
    return result;
  }

  /// Retrieve list of paired Bluetooth devices on the system.
  static Future<List<Map<String, String>>> getPairedPrinters() async {
    return await platformGetPairedPrinters();
  }

  /// Send raw ESC/POS binary payload to POS / thermal printer.
  /// On Android: streams directly via native RFCOMM Bluetooth SPP socket (Driverless).
  /// On Windows: streams directly to detected COM serial port.
  /// On Web (Edge / Chrome): streams via Web Serial API or local serial Python bridge.
  static Future<PrinterResult> print58mmReceipt(List<int> bytes) async {
    if (testPrintHandler != null) {
      return await testPrintHandler!(bytes);
    }
    // Defense-in-depth: Ensure all byte elements are strictly in the range 0..255
    final safeBytes = bytes.map((b) => (b < 0 || b > 255) ? 0x20 : b).toList();
    final result = await platformPrint58mm(safeBytes);
    if (result.success && result.deviceName != null && result.deviceName!.isNotEmpty) {
      activeTargetPrinterName = result.deviceName!;
    }
    return result;
  }

  /// Print receipt to ANY printer via standard OS / Browser System Print Dialog.
  static Future<PrinterResult> printSystemReceipt(String plainTextReceipt) async {
    final result = await platformPrintSystem(plainTextReceipt);
    if (result.success && result.deviceName != null && result.deviceName!.isNotEmpty) {
      activeTargetPrinterName = result.deviceName!;
    }
    return result;
  }

  /// Generate 32-column test receipt payload matching universal ESC/POS standards
  static List<int> generateTestReceiptBytes() {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final bytes = <int>[];

    // INIT
    bytes.addAll([0x1B, 0x40]);
    // CENTER + BOLD ON
    bytes.addAll([0x1B, 0x61, 0x01, 0x1B, 0x45, 0x01]);
    bytes.addAll('C&J SPORTS ARENA POS\n'.codeUnits);
    bytes.addAll('** BLUETOOTH PRINT TEST **\n'.codeUnits);
    // BOLD OFF
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll('Printer: Universal ESC/POS (58mm)\n'.codeUnits);
    bytes.addAll('Date: $now\n'.codeUnits);
    // LEFT
    bytes.addAll([0x1B, 0x61, 0x00]);
    bytes.addAll('--------------------------------\n'.codeUnits);
    bytes.addAll('Item             Qty       Price\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);
    bytes.addAll('Court 1 (Pickle)   1     P600.00\n'.codeUnits);
    bytes.addAll('Bottled Water      2      P70.00\n'.codeUnits);
    bytes.addAll('Overgrip           1     P150.00\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);
    // BOLD ON
    bytes.addAll([0x1B, 0x45, 0x01]);
    bytes.addAll('TOTAL AMOUNT:            P820.00\n'.codeUnits);
    // BOLD OFF
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll('Payment: CASH            P1000.0\n'.codeUnits);
    bytes.addAll('Change:                  P180.00\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);
    // CENTER + BOLD ON
    bytes.addAll([0x1B, 0x61, 0x01, 0x1B, 0x45, 0x01]);
    bytes.addAll('*** TEST PRINT SUCCESSFUL ***\n'.codeUnits);
    bytes.addAll([0x1B, 0x45, 0x00]);
    bytes.addAll('Universal ESC/POS OK\n'.codeUnits);
    bytes.addAll('\n\n\n\n'.codeUnits);

    return bytes;
  }

  /// Print a hardware test receipt to verify driverless connectivity.
  static Future<PrinterResult> printTestReceipt() async {
    final testBytes = generateTestReceiptBytes();
    return await print58mmReceipt(testBytes);
  }
}

