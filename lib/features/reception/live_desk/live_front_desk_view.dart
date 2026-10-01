import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../billing_departure/widgets/overdue_checkouts_card.dart';
import 'widgets/bellboy_quick_queue.dart';
import 'widgets/front_desk_kpis.dart';
import 'widgets/live_room_matrix.dart';

class LiveFrontDeskView extends ConsumerStatefulWidget {
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
  ConsumerState<LiveFrontDeskView> createState() => _LiveFrontDeskViewState();
}

class _LiveFrontDeskViewState extends ConsumerState<LiveFrontDeskView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _bellboyKey = GlobalKey();

  void _scrollToBellboy() {
    final ctx = _bellboyKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16,
            vertical: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. High-Level 5-Star Operational KPI Ribbon with KYC & Bellboy requests
              FrontDeskKpisSection(
                onArrivalsTap: widget.onNavigateToArrivals,
                onKycTap: widget.onNavigateToArrivals,
                onBillingTap: widget.onNavigateToBilling,
                onBellboyTap: _scrollToBellboy,
              ),
              const SizedBox(height: 10),

              // Overdue Checkouts Warning Card (self-spacing only when active)
              const OverdueCheckoutsCard(hideIfEmpty: true),

              // 2. Main Operational Focus: Live Room Inventory & Status Matrix
              LiveRoomMatrix(
                onWalkInForRoom: widget.onWalkInWithRoom,
              ),
              const SizedBox(height: 12),

              // 3. Bellboy & Luggage Dispatch Queue
              KeyedSubtree(
                key: _bellboyKey,
                child: const BellboyQuickQueue(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
