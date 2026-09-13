import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../core/widgets/luxury_text_field.dart';
import '../../../../data/providers/supabase_providers.dart';
import '../../../../data/providers/reception_providers.dart';

class CreateOfferDialog extends ConsumerStatefulWidget {
  const CreateOfferDialog({super.key});

  @override
  ConsumerState<CreateOfferDialog> createState() => _CreateOfferDialogState();
}

class _CreateOfferDialogState extends ConsumerState<CreateOfferDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _discountController = TextEditingController();
  final _codeController = TextEditingController();

  String _offerType = 'DISCOUNT';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitOffer() async {
    final title = _titleController.text.trim();
    final discount = double.tryParse(_discountController.text.trim()) ?? 0;
    final code = _codeController.text.trim();

    if (title.isEmpty) {
      setState(() => _errorMessage = 'Offer title is required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final offerService = ref.read(offerServiceProvider);
      final propId = await ref.read(resolvedPropertyIdProvider.future);

      await offerService.createOffer({
        'property_id': propId,
        'title': title,
        'description': _descriptionController.text.trim(),
        'offer_type': _offerType,
        'discount_value': discount,
        'promo_code': code.toUpperCase(),
        'is_active': true,
        'valid_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });

      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Offer created and published successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to create offer: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          return Container(
            width: 520,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.purpleLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.local_offer_outlined, color: AppColors.purple, size: 20),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create In-Stay Offer',
                              style: AppTypography.titleMedium.copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Publish deals & discounts for guests',
                              style: AppTypography.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: const TextStyle(color: AppColors.departure, fontSize: 13)),
                    AppSpacing.gapV12,
                  ],

                  LuxuryTextField(
                    controller: _titleController,
                    label: 'Offer Title',
                    hintText: 'e.g. 20% Off Rooftop Dining',
                  ),
                  AppSpacing.gapV12,

                  LuxuryTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hintText: 'Full package terms & benefits for the guest...',
                    maxLines: 2,
                  ),
                  AppSpacing.gapV12,

                  if (isNarrow) ...[
                    DropdownButtonFormField<String>(
                      value: _offerType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Offer Type',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'DISCOUNT', child: Text('Percentage Discount (%)')),
                        DropdownMenuItem(value: 'FLAT', child: Text('Flat Amount (₹ Off)')),
                        DropdownMenuItem(value: 'PACKAGE', child: Text('Experience Bundle')),
                        DropdownMenuItem(value: 'EARLY_LATE', child: Text('Stay Waiver')),
                      ],
                      onChanged: (v) => setState(() => _offerType = v ?? 'DISCOUNT'),
                    ),
                    AppSpacing.gapV12,
                    LuxuryTextField(
                      controller: _discountController,
                      label: 'Value (₹ / %)',
                      hintText: 'e.g. 20',
                      keyboardType: TextInputType.number,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _offerType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Offer Type',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'DISCOUNT', child: Text('Percentage (%)')),
                              DropdownMenuItem(value: 'FLAT', child: Text('Flat (₹ Off)')),
                              DropdownMenuItem(value: 'PACKAGE', child: Text('Bundle')),
                              DropdownMenuItem(value: 'EARLY_LATE', child: Text('Waiver')),
                            ],
                            onChanged: (v) => setState(() => _offerType = v ?? 'DISCOUNT'),
                          ),
                        ),
                        AppSpacing.gapH12,
                        Expanded(
                          child: LuxuryTextField(
                            controller: _discountController,
                            label: 'Value (₹ / %)',
                            hintText: 'e.g. 20',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                  AppSpacing.gapV12,

                  LuxuryTextField(
                    controller: _codeController,
                    label: 'Promo / Desk Code',
                    hintText: 'e.g. VIP20',
                  ),
                  AppSpacing.gapV20,

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                      ),
                      AppSpacing.gapH8,
                      LuxuryButton(
                        text: 'Publish Offer',
                        variant: LuxuryButtonVariant.primary,
                        height: 38,
                        isLoading: _isSubmitting,
                        onPressed: _submitOffer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
