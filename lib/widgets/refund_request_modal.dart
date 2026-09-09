import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/snackbar_helper.dart';
import '../core/utils/validators.dart';
import '../models/booking_model.dart';
import '../models/booking_refund_model.dart';
import '../services/booking_service.dart';
import 'custom_text_field.dart';
import 'neon_button.dart';
import 'tap_collapse.dart';

/// Bottom sheet modal for submitting a cancellation refund request with 24h eligibility check.
class RefundRequestModal extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onRefundSubmitted;

  const RefundRequestModal({
    super.key,
    required this.booking,
    this.onRefundSubmitted,
  });

  static Future<BookingRefundModel?> show(
    BuildContext context, {
    required BookingModel booking,
    VoidCallback? onRefundSubmitted,
  }) {
    return showModalBottomSheet<BookingRefundModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RefundRequestModal(
        booking: booking,
        onRefundSubmitted: onRefundSubmitted,
      ),
    );
  }

  @override
  State<RefundRequestModal> createState() => _RefundRequestModalState();
}

class _RefundRequestModalState extends State<RefundRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _reasonController = TextEditingController(text: 'Schedule Conflict');

  String _selectedWallet = 'gcash';
  bool _isLoading = false;

  final List<Map<String, String>> _walletOptions = const [
    {'id': 'gcash', 'label': 'GCash'},
    {'id': 'maya', 'label': 'Maya'},
    {'id': 'bank_transfer', 'label': 'Bank Transfer'},
    {'id': 'counter_cash', 'label': 'Counter Cash'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRefund() async {
    if (!widget.booking.isCancellable) {
      AppSnackBar.error(
        context,
        'Cancellations only permitted 24+ hours before match start.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final refund = await BookingService.instance.requestRefund(
        bookingId: widget.booking.id,
        amount: widget.booking.totalPrice,
        walletType: _selectedWallet,
        accountName: _nameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        AppSnackBar.success(
          context,
          'Refund request submitted successfully (Pending Review).',
        );
        widget.onRefundSubmitted?.call();
        Navigator.of(context).pop(refund);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          'Failed to submit refund: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEligible = widget.booking.isCancellable;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REQUEST REFUND',
                          style: TextStyle(
                            fontFamily: 'BebasNeue',
                            fontSize: 26,
                            letterSpacing: -0.5,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          '${widget.booking.courtName ?? "Court"} • ₱${widget.booking.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.ink),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 24-Hour Policy Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEligible
                      ? AppColors.courtSuccess.withValues(alpha: 0.08)
                      : AppColors.saleRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEligible
                        ? AppColors.courtSuccess.withValues(alpha: 0.25)
                        : AppColors.saleRed.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEligible ? Icons.verified_user_outlined : Icons.warning_amber_rounded,
                      color: isEligible ? AppColors.courtSuccess : AppColors.saleRed,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEligible
                            ? 'Eligible for 100% full refund under our 24-Hour Policy.'
                            : 'Ineligible: Cancellations must be made 24+ hours in advance.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isEligible ? AppColors.courtSuccess : AppColors.saleRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Refund Destination E-Wallets
              const Text(
                'SELECT REFUND DESTINATION',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.mute,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _walletOptions.map((w) {
                  final isSelected = _selectedWallet == w['id'];
                  return TapCollapse(
                    onTap: () => setState(() => _selectedWallet = w['id']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.ink : AppColors.softCloud,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isSelected ? AppColors.ink : AppColors.hairline,
                        ),
                      ),
                      child: Text(
                        w['label']!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.canvas : AppColors.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Form Inputs
              CustomTextField(
                label: 'ACCOUNT HOLDER NAME',
                hintText: 'Juan Dela Cruz',
                controller: _nameController,
                validator: (v) => Validators.validateFullName(v),
              ),
              const SizedBox(height: 14),

              CustomTextField(
                label: '${_selectedWallet.toUpperCase()} NUMBER / ACCOUNT DETAILS',
                hintText: _selectedWallet == 'gcash' || _selectedWallet == 'maya'
                    ? '09171234567'
                    : 'Bank Account Number',
                controller: _accountNumberController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please provide destination account number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              CustomTextField(
                label: 'REASON FOR CANCELLATION',
                hintText: 'Schedule Conflict, Medical, Weather, etc.',
                controller: _reasonController,
              ),
              const SizedBox(height: 24),

              // Action Button
              NeonButton(
                text: 'CONFIRM CANCELLATION & SUBMIT REFUND',
                isLoading: _isLoading,
                onPressed: isEligible ? _submitRefund : null,
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Processed within 24–48 hours to registered wallet.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.mute,
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
