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
  String? _selectedCategory; // null means 'All Categories'
  final _priceController = TextEditingController(text: '500');
  final _limitController = TextEditingController(text: '10');

  DateTime _minTime = DateTime.now().copyWith(hour: 8, minute: 0, second: 0);
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
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

  Future<void> _submit(List<String> distinctCategories) async {
    final priceStr = _priceController.text.trim();
    final limitStr = _limitController.text.trim();

    final price = double.tryParse(priceStr);
    final limit = int.tryParse(limitStr);

    if (price == null || price <= 0) {
      setState(() => _errorMessage = 'Please provide a valid hourly price (e.g. ₹500).');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final propId = await ref.read(resolvedPropertyIdProvider.future);

      final targetCategories = _selectedCategory != null && _selectedCategory!.isNotEmpty
          ? [_selectedCategory!]
          : distinctCategories;

      if (targetCategories.isEmpty) {
        throw Exception('No room categories found for this property.');
      }

      for (final cat in targetCategories) {
        await SupabaseService.instance.upsertCategoryEarlyLateOffer(
          propertyId: propId,
          type: 'early_in',
          category: cat,
          price: price,
          isActive: true,
          minTime: _minTime,
          limit: limit,
        );
      }

      ref.invalidate(earlyCheckinOffersProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              _selectedCategory != null
                  ? 'Early Check-In pass for "$_selectedCategory" saved at ₹${price.toStringAsFixed(0)}/hr!'
                  : 'Early Check-In pass configured for all ${targetCategories.length} categories at ₹${price.toStringAsFixed(0)}/hr!',
            ),
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
    final roomsAsync = ref.watch(receptionRoomsProvider);
    final rooms = roomsAsync.valueOrNull ?? [];
    final distinctCategories = rooms
        .map((r) => (r['type'] ?? r['room_type'] ?? r['category'] ?? 'Standard').toString())
        .toSet()
        .toList();

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
                            Text('Configure Early Check-In Offer', style: AppTypography.titleMedium.copyWith(fontSize: isMobile ? 16 : 18)),
                            Text('Enable early arrival pass and set pricing per room type', style: AppTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
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

                  // Room Category Dropdown
                  Text('Target Room Category', style: AppTypography.labelMedium),
                  AppSpacing.gapV8,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: AppSpacing.roundedMd,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('🌟 All Room Categories', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          ...distinctCategories.map(
                            (cat) => DropdownMenuItem<String?>(
                              value: cat,
                              child: Text(cat),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        },
                      ),
                    ),
                  ),
                  AppSpacing.gapV16,

                  Row(
                    children: [
                      Expanded(
                        child: LuxuryTextField(
                          label: 'Hourly Rate (₹ / room)',
                          hintText: '500',
                          keyboardType: TextInputType.number,
                          controller: _priceController,
                        ),
                      ),
                      AppSpacing.gapH16,
                      Expanded(
                        child: LuxuryTextField(
                          label: 'Daily Room Quota',
                          hintText: '10',
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
                        text: 'Save & Enable Offer',
                        variant: LuxuryButtonVariant.primary,
                        icon: Icons.check_circle_outline,
                        isLoading: _isSubmitting,
                        onPressed: () => _submit(distinctCategories),
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
