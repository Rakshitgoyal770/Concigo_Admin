import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../data/providers/supabase_providers.dart';

class RoomUpgradesTab extends ConsumerWidget {
  const RoomUpgradesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upgradesAsync = ref.watch(roomUpgradesProvider);

    return upgradesAsync.when(
      data: (upgrades) {
        if (upgrades.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.upgrade_outlined, size: 40, color: AppColors.textMuted),
                  AppSpacing.gapV8,
                  Text('No active room upgrade requests', style: AppTypography.bodySmall),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: upgrades.length,
          separatorBuilder: (_, __) => const Divider(height: 16),
          itemBuilder: (context, index) {
            final up = upgrades[index];
            final upId = (up['upgrade_id'] ?? up['id'] ?? '').toString();
            final roomNum = (up['current_room'] ?? up['room_number'] ?? 'N/A').toString();
            final targetCategory = (up['target_category'] ?? up['target_room_type'] ?? 'Deluxe Suite').toString();
            final diffPrice = up['differential_price'] ?? up['price'] ?? 1200;
            final status = (up['status'] as String? ?? 'pending').toLowerCase();

            return LuxuryCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upgrade to $targetCategory', style: AppTypography.labelLarge),
                          Text('Upgrade Differential: ₹$diffPrice / night', style: AppTypography.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      LuxuryBadge(
                        label: status.toUpperCase(),
                        variant: status == 'approved' ? LuxuryBadgeVariant.success : LuxuryBadgeVariant.attention,
                        isSmall: true,
                      ),
                      AppSpacing.gapH12,
                      if (status == 'pending' || status == 'requested')
                        LuxuryButton(
                          text: 'Approve & Charge',
                          variant: LuxuryButtonVariant.success,
                          height: 32,
                          onPressed: () async {
                            await ref.read(offerServiceProvider).updateRoomUpgradeStatus(
                              upgradeId: upId,
                              status: 'approved',
                            );
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
