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
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16,
            vertical: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. High-Level 5-Star Operational KPI Ribbon
              FrontDeskKpisSection(
                onArrivalsTap: onNavigateToArrivals,
                onKycTap: onNavigateToArrivals,
                onBillingTap: onNavigateToBilling,
              ),
              const SizedBox(height: 10),

              // Overdue Checkouts Warning Card (self-spacing only when active)
              const OverdueCheckoutsCard(hideIfEmpty: true),

              // 2. Main Operational Focus: Live Room Inventory & Status Matrix
              LiveRoomMatrix(
                onWalkInForRoom: onWalkInWithRoom,
              ),
              const SizedBox(height: 12),

              // 3. Bellboy & Luggage Dispatch Queue
              const BellboyQuickQueue(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
