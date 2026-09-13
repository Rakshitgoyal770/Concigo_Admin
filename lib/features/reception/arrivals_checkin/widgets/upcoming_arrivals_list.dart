import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import 'activate_upcoming_stay_modal.dart';
import 'create_upcoming_booking_dialog.dart';

class UpcomingArrivalsList extends ConsumerWidget {
  const UpcomingArrivalsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingStaysProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return LuxuryCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: AppSpacing.roundedMd,
                    ),
                    child: const Icon(Icons.flight_land_rounded, size: 18, color: AppColors.info),
                  ),
                  AppSpacing.gapH12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upcoming Arrivals & Bookings', style: AppTypography.titleSmall),
                        Text('Scheduled arrivals with pre-bookings & app check-ins', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  if (!isMobile)
                    LuxuryButton(
                      text: '+ New Booking',
                      variant: LuxuryButtonVariant.outline,
                      icon: Icons.add_circle_outline_rounded,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CreateUpcomingBookingDialog(),
                        );
                      },
                    ),
                ],
              ),
              if (isMobile) ...[
                AppSpacing.gapV12,
                LuxuryButton(
                  text: '+ New Booking',
                  variant: LuxuryButtonVariant.outline,
                  icon: Icons.add_circle_outline_rounded,
                  isExpanded: true,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const CreateUpcomingBookingDialog(),
                    );
                  },
                ),
              ],
              AppSpacing.gapV16,
              upcomingAsync.when(
                data: (stays) {
                  if (stays.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.event_available_outlined, size: 40, color: AppColors.textMuted),
                            AppSpacing.gapV8,
                            Text('No pending scheduled arrivals for today', style: AppTypography.titleSmall),
                            AppSpacing.gapV4,
                            Text('Create a scheduled reservation or walk-in above.', style: AppTypography.bodySmall),
                            AppSpacing.gapV12,
                            LuxuryButton(
                              text: '+ Create Upcoming Reservation',
                              variant: LuxuryButtonVariant.secondary,
                              icon: Icons.calendar_month_rounded,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const CreateUpcomingBookingDialog(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stays.length,
                    separatorBuilder: (_, __) => AppSpacing.gapV12,
                    itemBuilder: (context, index) {
                      final stay = stays[index];
                      final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
                      final phone = (stay['phone_number'] ?? stay['phone'] ?? stay['mobile_no'] ?? '').toString();
                      final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'Unassigned').toString();
                      final isKycDone = stay['is_kyc_verified'] == true || stay['kyc_status'] == 'APPROVED';

                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppSpacing.roundedMd,
                          border: Border.all(
                            color: isKycDone ? AppColors.successBorder.withValues(alpha: 0.4) : AppColors.border,
                          ),
                          boxShadow: const [AppColors.shadowSm],
                        ),
                        child: LayoutBuilder(
                          builder: (context, rowConstraints) {
                            final isRowNarrow = rowConstraints.maxWidth < 560;

                            if (isRowNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceSubtle,
                                          borderRadius: AppSpacing.roundedSm,
                                        ),
                                        child: Text(
                                          'Room $roomNum',
                                          style: AppTypography.monoRoom.copyWith(fontSize: 12),
                                        ),
                                      ),
                                      LuxuryBadge(
                                        label: isKycDone ? 'KYC Done' : 'KYC Pending',
                                        variant: isKycDone ? LuxuryBadgeVariant.success : LuxuryBadgeVariant.attention,
                                        isSmall: true,
                                      ),
                                    ],
                                  ),
                                  AppSpacing.gapV8,
                                  Text(
                                    guestName,
                                    style: AppTypography.labelLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  AppSpacing.gapV4,
                                  Text(
                                    '$phone • Online Booking',
                                    style: AppTypography.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  AppSpacing.gapV12,
                                  LuxuryButton(
                                    text: 'Activate Check-In',
                                    variant: LuxuryButtonVariant.primary,
                                    isExpanded: true,
                                    height: 34,
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => ActivateUpcomingStayModal(stay: stay),
                                      );
                                    },
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: AppSpacing.roundedSm,
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Room $roomNum',
                                    style: AppTypography.monoRoom.copyWith(fontSize: 13),
                                  ),
                                ),
                                AppSpacing.gapH12,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        guestName,
                                        style: AppTypography.labelLarge,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      AppSpacing.gapV4,
                                      Text(
                                        '$phone • Online Booking',
                                        style: AppTypography.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                AppSpacing.gapH12,
                                LuxuryBadge(
                                  label: isKycDone ? 'KYC Verified' : 'KYC Pending',
                                  variant: isKycDone ? LuxuryBadgeVariant.success : LuxuryBadgeVariant.attention,
                                  isSmall: true,
                                ),
                                AppSpacing.gapH12,
                                LuxuryButton(
                                  text: 'Activate Check-In',
                                  variant: LuxuryButtonVariant.primary,
                                  height: 34,
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => ActivateUpcomingStayModal(stay: stay),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Text('Failed to load arrivals: $err', style: const TextStyle(color: AppColors.departure)),
              ),
            ],
          ),
        );
      },
    );
  }
}
