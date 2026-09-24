import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../services/thermal_printer_service.dart';

class PosPrinterDebugModal extends StatefulWidget {
  const PosPrinterDebugModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const PosPrinterDebugModal(),
    );
  }

  @override
  State<PosPrinterDebugModal> createState() => _PosPrinterDebugModalState();
}

class _PosPrinterDebugModalState extends State<PosPrinterDebugModal> {
  bool _isConnecting = false;
  bool _isPrintingTest = false;
  String _statusText = 'Ready to test printer connection.';
  String? _connectedDeviceName;
  bool? _lastSuccess;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _addLog('Diagnostic console initialized.');
    _detectEnvironment();
  }

  void _addLog(String msg) {
    final time = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() {
      _logs.add('[$time] $msg');
    });
  }

  void _detectEnvironment() {
    if (kIsWeb) {
      _addLog('Platform: Web Browser (Microsoft Edge / Google Chrome).');
      _addLog('Mechanism: Web Serial API (Any Serial/USB Printer) + System Print Dialog + Local Bridge.');
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      _addLog('Platform: Android Mobile / Tablet (Native Bluetooth SPP).');
      _addLog('UUID: 00001101-0000-1000-8000-00805F9B34FB (100% Driverless).');
      _addLog('Target Printers: Any paired Bluetooth or ESC/POS thermal printer.');
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      _addLog('Platform: Windows Desktop.');
      _addLog('Target: Any Virtual Serial Port (COM1-COM20) or Windows Default Printer.');
    }
  }

  Future<void> _handleConnect() async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _statusText = 'Searching for connected/paired printer...';
    });
    _addLog('Searching for POS receipt printer...');

    try {
      final result = await ThermalPrinterService.connectPrinter();
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _lastSuccess = result.success;
        _statusText = result.message;
        if (result.success && result.deviceName != null) {
          _connectedDeviceName = result.deviceName;
        }
      });
      _addLog(result.success ? 'SUCCESS: ${result.message}' : 'NOTICE: ${result.message}');
      if (result.success) {
        AppSnackBar.success(context, result.message);
      } else {
        AppSnackBar.info(context, result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _lastSuccess = false;
        _statusText = 'Error connecting: $e';
      });
      _addLog('ERROR: $e');
    }
  }

  Future<void> _handleTestPrint() async {
    if (_isPrintingTest) return;
    setState(() {
      _isPrintingTest = true;
      _statusText = 'Sending ESC/POS test payload...';
    });
    _addLog('Triggering test print (Universal ESC/POS test receipt)...');

    try {
      final result = await ThermalPrinterService.printTestReceipt();
      if (!mounted) return;
      setState(() {
        _isPrintingTest = false;
        _lastSuccess = result.success;
        _statusText = result.message;
      });
      _addLog(result.success ? 'PRINT SUCCESS: ${result.message}' : 'PRINT FAILED: ${result.message}');
      if (result.success) {
        AppSnackBar.success(context, result.message);
      } else {
        AppSnackBar.error(context, result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPrintingTest = false;
        _lastSuccess = false;
        _statusText = 'Print exception: $e';
      });
      _addLog('EXCEPTION: $e');
    }
  }

  Future<void> _handleSystemPrintTest() async {
    _addLog('Triggering System Print Dialog test...');
    const testText = 'C&J SPORTS ARENA POS\\n*** SYSTEM PRINT TEST ***\\nCompatible with ANY printer.\\n';
    final result = await ThermalPrinterService.printSystemReceipt(testText);
    if (!mounted) return;
    _addLog(result.success ? 'SYSTEM PRINT: ${result.message}' : 'SYSTEM PRINT ERROR: ${result.message}');
    if (result.success) {
      AppSnackBar.success(context, result.message);
    } else {
      AppSnackBar.info(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 540,
          constraints: const BoxConstraints(maxHeight: 720),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E599).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.print,
                        color: Color(0xFF00E599),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thermal & POS Printer Diagnostics',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Universal POS • Thermal & System Printer',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _lastSuccess == true
                                ? const Color(0xFF00E599)
                                : colors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _lastSuccess == true
                                        ? const Color(0xFF00E599)
                                        : const Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _connectedDeviceName != null
                                        ? 'Target: $_connectedDeviceName'
                                        : kIsWeb
                                            ? 'Target: Any Serial, USB, or System Printer'
                                            : 'Target: Any Bluetooth or System Printer',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E599).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '100% DRIVERLESS',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF00E599),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _statusText,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Platform Guide Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How Driverless Works on Your Device:',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              kIsWeb
                                  ? '• On Edge/Chrome: Click "Connect Port" below to pair with any serial or USB thermal printer via Web Serial, OR use System Print.\n• Compatible with ANY printer.'
                                  : defaultTargetPlatform == TargetPlatform.android
                                      ? '• On Android: Connects directly via Bluetooth RFCOMM socket (SPP UUID 00001101).\n• Compatible with any paired Bluetooth printer (Epson, Star, Sunmi, POS-58, etc.).'
                                      : '• On Windows Desktop: Streams raw ESC/POS commands directly to any detected COM port, or sends to Windows Default Printer.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                height: 1.5,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: _isConnecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.bluetooth_searching, size: 18),
                              label: Text(
                                _isConnecting ? 'Connecting...' : 'Connect Port',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.border),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isConnecting ? null : _handleConnect,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: _isPrintingTest
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0A0F0D),
                                      ),
                                    )
                                  : const Icon(Icons.print, size: 18),
                              label: Text(
                                _isPrintingTest ? 'Printing...' : 'ESC/POS Test',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E599),
                                foregroundColor: const Color(0xFF0A0F0D),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _isPrintingTest ? null : _handleTestPrint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: Text(
                                'System Print',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textPrimary,
                                side: BorderSide(color: colors.border),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _handleSystemPrintTest,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Monospace Log Console
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Realtime Diagnostic Log:',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.copy, size: 14),
                            label: const Text('Copy Log', style: TextStyle(fontSize: 11)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _logs.join('\n')));
                              AppSnackBar.info(context, 'Diagnostics log copied.');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        height: 160,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF020617),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Text(
                            _logs.join('\n'),
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: const Color(0xFF38BDF8),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close Diagnostics', style: GoogleFonts.inter(color: colors.textSecondary)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
