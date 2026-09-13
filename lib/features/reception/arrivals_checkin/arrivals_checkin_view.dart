import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../walk_in/instant_walk_in_dialog.dart';
import 'widgets/create_upcoming_booking_dialog.dart';
import 'widgets/kyc_queue_tab.dart';
import 'widgets/upcoming_arrivals_list.dart';

class ArrivalsCheckinView extends ConsumerStatefulWidget {
  const ArrivalsCheckinView({super.key});

  @override
  ConsumerState<ArrivalsCheckinView> createState() => _ArrivalsCheckinViewState();
}

class _ArrivalsCheckinViewState extends ConsumerState<ArrivalsCheckinView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kycRequestsAsync = ref.watch(checkinRequestsProvider);
    final upcomingAsync = ref.watch(upcomingStaysProvider);

    final pendingKycCount = kycRequestsAsync.value?.where((r) {
      final st = (r['status'] as String? ?? '').toLowerCase();
      return st != 'approved' && st != 'rejected' && st != 'denied';
    }).length ?? 0;

    final upcomingCount = upcomingAsync.value?.length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Header with Instant Walk-In & Upcoming Reservation Actions
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arrivals & Check-In Desk', style: AppTypography.titleLarge.copyWith(fontSize: 20)),
                    AppSpacing.gapV4,
                    Text('Pre-check-in approvals, upcoming bookings & rapid walk-ins', style: AppTypography.bodySmall),
                    AppSpacing.gapV12,
                    Row(
                      children: [
                        Expanded(
                          child: LuxuryButton(
                            text: '+ New Booking',
                            variant: LuxuryButtonVariant.secondary,
                            icon: Icons.calendar_today_rounded,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const CreateUpcomingBookingDialog(),
                              );
                            },
                          ),
                        ),
                        AppSpacing.gapH8,
                        Expanded(
                          child: LuxuryButton(
                            text: '+ Walk-In',
                            variant: LuxuryButtonVariant.primary,
                            icon: Icons.flash_on_rounded,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const InstantWalkInDialog(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Arrivals & Check-In Desk', style: AppTypography.titleLarge),
                          AppSpacing.gapV4,
                          Text('Pre-check-in approvals, guest identity verification & rapid walk-ins', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        LuxuryButton(
                          text: '+ Create Upcoming Reservation',
                          variant: LuxuryButtonVariant.secondary,
                          icon: Icons.calendar_month_rounded,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const CreateUpcomingBookingDialog(),
                            );
                          },
                        ),
                        AppSpacing.gapH12,
                        LuxuryButton(
                          text: '+ Instant Desk Walk-In',
                          variant: LuxuryButtonVariant.primary,
                          icon: Icons.flash_on_rounded,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const InstantWalkInDialog(),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              AppSpacing.gapV20,

              // Luxury Tabs (Upcoming Arrivals vs Pre-Check-In & KYC Queue)
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.roundedSm,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isMobile,
                  tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flight_land_rounded, size: 16),
                          AppSpacing.gapH8,
                          const Text('Upcoming Arrivals & Bookings'),
                          if (upcomingCount > 0) ...[
                            AppSpacing.gapH8,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$upcomingCount',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_outlined, size: 16),
                          AppSpacing.gapH8,
                          const Text('Pre-Check-In & KYC Queue'),
                          if (pendingKycCount > 0) ...[
                            AppSpacing.gapH8,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.attention,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingKycCount',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapV20,

              // Tab Content
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return _tabController.index == 0
                      ? const UpcomingArrivalsList()
                      : const KycQueueTab();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
