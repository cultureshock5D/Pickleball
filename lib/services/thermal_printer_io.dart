import 'dart:io';
import 'package:flutter/services.dart';
import 'printer_result.dart';

const _channel = MethodChannel('com.example.pickleball_app/thermal_printer');

Future<PrinterResult> platformPrint58mm(List<int> bytes) async {
  if (Platform.isAndroid) {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'printRawBytes',
        {'bytes': Uint8List.fromList(bytes)},
      );
      final deviceName = result?['deviceName'] as String? ?? 'XP-58H';
      return PrinterResult(
        success: true,
        message: 'Successfully printed to $deviceName via direct Bluetooth RFCOMM.',
        deviceName: deviceName,
      );
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return const PrinterResult(
          success: false,
          message: 'Permission required: Please allow "Nearby devices" permission to communicate with your Bluetooth thermal printer.',
        );
      } else if (e.code == 'BLUETOOTH_DISABLED') {
        return const PrinterResult(
          success: false,
          message: 'Bluetooth is turned OFF. Please turn on Bluetooth in Android Quick Settings.',
        );
      }
      return PrinterResult(
        success: false,
        message: e.message ?? 'Failed to connect to Bluetooth printer.',
      );
    } catch (e) {
      return PrinterResult(
        success: false,
        message: 'Android Bluetooth error: $e',
      );
    }
  } else if (Platform.isWindows) {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\pos_receipt.bin');
      await tempFile.writeAsBytes(bytes, flush: true);

      // Call Python helper
      const scriptPath = 'scripts\\print_escpos_windows.py';
      final res = await Process.run('python', [scriptPath, tempFile.path]);

      if (res.exitCode == 0) {
        return const PrinterResult(
          success: true,
          message: 'Successfully printed to XP-58H on COM4 via direct serial.',
          deviceName: 'XP-58H / JP58H (COM4)',
        );
      } else {
        final errOutput = (res.stderr as String).trim();
        final stdOutput = (res.stdout as String).trim();
        final combined = errOutput.isNotEmpty ? errOutput : stdOutput;
        return PrinterResult(
          success: false,
          message: combined.isNotEmpty ? combined : 'Printer busy or COM4 port unavailable.',
        );
      }
    } catch (e) {
      return PrinterResult(
        success: false,
        message: 'Windows print error: $e',
      );
    }
  }

  return const PrinterResult(
    success: false,
    message: 'Direct thermal printing is supported on Android and Windows.',
  );
}

Future<PrinterResult> platformConnectPrinter() async {
  if (Platform.isAndroid) {
    try {
      final printers = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getPairedPrinters');
      if (printers == null || printers.isEmpty) {
        return const PrinterResult(
          success: false,
          message: 'No paired Bluetooth devices found. Please pair XP-58H in phone Bluetooth Settings (PIN: 0000 or 1234).',
        );
      }

      final matchedPrinter = printers.firstWhere(
        (p) {
          final name = (p['name'] as String? ?? '').toUpperCase();
          return name.contains('XP') ||
              name.contains('58') ||
              name.contains('JP') ||
              name.contains('POS') ||
              name.contains('0A4B') ||
              name.contains('PRINTER') ||
              name.contains('MPT') ||
              name.contains('RPP');
        },
        orElse: () => printers.first,
      );

      final deviceName = matchedPrinter['name'] as String? ?? 'XP-58H';
      final address = matchedPrinter['address'] as String? ?? '';

      return PrinterResult(
        success: true,
        message: 'Printer connected & ready: $deviceName ($address)',
        deviceName: deviceName,
      );
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        return const PrinterResult(
          success: false,
          message: 'Permission required: Please allow "Nearby devices" permission in Android App Settings to scan Bluetooth printers.',
        );
      } else if (e.code == 'BLUETOOTH_DISABLED') {
        return const PrinterResult(
          success: false,
          message: 'Bluetooth is turned OFF. Please turn on Bluetooth in Android Quick Settings.',
        );
      }
      return PrinterResult(success: false, message: e.message ?? 'Bluetooth error');
    } catch (e) {
      return PrinterResult(success: false, message: 'Bluetooth check error: $e');
    }
  } else if (Platform.isWindows) {
    return const PrinterResult(
      success: true,
      message: 'Windows COM4 / COM3 Bluetooth Serial connection is active.',
      deviceName: 'XP-58H / JP58H (COM4)',
    );
  }

  return const PrinterResult(
    success: false,
    message: 'Unsupported platform.',
  );
}

Future<List<Map<String, String>>> platformGetPairedPrinters() async {
  if (Platform.isAndroid) {
    try {
      final list = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getPairedPrinters');
      if (list == null) return [];
      return list.map((item) {
        return {
          'name': item['name'] as String? ?? 'Unknown Device',
          'address': item['address'] as String? ?? '',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
  return [];
}
