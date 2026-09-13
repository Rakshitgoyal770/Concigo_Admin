import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../services/supabase_service.dart';
import 'create_early_checkin_dialog.dart';

class EarlyCheckinTab extends ConsumerWidget {
  const EarlyCheckinTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(earlyCheckinOffersProvider);
    final acceptsAsync = ref.watch(earlyLateAcceptsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Early Check-In Hourly Passes', style: AppTypography.titleSmall),
                    const SizedBox(height: 2),
                    Text('Published early arrival slots and rates for guests', style: AppTypography.caption),
                    AppSpacing.gapV12,
                    LuxuryButton(
                      text: '+ Create Early Check-In Offer',
                      variant: LuxuryButtonVariant.primary,
                      height: 38,
                      isExpanded: true,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CreateEarlyCheckinDialog(),
                        );
                      },
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Early Check-In Hourly Passes', style: AppTypography.titleSmall),
                        const SizedBox(height: 2),
                        Text('Published early arrival slots and rates for guests', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  LuxuryButton(
                    text: '+ Create Early Check-In Offer',
                    variant: LuxuryButtonVariant.primary,
                    height: 38,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const CreateEarlyCheckinDialog(),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          AppSpacing.gapV16,

          // Offers List
          offersAsync.when(
            data: (offers) {
              if (offers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.login_rounded, size: 36, color: AppColors.textMuted),
                        AppSpacing.gapV8,
                        Text('No early check-in offers created yet', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  final offerId = (offer['offer_id'] ?? '').toString();
                  final name = (offer['offer_name'] ?? 'Early Check-In').toString();
                  final price = (offer['price_per_hour'] ?? 0).toString();
                  final status = (offer['status'] ?? 'active').toString();
                  final isActive = status == 'active';
                  final limitVal = offer['limit'];
                  final minTimeStr = offer['min_time'] != null ? offer['min_time'].toString() : null;
                  final minTime = minTimeStr != null ? DateTime.tryParse(minTimeStr) : null;

                  return LuxuryCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.infoLight,
                                  borderRadius: AppSpacing.roundedMd,
                                ),
                                child: const Icon(Icons.login_rounded, color: AppColors.info, size: 20),
                              ),
                              AppSpacing.gapH12,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(name, style: AppTypography.labelLarge),
                                        AppSpacing.gapH8,
                                        LuxuryBadge(
                                          label: isActive ? 'Active' : 'Disabled',
                                          variant: isActive ? LuxuryBadgeVariant.success : LuxuryBadgeVariant.neutral,
                                          isSmall: true,
                                        ),
                                        if (limitVal != null) ...[
                                          AppSpacing.gapH8,
                                          LuxuryBadge(
                                            label: 'Limit: $limitVal rooms',
                                            variant: LuxuryBadgeVariant.info,
                                            isSmall: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                    AppSpacing.gapV4,
                                    Text(
                                      'Rate: ₹$price/hr · ${minTime != null ? "Earliest: ${DateFormat('dd MMM yyyy, hh:mm a').format(minTime.toLocal())}" : "Anytime before standard check-in"}',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Switch.adaptive(
                              value: isActive,
                              activeColor: AppColors.primary,
                              onChanged: (val) async {
                                final newStatus = val ? 'active' : 'disabled';
                                await SupabaseService.instance.toggleEarlyLateOfferStatus(offerId, newStatus);
                                ref.read(receptionRefreshSignalProvider.notifier).state++;
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (e, _) => Text('Error loading early check-in offers: $e', style: AppTypography.bodySmall),
          ),

          AppSpacing.gapV24,

          // Accepted Early Check-In Claims Section
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
              ),
              AppSpacing.gapH8,
              Text('Guest Early Check-In Claims & Payments', style: AppTypography.titleSmall),
            ],
          ),
          AppSpacing.gapV12,

          acceptsAsync.when(
            data: (allAccepts) {
              final earlyAccepts = allAccepts.where((a) => a['type'] == 'early_in').toList();
              if (earlyAccepts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text('No early check-in requests claimed yet', style: AppTypography.bodySmall),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: earlyAccepts.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final accept = earlyAccepts[index];
                  final user = accept['users'] as Map<String, dynamic>?;
                  final guestName = user?['name'] ?? 'Guest';
                  final phone = user?['mobile_no'] ?? '';
                  final amount = accept['amount_paid'] ?? 0;
                  final timeSelectedStr = accept['time_selected']?.toString();
                  final timeSelected = timeSelectedStr != null ? DateTime.tryParse(timeSelectedStr) : null;

                  return LuxuryCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                            AppSpacing.gapH8,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$guestName ($phone)', style: AppTypography.labelMedium),
                                if (timeSelected != null)
                                  Text(
                                    'Requested Arrival: ${DateFormat('dd MMM, hh:mm a').format(timeSelected.toLocal())}',
                                    style: AppTypography.bodySmall,
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Text('Paid: ₹$amount', style: AppTypography.monoSmall.copyWith(color: AppColors.primary)),
                      ],
                    ),
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
  }
}
