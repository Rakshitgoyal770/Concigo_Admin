import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../core/widgets/luxury_text_field.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../data/providers/supabase_providers.dart';
import '../../../../data/providers/reception_providers.dart';

class FolioBillingSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> stay;

  const FolioBillingSheet({
    super.key,
    required this.stay,
  });

  @override
  ConsumerState<FolioBillingSheet> createState() => _FolioBillingSheetState();
}

class _FolioBillingSheetState extends ConsumerState<FolioBillingSheet> {
  final _chargeNameController = TextEditingController();
  final _chargeAmountController = TextEditingController();
  final _paymentAmountController = TextEditingController();

  String _paymentMode = 'CASH';
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _chargeNameController.dispose();
    _chargeAmountController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  Future<void> _addSurcharge() async {
    final name = _chargeNameController.text.trim();
    final amt = double.tryParse(_chargeAmountController.text.trim()) ?? 0;
    final stayId = (widget.stay['stay_id'] ?? widget.stay['id']).toString();

    if (name.isEmpty || amt <= 0) {
      setState(() => _errorMessage = 'Please provide charge name and valid amount.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await ref.read(billingServiceProvider).addSurcharge(
        stayId: stayId,
        chargeName: name,
        amount: amt,
      );
      ref.read(receptionRefreshSignalProvider.notifier).state++;
      _chargeNameController.clear();
      _chargeAmountController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.success, content: Text('Added ₹$amt charge for $name.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to add charge: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _recordPayment() async {
    final amt = double.tryParse(_paymentAmountController.text.trim()) ?? 0;
    final stayId = (widget.stay['stay_id'] ?? widget.stay['id']).toString();

    if (amt <= 0) {
      setState(() => _errorMessage = 'Please enter a valid payment amount.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await ref.read(billingServiceProvider).recordPayment(
        stayId: stayId,
        amount: amt,
        paymentMode: _paymentMode,
      );
      ref.read(receptionRefreshSignalProvider.notifier).state++;
      _paymentAmountController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.success, content: Text('Recorded payment of ₹$amt via $_paymentMode.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to record payment: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stay = widget.stay;
    final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
    final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'N/A').toString();
    final totalTariff = stay['total_amount'] ?? stay['tariff'] ?? 2500;
    final paidAmount = stay['paid_amount'] ?? 0;
    final outstanding = (totalTariff is num && paidAmount is num) ? (totalTariff - paidAmount).clamp(0, 999999) : 0;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 640,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                      ),
                      AppSpacing.gapH12,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guest Folio & Billing', style: AppTypography.titleMedium),
                          Text('Room $roomNum • $guestName', style: AppTypography.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const Divider(height: 32),

              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: AppColors.departure, fontSize: 13)),
                AppSpacing.gapV12,
              ],

              // Folio Balance Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Total Tariff', style: AppTypography.bodySmall),
                        AppSpacing.gapV4,
                        Text('₹$totalTariff', style: AppTypography.monoMetric.copyWith(fontSize: 18)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Paid to Date', style: AppTypography.bodySmall),
                        AppSpacing.gapV4,
                        Text('₹$paidAmount', style: AppTypography.monoMetric.copyWith(fontSize: 18, color: AppColors.success)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Outstanding Balance', style: AppTypography.bodySmall),
                        AppSpacing.gapV4,
                        Text('₹$outstanding', style: AppTypography.monoMetric.copyWith(fontSize: 18, color: outstanding > 0 ? AppColors.departure : AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.gapV24,

              // Add Surcharge Section
              Text('Add Incidentals / Surcharge', style: AppTypography.labelLarge),
              AppSpacing.gapV12,
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: LuxuryTextField(
                      controller: _chargeNameController,
                      hintText: 'e.g. Minibar / Restaurant / Late Checkout',
                    ),
                  ),
                  AppSpacing.gapH8,
                  Expanded(
                    flex: 1,
                    child: LuxuryTextField(
                      controller: _chargeAmountController,
                      hintText: 'Amount ₹',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  AppSpacing.gapH8,
                  LuxuryButton(
                    text: 'Add',
                    variant: LuxuryButtonVariant.secondary,
                    onPressed: _addSurcharge,
                  ),
                ],
              ),
              AppSpacing.gapV24,

              // Record Payment Section
              Text('Collect Payment', style: AppTypography.labelLarge),
              AppSpacing.gapV12,
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      value: _paymentMode,
                      decoration: const InputDecoration(labelText: 'Payment Method'),
                      items: const [
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'CARD', child: Text('Credit / Debit Card')),
                        DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                        DropdownMenuItem(value: 'ROOM_CHARGE', child: Text('Room Bill')),
                      ],
                      onChanged: (v) => setState(() => _paymentMode = v ?? 'CASH'),
                    ),
                  ),
                  AppSpacing.gapH8,
                  Expanded(
                    flex: 1,
                    child: LuxuryTextField(
                      controller: _paymentAmountController,
                      hintText: 'Paid Amount ₹',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  AppSpacing.gapH8,
                  LuxuryButton(
                    text: 'Record Payment',
                    variant: LuxuryButtonVariant.success,
                    isLoading: _isProcessing,
                    onPressed: _recordPayment,
                  ),
                ],
              ),
              AppSpacing.gapV24,

              // Close
              Align(
                alignment: Alignment.centerRight,
                child: LuxuryButton(
                  text: 'Done',
                  variant: LuxuryButtonVariant.primary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
