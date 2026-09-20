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

/// Calculates the exact departure DateTime taking into account:
/// 1. early_late_offer_accepts (redeemed Late Checkout Pass, e.g. '16:00:00' / 04:00 PM)
/// 2. stay.check_out_time (e.g. '14:00:00' from a late pass)
/// 3. hotel_property.checkout_time (e.g. '12:00:00' or '11:00:00')
/// 4. ISO timestamp inside check_out_date
DateTime? getStayDepartureDateTime(Map<String, dynamic> stay) {
  final outStr = stay['check_out_date']?.toString();
  if (outStr == null || outStr.isEmpty) return null;

  final datePart = outStr.split('T')[0];
  final date = DateTime.tryParse(datePart);
  if (date == null) return null;

  // 1. Check if there is an accepted late_out pass in early_late_offer_accepts
  final accepts = stay['early_late_offer_accepts'] as List?;
  if (accepts != null && accepts.isNotEmpty) {
    final latePasses = accepts.where((a) {
      final m = a as Map<String, dynamic>?;
      return m?['type'] == 'late_out' && m?['time_selected'] != null;
    }).toList();

    if (latePasses.isNotEmpty) {
      final lastLate = latePasses.last as Map<String, dynamic>;
      final timeSelected = lastLate['time_selected']?.toString();
      if (timeSelected != null && timeSelected.isNotEmpty) {
        final parsedTime = DateTime.tryParse(timeSelected);
        if (parsedTime != null) {
          return DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);
        }
      }
    }
  }

  // 2. If check_out_date contains full time component
  if (outStr.contains('T') && !outStr.endsWith('T00:00:00.000') && !outStr.endsWith('T00:00:00')) {
    final parsed = DateTime.tryParse(outStr);
    if (parsed != null && (parsed.hour != 0 || parsed.minute != 0)) {
      return parsed;
    }
  }

  // 3. Fallback to stay.check_out_time or hotel default checkout_time
  final timeStr = stay['check_out_time']?.toString() ??
      stay['hotel_property']?['checkout_time']?.toString() ??
      stay['hotel']?['checkout_time']?.toString() ??
      '11:00:00';

  int hour = 11;
  int minute = 0;
  try {
    final parts = timeStr.split(':');
    if (parts.isNotEmpty) hour = int.tryParse(parts[0]) ?? 11;
    if (parts.length > 1) minute = int.tryParse(parts[1]) ?? 0;
  } catch (_) {}

  return DateTime(date.year, date.month, date.day, hour, minute);
}

bool isStayTimedOut(Map<String, dynamic> stay) {
  final departureMoment = getStayDepartureDateTime(stay);
  if (departureMoment == null) return false;
  return DateTime.now().isAfter(departureMoment);
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Overdue Checkouts (Timed-Out Guests)',
                              style: AppTypography.titleSmall.copyWith(
                                color: const Color(0xFF92400E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            LuxuryBadge(
                              label: '$count OVERDUE',
                              variant: LuxuryBadgeVariant.departure,
                              isSmall: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Guests past standard checkout without approved extension. Room services paused on guest app.',
                          style: AppTypography.bodySmall.copyWith(color: const Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.gapV16,
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 620;

                  return ListView.separated(
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

                      final departureMoment = getStayDepartureDateTime(stay);
                      String timeLabel = '11:00 AM';
                      if (departureMoment != null) {
                        final h = departureMoment.hour % 12 == 0 ? 12 : departureMoment.hour % 12;
                        final m = departureMoment.minute.toString().padLeft(2, '0');
                        final p = departureMoment.hour >= 12 ? 'PM' : 'AM';
                        timeLabel = '$h:$m $p';
                      }

                      final roomBadge = Container(
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
                      );

                      final guestInfo = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guestName,
                            style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$phone • Due: $outStr ($timeLabel)',
                            style: AppTypography.bodySmall.copyWith(
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      );

                      final actionButtons = Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          LuxuryButton(
                            text: 'Contact',
                            variant: LuxuryButtonVariant.outline,
                            height: 32,
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
                            height: 32,
                            icon: Icons.more_time_rounded,
                            onPressed: () => _showExtendDialog(context, ref, stay),
                          ),
                          LuxuryButton(
                            text: 'Checkout',
                            variant: LuxuryButtonVariant.danger,
                            height: 32,
                            icon: Icons.logout_rounded,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => InstantCheckoutModal(stay: stay),
                              );
                            },
                          ),
                        ],
                      );

                      if (isCompact) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: AppSpacing.roundedMd,
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  roomBadge,
                                  AppSpacing.gapH12,
                                  Expanded(child: guestInfo),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, thickness: 0.8, color: Color(0xFFFDE68A)),
                              const SizedBox(height: 10),
                              actionButtons,
                            ],
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: AppSpacing.roundedMd,
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            roomBadge,
                            AppSpacing.gapH12,
                            Expanded(child: guestInfo),
                            AppSpacing.gapH12,
                            actionButtons,
                          ],
                        ),
                      );
                    },
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
