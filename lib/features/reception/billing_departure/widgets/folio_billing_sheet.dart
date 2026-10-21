import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../core/widgets/luxury_text_field.dart';
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
      final result = await ref.read(billingServiceProvider).addSurcharge(
        stayId: stayId,
        chargeName: name,
        amount: amt,
      );
      if (!mounted) return;
      ref.read(receptionRefreshSignalProvider.notifier).state++;
      _chargeNameController.clear();
      _chargeAmountController.clear();
      _showOutcome(
        okText: 'Added ₹$amt charge for $name.',
        pmsFailed: result.pmsFailed,
        pmsError: result.pmsError,
        what: 'charge',
      );
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
    if (_paymentMode == 'ROOM_CHARGE') {
      // "Room Bill" means the amount stays on the room account. Nothing has been
      // paid, so there is nothing to record (recording it would zero the guest's
      // balance in the PMS for money that was never received).
      setState(() => _errorMessage =
          'Room Bill keeps the charge on the guest\'s room account — no payment to record. '
          'Choose Cash, Card or UPI once money is actually received.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(billingServiceProvider).recordPayment(
        stayId: stayId,
        amount: amt,
        paymentMode: _paymentMode,
      );
      if (!mounted) return;
      ref.read(receptionRefreshSignalProvider.notifier).state++;
      _paymentAmountController.clear();
      final settled = result.billsSettled == 0
          ? 'No bill was fully covered'
          : '${result.billsSettled} bill${result.billsSettled == 1 ? '' : 's'} settled';
      final due = result.stillDue > 0 ? ' · ₹${result.stillDue.toStringAsFixed(2)} still due' : '';
      _showOutcome(
        okText: 'Recorded ₹$amt via $_paymentMode. $settled$due.',
        pmsFailed: result.pmsFailed,
        pmsError: result.pmsError,
        what: 'payment',
      );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to record payment: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Green when everything worked; amber when it was saved in Concigo but the
  /// PMS did not accept it, so the desk knows to follow up.
  void _showOutcome({
    required String okText,
    required bool pmsFailed,
    required String? pmsError,
    required String what,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (!pmsFailed) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.success, content: Text(okText)));
      return;
    }
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.attention,
      duration: const Duration(seconds: 10),
      showCloseIcon: true,
      content: Text(
        '$okText\nSaved in Concigo, but the $what was NOT posted to the PMS: '
        '${(pmsError ?? 'unknown error').replaceAll(RegExp(r'\s+'), ' ')}. Tell the manager to re-post it.',
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final stay = widget.stay;
    final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
    final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'N/A').toString();
    final roomTariff = (stay['tariff'] is num ? (stay['tariff'] as num).toDouble() : double.tryParse(stay['tariff']?.toString() ?? '2500') ?? 2500.0);
    final totalAmount = (stay['total_amount'] is num ? (stay['total_amount'] as num).toDouble() : roomTariff);
    final paidAmount = (stay['paid_amount'] is num ? (stay['paid_amount'] as num).toDouble() : 0.0);
    final outstanding = (totalAmount - paidAmount).clamp(0.0, 999999.0);
    final bills = (stay['service_bills'] as List?) ?? [];

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
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
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Guest Folio & Billing', style: AppTypography.titleMedium, overflow: TextOverflow.ellipsis),
                              Text('Room $roomNum • $guestName', style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        Text('Room Tariff', style: AppTypography.bodySmall),
                        AppSpacing.gapV4,
                        Text('₹${roomTariff.toStringAsFixed(0)}', style: AppTypography.monoMetric.copyWith(fontSize: 17)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Total Charges', style: AppTypography.bodySmall),
                        AppSpacing.gapV4,
                        Text('₹${totalAmount.toStringAsFixed(0)}', style: AppTypography.monoMetric.copyWith(fontSize: 17)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Paid', style: AppTypography.bodySmall),
                        AppSpacing.gapV4,
                        Text('₹${paidAmount.toStringAsFixed(0)}', style: AppTypography.monoMetric.copyWith(fontSize: 17, color: AppColors.success)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Balance Due', style: AppTypography.bodySmall),
                        AppSpacing.gapV4,
                        Text('₹${outstanding.toStringAsFixed(0)}', style: AppTypography.monoMetric.copyWith(fontSize: 17, color: outstanding > 0 ? AppColors.departure : AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.gapV24,

              // Itemized Folio Charges Section
              if (bills.isNotEmpty) ...[
                Text('Itemized Folio Charges (${bills.length})', style: AppTypography.labelLarge),
                AppSpacing.gapV8,
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.roundedMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bills.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
                    itemBuilder: (context, i) {
                      final b = bills[i] as Map;
                      final amt = (b['amt'] as num?)?.toDouble() ?? 0.0;
                      final cat = (b['charge_category'] ?? 'Incidentals').toString();
                      final desc = (b['description'] ?? cat).toString();
                      final isPaid = (b['payment_status'] ?? '').toString().toLowerCase() == 'paid';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cat == 'Accommodation' ? AppColors.primaryLight : AppColors.surfaceSubtle,
                                borderRadius: AppSpacing.roundedSm,
                              ),
                              child: Text(cat, style: AppTypography.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                            AppSpacing.gapH12,
                            Expanded(
                              child: Text(desc, style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isPaid ? AppColors.successLight : AppColors.departureLight,
                                borderRadius: AppSpacing.roundedSm,
                              ),
                              child: Text(
                                isPaid ? 'PAID' : 'UNPAID',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isPaid ? AppColors.success : AppColors.departure,
                                ),
                              ),
                            ),
                            Text('₹${amt.toStringAsFixed(2)}', style: AppTypography.monoMetric.copyWith(fontSize: 14)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                AppSpacing.gapV24,
              ],

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
                        DropdownMenuItem(value: 'ROOM_CHARGE', child: Text('Room Bill (no payment)')),
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
