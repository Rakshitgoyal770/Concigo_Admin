import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../billing_departure/widgets/instant_checkout_modal.dart';

class InHouseGuestsOverview extends ConsumerWidget {
  final VoidCallback? onViewAllInHouse;

  const InHouseGuestsOverview({
    super.key,
    this.onViewAllInHouse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStaysAsync = ref.watch(activeStaysProvider);

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
                        Text('In-House Guests', style: AppTypography.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          'Currently checked-in active hotel residents',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (onViewAllInHouse != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onViewAllInHouse,
                      child: Text(
                        'View All →',
                        style: AppTypography.labelSmall.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ],
              ),
              AppSpacing.gapV16,

              activeStaysAsync.when(
                data: (stays) {
                  if (stays.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text('No active in-house guests currently', style: AppTypography.bodySmall),
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
                      final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'N/A').toString();

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(guestName, style: AppTypography.labelLarge),
                                const LuxuryBadge(
                                  label: 'In-House',
                                  variant: LuxuryBadgeVariant.primary,
                                  isSmall: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text('Room $roomNum · Phone: $phone', style: AppTypography.caption),
                            const SizedBox(height: 8),
                            LuxuryButton(
                              text: 'Folio & Checkout',
                              variant: LuxuryButtonVariant.secondary,
                              height: 32,
                              isExpanded: true,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => InstantCheckoutModal(stay: stay),
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
                                      const LuxuryBadge(
                                        label: 'In-House',
                                        variant: LuxuryBadgeVariant.primary,
                                        isSmall: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Phone: $phone · Active Stay', style: AppTypography.caption),
                                ],
                              ),
                            ],
                          ),
                          LuxuryButton(
                            text: 'Folio & Checkout',
                            variant: LuxuryButtonVariant.secondary,
                            height: 32,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => InstantCheckoutModal(stay: stay),
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
