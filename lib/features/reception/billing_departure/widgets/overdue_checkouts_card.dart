import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../data/providers/supabase_providers.dart';
import 'instant_checkout_modal.dart';

bool isStayTimedOut(Map<String, dynamic> stay) {
  final outStr = stay['check_out_date']?.toString().split('T')[0];
  if (outStr == null || outStr.isEmpty) return false;
  final outDate = DateTime.tryParse(outStr);
  if (outDate == null) return false;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final outDay = DateTime(outDate.year, outDate.month, outDate.day);

  if (today.isAfter(outDay)) return true;
  if (today.isAtSameMomentAs(outDay)) {
    return now.hour >= 11;
  }
  return false;
}

class OverdueCheckoutsCard extends ConsumerWidget {
  final bool hideIfEmpty;

  const OverdueCheckoutsCard({
    super.key,
    this.hideIfEmpty = true,
  });

  void _showExtendDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> stay) {
    final stayId = (stay['stay_id'] ?? stay['id']).toString();
    final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
    final currentOutStr = stay['check_out_date']?.toString().split('T')[0] ?? '';
    final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'N/A').toString();

    DateTime newDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
          title: Row(
            children: [
              const Icon(Icons.more_time_rounded, color: AppColors.primary),
              AppSpacing.gapH8,
              Text('Extend Stay / Late Checkout', style: AppTypography.titleSmall),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guest: $guestName (Room $roomNum)',
                style: AppTypography.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Current Checkout: $currentOutStr',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('New Checkout Date:', style: AppTypography.labelMedium),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: AppSpacing.roundedMd,
                  side: const BorderSide(color: AppColors.border),
                ),
                title: Text(
                  newDate.toIso8601String().split('T')[0],
                  style: AppTypography.bodyMedium,
                ),
                trailing: const Icon(Icons.calendar_month_outlined, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: newDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setModalState(() => newDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            LuxuryButton(
              text: 'Confirm Extension',
              variant: LuxuryButtonVariant.primary,
              height: 36,
              onPressed: () async {
                try {
                  final inStr = stay['check_in_date']?.toString().split('T')[0] ?? DateTime.now().toIso8601String().split('T')[0];
                  final inDate = DateTime.tryParse(inStr) ?? DateTime.now();

                  await ref.read(stayServiceProvider).updateStayDates(
                    stayId: stayId,
                    checkInDate: inDate,
                    checkOutDate: newDate,
                  );

                  ref.read(receptionRefreshSignalProvider.notifier).state++;
                  if (context.mounted) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('Stay for $guestName extended to ${newDate.toIso8601String().split('T')[0]}'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.departure, content: Text('Failed: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStaysAsync = ref.watch(activeStaysProvider);

    return activeStaysAsync.when(
      data: (stays) {
        final overdueStays = stays.where(isStayTimedOut).toList();

        if (overdueStays.isEmpty) {
          if (hideIfEmpty) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: AppSpacing.roundedMd,
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                AppSpacing.gapH8,
                Text(
                  'No overdue checkouts. All in-house stays are within schedule.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.success),
                ),
              ],
            ),
          );
        }

        final count = overdueStays.length;

        return LuxuryCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderColor: const Color(0xFFF59E0B),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: AppSpacing.roundedMd,
                    ),
                    child: const Icon(
                      Icons.alarm_on_rounded,
                      size: 20,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  AppSpacing.gapH12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Overdue Checkouts (Timed-Out Guests)',
                              style: AppTypography.titleSmall.copyWith(
                                color: const Color(0xFF92400E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            AppSpacing.gapH8,
                            LuxuryBadge(
                              label: '$count OVERDUE',
                              variant: LuxuryBadgeVariant.departure,
                              isSmall: true,
                            ),
                          ],
                        ),
                        Text(
                          'Guests past the 11:00 AM standard checkout without approved extension. Room services paused on guest app.',
                          style: AppTypography.bodySmall.copyWith(color: const Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.gapV16,
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: overdueStays.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final stay = overdueStays[index];
                  final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
                  final phone = (stay['phone_number'] ?? stay['phone'] ?? '').toString();
                  final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'N/A').toString();
                  final outStr = stay['check_out_date']?.toString().split('T')[0] ?? '';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: AppSpacing.roundedMd,
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: AppSpacing.roundedSm,
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            'Room $roomNum',
                            style: AppTypography.monoRoom.copyWith(
                              fontSize: 13,
                              color: const Color(0xFF92400E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        AppSpacing.gapH12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(guestName, style: AppTypography.labelLarge),
                              Text(
                                '$phone • Due: $outStr (11:00 AM)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            LuxuryButton(
                              text: 'Contact',
                              variant: LuxuryButtonVariant.outline,
                              height: 30,
                              icon: Icons.phone_outlined,
                              onPressed: () {
                                if (phone.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: phone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Phone $phone copied to clipboard'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                            LuxuryButton(
                              text: 'Extend',
                              variant: LuxuryButtonVariant.outline,
                              height: 30,
                              icon: Icons.more_time_rounded,
                              onPressed: () => _showExtendDialog(context, ref, stay),
                            ),
                            LuxuryButton(
                              text: 'Checkout',
                              variant: LuxuryButtonVariant.danger,
                              height: 30,
                              icon: Icons.logout_rounded,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => InstantCheckoutModal(stay: stay),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
