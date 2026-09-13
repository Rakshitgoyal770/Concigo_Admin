import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../data/providers/supabase_providers.dart';

class ActiveOffersTab extends ConsumerWidget {
  const ActiveOffersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(activeOffersProvider);

    return offersAsync.when(
      data: (offers) {
        if (offers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 40, color: AppColors.textMuted),
                  AppSpacing.gapV8,
                  Text('No active promotional offers published', style: AppTypography.bodySmall),
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
            final offerId = (offer['offer_id'] ?? offer['id'] ?? '').toString();
            final title = (offer['title'] ?? 'Special Deal').toString();
            final description = (offer['description'] ?? '').toString();
            final discount = offer['discount_value'] ?? offer['discount'] ?? 0;
            final promoCode = (offer['promo_code'] ?? offer['code'] ?? '').toString();

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
                          child: const Icon(Icons.local_offer_outlined, color: AppColors.purple, size: 20),
                        ),
                        AppSpacing.gapH12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppTypography.labelLarge),
                              if (description.isNotEmpty)
                                Text(description, style: AppTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              AppSpacing.gapV4,
                              if (promoCode.isNotEmpty)
                                Text('Code: $promoCode • Value: $discount', style: AppTypography.monoSmall.copyWith(color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      LuxuryBadge(label: 'Active', variant: LuxuryBadgeVariant.success, isSmall: true),
                      AppSpacing.gapH12,
                      IconButton(
                        tooltip: 'Deactivate Offer',
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.departure),
                        onPressed: () async {
                          await ref.read(offerServiceProvider).deleteOffer(offerId);
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
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.departure)),
    );
  }
}
