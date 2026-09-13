import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../arrivals_checkin/widgets/activate_upcoming_stay_modal.dart';

class TodayArrivalsOverview extends ConsumerWidget {
  final VoidCallback? onViewAllArrivals;

  const TodayArrivalsOverview({
    super.key,
    this.onViewAllArrivals,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingStaysProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.roundedMd,
            border: Border.all(color: AppColors.border, width: 0.8),
            boxShadow: const [AppColors.shadowSm],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Today's Arrivals", style: AppTypography.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          'Pre-booked guests scheduled for check-in today',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (onViewAllArrivals != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onViewAllArrivals,
                      child: Text(
                        'View All →',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ],
              ),
              AppSpacing.gapV16,

              upcomingAsync.when(
                data: (stays) {
                  if (stays.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text('No pending arrivals scheduled for today', style: AppTypography.bodySmall),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stays.take(4).length,
                    separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.borderSubtle),
                    itemBuilder: (context, index) {
                      final stay = stays[index];
                      final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
                      final phone = (stay['phone_number'] ?? stay['phone'] ?? '').toString();
                      final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'Unassigned').toString();
                      final isKycDone = stay['is_kyc_verified'] == true || stay['kyc_status'] == 'APPROVED';

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(guestName, style: AppTypography.labelLarge),
                                LuxuryBadge(
                                  label: isKycDone ? 'KYC Verified' : 'KYC Pending',
                                  variant: isKycDone ? LuxuryBadgeVariant.success : LuxuryBadgeVariant.attention,
                                  isSmall: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('Room $roomNum · Phone: $phone', style: AppTypography.caption),
                            const SizedBox(height: 8),
                            LuxuryButton(
                              text: 'Verify & Check In',
                              variant: LuxuryButtonVariant.primary,
                              height: 32,
                              isExpanded: true,
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('Room $roomNum', style: AppTypography.monoRoom.copyWith(fontSize: 14)),
                              AppSpacing.gapH16,
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(guestName, style: AppTypography.labelLarge),
                                      AppSpacing.gapH8,
                                      LuxuryBadge(
                                        label: isKycDone ? 'KYC Verified' : 'KYC Pending',
                                        variant: isKycDone ? LuxuryBadgeVariant.success : LuxuryBadgeVariant.attention,
                                        isSmall: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Phone: $phone · Online Pre-Booking', style: AppTypography.caption),
                                ],
                              ),
                            ],
                          ),
                          LuxuryButton(
                            text: 'Verify & Check In',
                            variant: LuxuryButtonVariant.primary,
                            height: 32,
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
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
