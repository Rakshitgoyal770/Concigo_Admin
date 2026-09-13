import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../core/widgets/luxury_text_field.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../services/supabase_service.dart';

class CreateEarlyCheckinDialog extends ConsumerStatefulWidget {
  const CreateEarlyCheckinDialog({super.key});

  @override
  ConsumerState<CreateEarlyCheckinDialog> createState() => _CreateEarlyCheckinDialogState();
}

class _CreateEarlyCheckinDialogState extends ConsumerState<CreateEarlyCheckinDialog> {
  final _nameController = TextEditingController(text: 'Early Bird Check-In Pass');
  final _priceController = TextEditingController(text: '350');
  final _limitController = TextEditingController(text: '5');

  DateTime _minTime = DateTime.now().copyWith(hour: 8, minute: 0, second: 0);
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _pickMinTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _minTime,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minTime.hour, minute: _minTime.minute),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _minTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final limitStr = _limitController.text.trim();

    final price = double.tryParse(priceStr);
    final limit = int.tryParse(limitStr);

    if (name.isEmpty || price == null || price <= 0 || limit == null || limit <= 0) {
      setState(() => _errorMessage = 'Please provide valid offer name, hourly price, and guest limit.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final propId = await ref.read(resolvedPropertyIdProvider.future);
      await SupabaseService.instance.createEarlyLateOffer(
        propertyId: propId,
        offerName: name,
        minTime: _minTime,
        type: 'early_in',
        pricePerHour: price,
        limit: limit,
      );

      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Early Check-In Offer "$name" published at ₹${price.toStringAsFixed(0)}/hr (Limit: $limit)!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to publish offer: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.roundedXl,
        side: const BorderSide(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = MediaQuery.of(context).size.width < 600;

          return Container(
            constraints: const BoxConstraints(maxWidth: 540),
            padding: EdgeInsets.all(isMobile ? AppSpacing.lg : AppSpacing.xxl),
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
                          color: AppColors.infoLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.login_rounded, color: AppColors.info, size: 18),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create Early Check-In Offer', style: AppTypography.titleMedium.copyWith(fontSize: isMobile ? 16 : 18)),
                            Text('Offer arriving guests early room access for an hourly rate', style: AppTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
            AppSpacing.gapV20,

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.departureLight,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.departure),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.departure, size: 18),
                    AppSpacing.gapH8,
                    Expanded(
                      child: Text(_errorMessage!, style: AppTypography.bodySmall.copyWith(color: AppColors.departure)),
                    ),
                  ],
                ),
              ),

            LuxuryTextField(
              label: 'Offer Title',
              hintText: 'e.g. Early Bird Check-In Access',
              controller: _nameController,
            ),
            AppSpacing.gapV16,

            Row(
              children: [
                Expanded(
                  child: LuxuryTextField(
                    label: 'Price Per Hour (₹)',
                    hintText: '350',
                    keyboardType: TextInputType.number,
                    controller: _priceController,
                  ),
                ),
                AppSpacing.gapH16,
                Expanded(
                  child: LuxuryTextField(
                    label: 'Guest Limit (Rooms)',
                    hintText: '5',
                    keyboardType: TextInputType.number,
                    controller: _limitController,
                  ),
                ),
              ],
            ),
            AppSpacing.gapV16,

            Text('Earliest Allowed Arrival Time', style: AppTypography.labelMedium),
            AppSpacing.gapV8,
            InkWell(
              onTap: _pickMinTime,
              borderRadius: AppSpacing.roundedMd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18, color: AppColors.info),
                        AppSpacing.gapH12,
                        Text(
                          DateFormat('EEE, dd MMM yyyy · hh:mm a').format(_minTime),
                          style: AppTypography.labelLarge,
                        ),
                      ],
                    ),
                    const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            AppSpacing.gapV24,

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      LuxuryButton(
                        text: 'Cancel',
                        variant: LuxuryButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      AppSpacing.gapH12,
                      LuxuryButton(
                        text: 'Publish Early Offer',
                        variant: LuxuryButtonVariant.primary,
                        icon: Icons.check_circle_outline,
                        isLoading: _isSubmitting,
                        onPressed: _submit,
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
