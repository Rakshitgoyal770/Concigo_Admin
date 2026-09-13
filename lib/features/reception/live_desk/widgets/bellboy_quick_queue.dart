import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../data/providers/supabase_providers.dart';

class BellboyQuickQueue extends ConsumerWidget {
  const BellboyQuickQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(bellboyQueueProvider);

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
                        Text('Luggage & Porter Dispatch', style: AppTypography.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          'Active luggage transfer and porter assistance requests',
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 8),
                    const LuxuryBadge(
                      label: 'Live Dispatch',
                      variant: LuxuryBadgeVariant.purple,
                      isSmall: true,
                    ),
                  ],
                ],
              ),
              AppSpacing.gapV16,

              queueAsync.when(
                data: (requests) {
                  if (requests.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text('No luggage transfers active in queue', style: AppTypography.bodySmall),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: requests.take(5).length,
                    separatorBuilder: (_, __) => const Divider(height: 16, color: AppColors.borderSubtle),
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final reqId = (req['request_id'] ?? req['id'] ?? '').toString();
                      final roomNum = (req['room_number'] ?? req['room_no'] ?? 'N/A').toString();
                      final guestName = (req['guest_name'] ?? 'Guest').toString();
                      final bagsCount = req['bags_count'] ?? 1;
                      final status = (req['status'] as String? ?? 'pending').toLowerCase();

                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Room $roomNum', style: AppTypography.monoRoom.copyWith(fontSize: 13)),
                                AppSpacing.gapH8,
                                Expanded(child: Text(guestName, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            AppSpacing.gapV4,
                            Text('$bagsCount Bags · Status: ${status.toUpperCase()}', style: AppTypography.caption),
                            AppSpacing.gapV8,
                            if (status == 'pending' || status == 'requested' || status == 'called')
                              LuxuryButton(
                                text: 'Assign Porter',
                                variant: LuxuryButtonVariant.secondary,
                                height: 32,
                                isExpanded: true,
                                onPressed: () async {
                                  await ref.read(bellboyServiceProvider).updateLuggageStatus(
                                    requestId: reqId,
                                    status: 'reached',
                                  );
                                  ref.read(receptionRefreshSignalProvider.notifier).state++;
                                },
                              )
                            else if (status == 'in_progress' || status == 'reached')
                              LuxuryButton(
                                text: 'Mark Delivered',
                                variant: LuxuryButtonVariant.primary,
                                height: 32,
                                isExpanded: true,
                                onPressed: () async {
                                  await ref.read(bellboyServiceProvider).updateLuggageStatus(
                                    requestId: reqId,
                                    status: 'completed',
                                  );
                                  ref.read(receptionRefreshSignalProvider.notifier).state++;
                                },
                              )
                            else
                              const LuxuryBadge(label: 'Delivered', variant: LuxuryBadgeVariant.success, isSmall: true),
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
                                  Text(guestName, style: AppTypography.labelLarge),
                                  const SizedBox(height: 2),
                                  Text('$bagsCount Bags · Status: ${status.toUpperCase()}', style: AppTypography.caption),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              if (status == 'pending' || status == 'requested' || status == 'called')
                                LuxuryButton(
                                  text: 'Assign Porter',
                                  variant: LuxuryButtonVariant.secondary,
                                  height: 32,
                                  onPressed: () async {
                                    await ref.read(bellboyServiceProvider).updateLuggageStatus(
                                      requestId: reqId,
                                      status: 'reached',
                                    );
                                    ref.read(receptionRefreshSignalProvider.notifier).state++;
                                  },
                                )
                              else if (status == 'in_progress' || status == 'reached')
                                LuxuryButton(
                                  text: 'Mark Delivered',
                                  variant: LuxuryButtonVariant.primary,
                                  height: 32,
                                  onPressed: () async {
                                    await ref.read(bellboyServiceProvider).updateLuggageStatus(
                                      requestId: reqId,
                                      status: 'completed',
                                    );
                                    ref.read(receptionRefreshSignalProvider.notifier).state++;
                                  },
                                )
                              else
                                const LuxuryBadge(label: 'Delivered', variant: LuxuryBadgeVariant.success, isSmall: true),
                            ],
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
