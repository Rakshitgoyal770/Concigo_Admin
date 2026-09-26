import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../routes/app_routes.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/pms/pms_sync_service.dart';
import '../../../../services/pms/apaleo_service.dart';
import '../live_desk/live_front_desk_view.dart';
import '../arrivals_checkin/arrivals_checkin_view.dart';
import '../upsells_offers/upsells_offers_view.dart';
import '../billing_departure/billing_departure_view.dart';
import '../walk_in/instant_walk_in_dialog.dart';
import 'apaleo_connect_dialog.dart';

class ReceptionShell extends ConsumerStatefulWidget {
  final String employeeName;
  final String propertyName;
  final String propertyId;
  final VoidCallback? onLogout;

  const ReceptionShell({
    super.key,
    required this.employeeName,
    required this.propertyName,
    required this.propertyId,
    this.onLogout,
  });

  @override
  ConsumerState<ReceptionShell> createState() => _ReceptionShellState();
}

class _ReceptionShellState extends ConsumerState<ReceptionShell> {
  int _currentHubIndex = 0;
  bool _showAuthErrorBanner = false;

  @override
  void initState() {
    super.initState();
    // Listen for auth token errors and surface them in the UI
    ApaleoService.tokenExpiredNotifier.addListener(_onTokenStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.propertyId.isNotEmpty) {
        ref.read(activePropertyIdProvider.notifier).state = widget.propertyId;
        // Start automatic PMS polling loop (every 5 minutes to preserve Disk IO)
        PmsSyncService.instance.startPeriodicSync(
          propertyId: widget.propertyId,
          interval: const Duration(minutes: 5),
          onComplete: () {
            if (mounted) {
              ref.read(receptionRefreshSignalProvider.notifier).state++;
            }
          },
        );
      }
    });
  }

  void _onTokenStateChanged() {
    if (mounted) {
      setState(() {
        _showAuthErrorBanner = ApaleoService.tokenExpiredNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    ApaleoService.tokenExpiredNotifier.removeListener(_onTokenStateChanged);
    PmsSyncService.instance.stopPeriodicSync();
    super.dispose();
  }

  void _openWalkIn([Map<String, dynamic>? preselectedRoom]) {
    showDialog(
      context: context,
      builder: (_) => InstantWalkInDialog(initialRoom: preselectedRoom),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.departureLight,
                borderRadius: AppSpacing.roundedSm,
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.departure, size: 20),
            ),
            AppSpacing.gapH12,
            Text('Logout Front Desk', style: AppTypography.titleSmall),
          ],
        ),
        content: Text(
          'Are you sure you want to end your workstation session and log out?',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onLogout != null) {
                widget.onLogout!();
              } else {
                SupabaseService.instance.clearSession();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.loginVerificationScreen,
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.departure,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedSm),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              elevation: 0,
            ),
            child: const Text('Confirm Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kpis = ref.watch(liveDeskKpiProvider);
    final todayFormatted = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      // ── AUTH ERROR BANNER ───────────────────────────────────────────────────────
      // Shows when Apaleo token refresh fails. Disappears once reconnected.
      bottomNavigationBar: _showAuthErrorBanner
          ? SafeArea(
              top: false,
              child: Container(
                color: const Color(0xFFB91C1C),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ApaleoService.tokenErrorMessage.value ??
                            'Apaleo connection lost. Sync paused.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const ApaleoConnectDialog(),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Reconnect Now',
                          style: TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;

          return Column(
            children: [
              // ── TOP WORKSTATION CONSOLE HEADER ─────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? AppSpacing.md : AppSpacing.xxl,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
                  boxShadow: [AppColors.shadowSm],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      // Hotel Workstation Brand Identity
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: AppSpacing.roundedSm,
                              ),
                              child: const Center(
                                child: Icon(Icons.hotel_class_rounded, size: 18, color: AppColors.brass),
                              ),
                            ),
                            AppSpacing.gapH12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.propertyName.isNotEmpty ? widget.propertyName.toUpperCase() : 'CONCIGO LUXURY RESORT',
                                          style: AppTypography.labelLarge.copyWith(
                                            letterSpacing: 1.1,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                            fontSize: isMobile ? 12 : 13.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (constraints.maxWidth >= 860) ...[
                                        AppSpacing.gapH8,
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: AppColors.textMuted,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        AppSpacing.gapH8,
                                        Text(
                                          'Front Desk Console',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    todayFormatted,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: isMobile ? 10.5 : 11.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      AppSpacing.gapH8,

                      // Actions & PMS Controls
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Apaleo PMS status chip — tap to connect/manage
                          const ApaleoStatusChip(),

                          // Sync / Refresh Trigger
                          IconButton(
                            tooltip: 'Synchronize Live Data & PMS Now',
                            icon: const Icon(Icons.sync_rounded, size: 19, color: AppColors.textSecondary),
                            onPressed: () async {
                              if (widget.propertyId.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Syncing with PMS...'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                                await PmsSyncService.instance.syncReservations(propertyId: widget.propertyId);
                              }
                              ref.read(receptionRefreshSignalProvider.notifier).state++;
                            },
                          ),

                          if (constraints.maxWidth >= 920) ...[
                            AppSpacing.gapH8,
                            // Desk Agent Profile Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: AppSpacing.roundedSm,
                                border: Border.all(color: AppColors.border, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  AppSpacing.gapH8,
                                  Text(
                                    widget.employeeName.isNotEmpty ? widget.employeeName : 'Front Desk Agent',
                                    style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          AppSpacing.gapH8,

                          // Logout Trigger
                          IconButton(
                            tooltip: 'Logout Front Desk',
                            icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.departure),
                            onPressed: () => _showLogoutDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── 4 RECEPTION WORKSTATION HUBS ────────────────────────────────
              Container(
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? AppSpacing.md : AppSpacing.xxl),
                  child: Row(
                    children: [
                      _buildHubTab(0, 'Front Desk', Icons.dashboard_outlined, badgeCount: null),
                      _buildHubTab(1, 'Arrivals & Check-In', Icons.flight_land_rounded, badgeCount: kpis.pendingKYC > 0 ? kpis.pendingKYC : null),
                      _buildHubTab(2, 'Upsells & Offers', Icons.local_offer_outlined, badgeCount: null),
                      _buildHubTab(3, 'Billing & Departure', Icons.receipt_long_outlined, badgeCount: kpis.dueDepartures > 0 ? kpis.dueDepartures : null),
                    ],
                  ),
                ),
              ),

              // ── MAIN ACTIVE WORKSTATION VIEWPORT ─────────────────────────────
              Expanded(
                child: _buildActiveHubView(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveHubView() {
    switch (_currentHubIndex) {
      case 0:
        return LiveFrontDeskView(
          onNavigateToArrivals: () => setState(() => _currentHubIndex = 1),
          onNavigateToUpsells: () => setState(() => _currentHubIndex = 2),
          onNavigateToBilling: () => setState(() => _currentHubIndex = 3),
          onWalkInWithRoom: (room) => _openWalkIn(room),
        );
      case 1:
        return const ArrivalsCheckinView();
      case 2:
        return const UpsellsOffersView();
      case 3:
        return const BillingDepartureView();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHubTab(int index, String title, IconData icon, {int? badgeCount}) {
    final isSelected = _currentHubIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentHubIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2.2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            if (badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.attention,
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
