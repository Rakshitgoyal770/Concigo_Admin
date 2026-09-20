import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../billing_departure/widgets/overdue_checkouts_card.dart';
import 'widgets/bellboy_quick_queue.dart';
import 'widgets/front_desk_kpis.dart';
import 'widgets/live_room_matrix.dart';

class LiveFrontDeskView extends ConsumerWidget {
  final VoidCallback? onNavigateToArrivals;
  final VoidCallback? onNavigateToUpsells;
  final VoidCallback? onNavigateToBilling;
  final Function(Map<String, dynamic> room)? onWalkInWithRoom;

  const LiveFrontDeskView({
    super.key,
    this.onNavigateToArrivals,
    this.onNavigateToUpsells,
    this.onNavigateToBilling,
    this.onWalkInWithRoom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. High-Level 5-Star Operational KPI Ribbon
              FrontDeskKpisSection(
                onArrivalsTap: onNavigateToArrivals,
                onKycTap: onNavigateToArrivals,
                onBillingTap: onNavigateToBilling,
              ),
              AppSpacing.gapV24,

              // Overdue Checkouts Warning Card (if any guest is past 11:00 AM checkout)
              const OverdueCheckoutsCard(hideIfEmpty: true),
              AppSpacing.gapV24,

              // 2. Main Operational Focus: Live Room Inventory & Status Matrix
              LiveRoomMatrix(
                onWalkInForRoom: onWalkInWithRoom,
              ),
              AppSpacing.gapV24,

              // 3. Bellboy & Luggage Dispatch Queue
              const BellboyQuickQueue(),
              AppSpacing.gapV32,
            ],
          ),
        );
      },
    );
  }
}
