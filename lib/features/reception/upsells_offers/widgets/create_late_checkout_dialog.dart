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

class CreateLateCheckoutDialog extends ConsumerStatefulWidget {
  final String? initialStayId;
  const CreateLateCheckoutDialog({super.key, this.initialStayId});

  @override
  ConsumerState<CreateLateCheckoutDialog> createState() => _CreateLateCheckoutDialogState();
}

class _CreateLateCheckoutDialogState extends ConsumerState<CreateLateCheckoutDialog> {
  final _nameController = TextEditingController(text: 'Late Departure Privilege');
  final _priceController = TextEditingController(text: '400');

  String? _selectedStayId;
  DateTime _maxTime = DateTime.now().copyWith(hour: 18, minute: 0, second: 0);
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedStayId = widget.initialStayId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickMaxTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _maxTime,
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
      initialTime: TimeOfDay(hour: _maxTime.hour, minute: _maxTime.minute),
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
      _maxTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final price = double.tryParse(priceStr);

    if (name.isEmpty || price == null || price <= 0) {
      setState(() => _errorMessage = 'Please provide valid offer name and hourly price.');
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
        stayId: _selectedStayId,
        maxTime: _maxTime,
        type: 'late_out',
        pricePerHour: price,
      );

      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Late Check-Out Offer "$name" created at ₹${price.toStringAsFixed(0)}/hr!'),
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
    final activeStaysAsync = ref.watch(activeStaysProvider);

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
                          color: AppColors.purpleLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.logout_rounded, color: AppColors.purple, size: 18),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create Late Check-Out Offer', style: AppTypography.titleMedium.copyWith(fontSize: isMobile ? 16 : 18)),
                            Text('Enable in-house guests to extend their departure time', style: AppTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
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
                    hintText: 'e.g. Late Departure Privilege',
                    controller: _nameController,
                  ),
                  AppSpacing.gapV16,

                  activeStaysAsync.when(
                    data: (stays) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Target In-House Guest / Room', style: AppTypography.labelMedium),
                          AppSpacing.gapV8,
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedStayId,
                                isExpanded: true,
                                hint: const Text('All In-House Guests (Property-wide)'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('🌟 Property-Wide Offer (All Active Guests)'),
                                  ),
                                  ...stays.map((stay) {
                                    final id = (stay['stay_id'] ?? '').toString();
                                    final name = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
                                    final room = (stay['room_number'] ?? stay['room_no'] ?? '').toString();
                                    return DropdownMenuItem<String?>(
                                      value: id,
                                      child: Text('Room $room · $name'),
                                    );
                                  }),
                                ],
                                onChanged: (val) => setState(() => _selectedStayId = val),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  AppSpacing.gapV16,

                  LuxuryTextField(
                    label: 'Price Per Hour (₹)',
                    hintText: '400',
                    keyboardType: TextInputType.number,
                    controller: _priceController,
                  ),
                  AppSpacing.gapV16,

                  Text('Latest Allowed Departure Time', style: AppTypography.labelMedium),
                  AppSpacing.gapV8,
                  InkWell(
                    onTap: _pickMaxTime,
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
                              const Icon(Icons.access_time_rounded, size: 18, color: AppColors.purple),
                              AppSpacing.gapH12,
                              Text(
                                DateFormat('EEE, dd MMM yyyy · hh:mm a').format(_maxTime),
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
                        text: 'Publish Late Offer',
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
