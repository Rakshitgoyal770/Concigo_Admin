import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import 'widgets/folio_billing_sheet.dart';
import 'widgets/instant_checkout_modal.dart';
import 'widgets/overdue_checkouts_card.dart';

class BillingDepartureView extends ConsumerWidget {
  const BillingDepartureView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStaysAsync = ref.watch(activeStaysProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Billing & Guest Departure Hub', style: AppTypography.titleLarge.copyWith(fontSize: isMobile ? 20 : 24)),
                  AppSpacing.gapV4,
                  Text('Active guest folios, incidental charges, payment settlement & departures', style: AppTypography.bodySmall),
                ],
              ),
              AppSpacing.gapV24,

              // Overdue Checkouts Window
              const OverdueCheckoutsCard(hideIfEmpty: false),
              AppSpacing.gapV24,

              LuxuryCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: AppSpacing.roundedMd,
                          ),
                          child: const Icon(Icons.hotel_class_rounded, size: 18, color: AppColors.primary),
                        ),
                        AppSpacing.gapH12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active In-House Stays & Folios', style: AppTypography.titleSmall),
                              Text('Currently checked-in hotel guests', style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        if (!isMobile)
                          const LuxuryBadge(label: 'In-House', variant: LuxuryBadgeVariant.primary, isSmall: true),
                      ],
                    ),
                    AppSpacing.gapV16,
                    activeStaysAsync.when(
                      data: (stays) {
                        if (stays.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36.0),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.king_bed_outlined, size: 40, color: AppColors.textMuted),
                                  AppSpacing.gapV8,
                                  Text('No active in-house stays found', style: AppTypography.bodySmall),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: stays.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final stay = stays[index];
                            final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
                            final phone = (stay['phone_number'] ?? stay['phone'] ?? '').toString();
                            final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'N/A').toString();
                            final tariff = stay['total_amount'] ?? stay['tariff'] ?? 2500;

                            if (isMobile) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: AppSpacing.roundedSm,
                                        ),
                                        child: Text(
                                          roomNum.contains(',') ? 'Rooms $roomNum' : 'Room $roomNum',
                                          style: AppTypography.monoRoom.copyWith(fontSize: 12),
                                        ),
                                      ),
                                      Text(guestName, style: AppTypography.labelLarge),
                                    ],
                                  ),
                                  AppSpacing.gapV4,
                                  Text('$phone • Tariff: ₹$tariff', style: AppTypography.bodySmall),
                                  AppSpacing.gapV8,
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      LuxuryButton(
                                        text: 'Folio & Charges',
                                        variant: LuxuryButtonVariant.outline,
                                        height: 34,
                                        icon: Icons.receipt_long_outlined,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => FolioBillingSheet(stay: stay),
                                          );
                                        },
                                      ),
                                      LuxuryButton(
                                        text: 'Checkout',
                                        variant: LuxuryButtonVariant.danger,
                                        height: 34,
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
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: AppSpacing.roundedSm,
                                        ),
                                        child: Text('Room $roomNum', style: AppTypography.monoRoom.copyWith(fontSize: 13)),
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
                                              maxLines: 1,
                                            ),
                                            Text(
                                              '$phone • Tariff: ₹$tariff',
                                              style: AppTypography.bodySmall,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LuxuryButton(
                                      text: 'Folio & Charges',
                                      variant: LuxuryButtonVariant.outline,
                                      height: 32,
                                      icon: Icons.receipt_long_outlined,
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => FolioBillingSheet(stay: stay),
                                        );
                                      },
                                    ),
                                    AppSpacing.gapH8,
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
                                ),
                              ],
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
                      error: (err, _) => Text('Failed to load in-house stays: $err', style: TextStyle(color: AppColors.departure)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
