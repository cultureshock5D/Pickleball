import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/pos_service.dart';

class SupervisorPinResult {
  final bool authorized;
  final String? voidReason;

  const SupervisorPinResult({
    required this.authorized,
    this.voidReason,
  });
}

class SupervisorPinModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool requireReason;

  const SupervisorPinModal({
    super.key,
    this.title = 'Supervisor Authorization',
    this.subtitle = 'Enter 4-digit Master PIN to proceed',
    this.requireReason = false,
  });

  static Future<SupervisorPinResult?> show(
    BuildContext context, {
    String title = 'Supervisor Authorization',
    String subtitle = 'Enter 4-digit Master PIN to proceed',
    bool requireReason = false,
  }) {
    return showDialog<SupervisorPinResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SupervisorPinModal(
        title: title,
        subtitle: subtitle,
        requireReason: requireReason,
      ),
    );
  }

  @override
  State<SupervisorPinModal> createState() => _SupervisorPinModalState();
}

class _SupervisorPinModalState extends State<SupervisorPinModal>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isVerifying = false;
  String? _errorMessage;

  static const List<String> voidReasons = [
    'Customer Cancellation',
    'Cashier Scanning Error / Wrong Item',
    'Product Quality / Customer Return',
    'Payment Method Discrepancy',
    'Kitchen / Bar Out of Stock',
    'Other / Custom Reason',
  ];

  late String _selectedReason;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedReason = voidReasons.first;

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String val) {
    if (_pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += val;
        _errorMessage = null;
      });
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClear() {
    if (_pin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _pin = '';
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    if (_pin.length != 4) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final isValid = await PosService.instance.verifySupervisorPin(_pin);

    if (!mounted) return;

    setState(() {
      _isVerifying = false;
    });

    if (isValid) {
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(SupervisorPinResult(
        authorized: true,
        voidReason: widget.requireReason ? _selectedReason : null,
      ));
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);
      setState(() {
        _errorMessage = 'Invalid PIN. Access denied.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.accentColor,
                      size: 24,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Reason dropdown if required
              if (widget.requireReason) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'REASON FOR VOID (MANDATORY)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedReason,
                      isExpanded: true,
                      dropdownColor: colors.card,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      items: voidReasons.map((reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedReason = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // PIN Indicator Dots
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _pin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled
                                ? AppTheme.accentColor
                                : Colors.transparent,
                            border: Border.all(
                              color: isFilled
                                  ? AppTheme.accentColor
                                  : colors.border.withValues(alpha: 0.8),
                              width: 2,
                            ),
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accentColor.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Keypad
              if (_isVerifying)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: AppTheme.accentColor),
                )
              else
                Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3'], colors),
                    const SizedBox(height: 10),
                    _buildKeypadRow(['4', '5', '6'], colors),
                    const SizedBox(height: 10),
                    _buildKeypadRow(['7', '8', '9'], colors),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionKey(
                          label: 'C',
                          onTap: _onClear,
                          colors: colors,
                        ),
                        _buildNumericKey('0', colors),
                        _buildActionKey(
                          icon: Icons.backspace_outlined,
                          onTap: _onBackspace,
                          colors: colors,
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys, dynamic colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildNumericKey(k, colors)).toList(),
    );
  }

  Widget _buildNumericKey(String digit, dynamic colors) {
    return SizedBox(
      width: 68,
      height: 52,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onKeyPress(digit),
          child: Center(
            child: Text(
              digit,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    required dynamic colors,
  }) {
    return SizedBox(
      width: 68,
      height: 52,
      child: Material(
        color: colors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: label != null
                ? Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: colors.textSecondary,
                  ),
          ),
        ),
      ),
    );
  }
}
