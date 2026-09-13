import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../arrivals_checkin/widgets/kyc_inspector_modal.dart';
import '../../arrivals_checkin/widgets/activate_upcoming_stay_modal.dart';
import '../../billing_departure/widgets/instant_checkout_modal.dart';

class AttentionRequiredSection extends ConsumerWidget {
  final VoidCallback? onNavigateToArrivals;
  final VoidCallback? onNavigateToBilling;

  const AttentionRequiredSection({
    super.key,
    this.onNavigateToArrivals,
    this.onNavigateToBilling,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycRequestsAsync = ref.watch(checkinRequestsProvider);
    final upcomingAsync = ref.watch(upcomingStaysProvider);
    final bellboyAsync = ref.watch(bellboyQueueProvider);
    final activeStaysAsync = ref.watch(activeStaysProvider);

    return kycRequestsAsync.when(
      data: (requests) {
        final pendingKyc = requests.where((r) {
          final s = (r['status'] ?? '').toString().toUpperCase();
          return s == 'PENDING' || s == 'SUBMITTED' || s == 'REQUESTED';
        }).toList();

        final upcomingList = upcomingAsync.value ?? [];
        final luggageList = bellboyAsync.value ?? [];
        final activeStays = activeStaysAsync.value ?? [];

        // Aggregate urgent operational items
        final List<_OperationalItem> items = [];

        // 1. Pending KYC items
        for (final kyc in pendingKyc.take(3)) {
          final guestName = (kyc['user_name'] ?? kyc['guest_name'] ?? 'Guest').toString();
          final room = (kyc['room_number'] ?? kyc['room_no'] ?? 'Unassigned').toString();
          final phone = (kyc['mobile_no'] ?? kyc['phone'] ?? '').toString();

          items.add(
            _OperationalItem(
              title: guestName,
              subtitle: 'Room $room · KYC Documents Pending Review · $phone',
              tag: 'KYC Required',
              tagVariant: LuxuryBadgeVariant.attention,
              actionText: 'Review Documents',
              actionVariant: LuxuryButtonVariant.primary,
              onAction: () {
                showDialog(
                  context: context,
                  builder: (_) => KycInspectorModal(checkinRequest: kyc),
                );
              },
            ),
          );
        }

        // 2. Pending Luggage Requests
        for (final lug in luggageList.where((l) => l['status'] != 'completed').take(2)) {
          final guest = (lug['guest_name'] ?? lug['user_name'] ?? 'Guest').toString();
          final room = (lug['room_number'] ?? '').toString();
          final bags = lug['bags_count'] ?? lug['bag_count'] ?? 1;

          items.add(
            _OperationalItem(
              title: guest,
              subtitle: 'Room $room · Luggage Porter Call ($bags bags)',
              tag: 'Porter Call',
              tagVariant: LuxuryBadgeVariant.purple,
              actionText: 'Assign Porter',
              actionVariant: LuxuryButtonVariant.secondary,
              onAction: () {
                // Porter quick acknowledgement
                ref.read(receptionRefreshSignalProvider.notifier).state++;
              },
            ),
          );
        }

        // 3. Today Arrivals awaiting desk check-in
        for (final stay in upcomingList.take(2)) {
          final guest = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
          final room = (stay['room_number'] ?? stay['room_no'] ?? 'Unassigned').toString();

          items.add(
            _OperationalItem(
              title: guest,
              subtitle: 'Room $room · Scheduled Arrival · Online Pre-Booking',
              tag: 'Arrival Ready',
              tagVariant: LuxuryBadgeVariant.info,
              actionText: 'Verify & Check In',
              actionVariant: LuxuryButtonVariant.primary,
              onAction: () {
                showDialog(
                  context: context,
                  builder: (_) => ActivateUpcomingStayModal(stay: stay),
                );
              },
            ),
          );
        }

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.roundedMd,
            border: Border.all(color: AppColors.border, width: 0.8),
            boxShadow: const [AppColors.shadowSm],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 18, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attention Required', style: AppTypography.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            'Priority operational items requiring desk action',
                            style: AppTypography.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    LuxuryBadge(
                      label: '${items.length} ${items.length == 1 ? "Pending Action" : "Pending Actions"}',
                      variant: LuxuryBadgeVariant.attention,
                      isSmall: true,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),

              // Operational Rows
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
                itemBuilder: (context, index) {
                  final item = items[index];

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(item.title, style: AppTypography.labelLarge),
                                      LuxuryBadge(label: item.tag, variant: item.tagVariant, isSmall: true),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(item.subtitle, style: AppTypography.bodySmall),
                                  const SizedBox(height: 10),
                                  LuxuryButton(
                                    text: item.actionText,
                                    variant: item.actionVariant,
                                    isExpanded: true,
                                    height: 36,
                                    onPressed: item.onAction,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(item.title, style: AppTypography.labelLarge),
                                            AppSpacing.gapH12,
                                            LuxuryBadge(label: item.tag, variant: item.tagVariant, isSmall: true),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(item.subtitle, style: AppTypography.bodySmall),
                                      ],
                                    ),
                                  ),
                                  AppSpacing.gapH16,
                                  LuxuryButton(
                                    text: item.actionText,
                                    variant: item.actionVariant,
                                    height: 36,
                                    onPressed: item.onAction,
                                  ),
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

class _OperationalItem {
  final String title;
  final String subtitle;
  final String tag;
  final LuxuryBadgeVariant tagVariant;
  final String actionText;
  final LuxuryButtonVariant actionVariant;
  final VoidCallback onAction;

  _OperationalItem({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagVariant,
    required this.actionText,
    required this.actionVariant,
    required this.onAction,
  });
}
