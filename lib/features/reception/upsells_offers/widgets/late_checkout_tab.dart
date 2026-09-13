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
import 'create_late_checkout_dialog.dart';

class LateCheckoutTab extends ConsumerWidget {
  const LateCheckoutTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(lateCheckoutOffersProvider);
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
                    Text('Late Check-Out Departure Extensions', style: AppTypography.titleSmall),
                    const SizedBox(height: 2),
                    Text('Active departure extension offers and in-house guest extensions', style: AppTypography.caption),
                    AppSpacing.gapV12,
                    LuxuryButton(
                      text: '+ Create Late Check-Out Offer',
                      variant: LuxuryButtonVariant.primary,
                      height: 38,
                      isExpanded: true,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CreateLateCheckoutDialog(),
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
                        Text('Late Check-Out Departure Extensions', style: AppTypography.titleSmall),
                        const SizedBox(height: 2),
                        Text('Active departure extension offers and in-house guest extensions', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  LuxuryButton(
                    text: '+ Create Late Check-Out Offer',
                    variant: LuxuryButtonVariant.primary,
                    height: 38,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const CreateLateCheckoutDialog(),
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
                        const Icon(Icons.logout_rounded, size: 36, color: AppColors.textMuted),
                        AppSpacing.gapV8,
                        Text('No late check-out offers active', style: AppTypography.bodySmall),
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
                  final name = (offer['offer_name'] ?? 'Late Check-Out').toString();
                  final price = (offer['price_per_hour'] ?? 0).toString();
                  final status = (offer['status'] ?? 'active').toString();
                  final isActive = status == 'active';
                  final guestName = offer['guest_name'];
                  final roomNumber = offer['room_number'];
                  final maxTimeStr = offer['max_time'] != null ? offer['max_time'].toString() : null;
                  final maxTime = maxTimeStr != null ? DateTime.tryParse(maxTimeStr) : null;

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
                                  color: AppColors.purpleLight,
                                  borderRadius: AppSpacing.roundedMd,
                                ),
                                child: const Icon(Icons.logout_rounded, color: AppColors.purple, size: 20),
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
                                        if (roomNumber != null && roomNumber != '—') ...[
                                          AppSpacing.gapH8,
                                          LuxuryBadge(
                                            label: 'Room $roomNumber ($guestName)',
                                            variant: LuxuryBadgeVariant.purple,
                                            isSmall: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                    AppSpacing.gapV4,
                                    Text(
                                      'Rate: ₹$price/hr · ${maxTime != null ? "Latest departure: ${DateFormat('dd MMM yyyy, hh:mm a').format(maxTime.toLocal())}" : "Flexible extension"}',
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
                              activeColor: AppColors.purple,
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
            error: (e, _) => Text('Error loading late check-out offers: $e', style: AppTypography.bodySmall),
          ),

          AppSpacing.gapV24,

          // Accepted Late Check-Out Claims Section
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.purple),
              ),
              AppSpacing.gapH8,
              Text('Guest Late Check-Out Claims & Extended Hours', style: AppTypography.titleSmall),
            ],
          ),
          AppSpacing.gapV12,

          acceptsAsync.when(
            data: (allAccepts) {
              final lateAccepts = allAccepts.where((a) => a['type'] == 'late_out').toList();
              if (lateAccepts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text('No late check-out claims requested yet', style: AppTypography.bodySmall),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lateAccepts.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final accept = lateAccepts[index];
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
                            const Icon(Icons.schedule_rounded, color: AppColors.purple, size: 16),
                            AppSpacing.gapH8,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$guestName ($phone)', style: AppTypography.labelMedium),
                                if (timeSelected != null)
                                  Text(
                                    'Extended Departure: ${DateFormat('dd MMM, hh:mm a').format(timeSelected.toLocal())}',
                                    style: AppTypography.bodySmall,
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Text('Paid: ₹$amount', style: AppTypography.monoSmall.copyWith(color: AppColors.purple)),
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
