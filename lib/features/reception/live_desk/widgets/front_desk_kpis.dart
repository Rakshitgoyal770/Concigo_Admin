import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../data/providers/reception_providers.dart';

/// Elevated 5-Star Luxury Operational Metric Cards
class FrontDeskKpisSection extends ConsumerWidget {
  final VoidCallback? onArrivalsTap;
  final VoidCallback? onKycTap;
  final VoidCallback? onBillingTap;

  const FrontDeskKpisSection({
    super.key,
    this.onArrivalsTap,
    this.onKycTap,
    this.onBillingTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(liveDeskKpiProvider);
    final attentionCount = kpis.pendingKYC + (kpis.pendingLuggage > 0 ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final availableCard = _buildMetricCard(
          icon: Icons.hotel_rounded,
          iconColor: AppColors.primary,
          iconBg: AppColors.primaryLight,
          count: '${kpis.vacantRooms}',
          label: 'Available Rooms',
        );

        final arrivalsCard = _buildMetricCard(
          icon: Icons.flight_land_rounded,
          iconColor: AppColors.success,
          iconBg: AppColors.successLight,
          count: kpis.expectedArrivals < 10 ? '0${kpis.expectedArrivals}' : '${kpis.expectedArrivals}',
          label: 'Today Arrivals',
          onTap: onArrivalsTap,
        );

        final inHouseCard = _buildMetricCard(
          icon: Icons.people_outline_rounded,
          iconColor: AppColors.primary,
          iconBg: AppColors.surfaceSubtle,
          count: kpis.occupiedRooms < 10 ? '0${kpis.occupiedRooms}' : '${kpis.occupiedRooms}',
          label: 'In-House Guests',
        );

        final departuresCard = _buildMetricCard(
          icon: Icons.flight_takeoff_rounded,
          iconColor: AppColors.textSecondary,
          iconBg: AppColors.surfaceSubtle,
          count: kpis.dueDepartures < 10 ? '0${kpis.dueDepartures}' : '${kpis.dueDepartures}',
          label: 'Due Departures',
          onTap: onBillingTap,
        );

        final actionCard = _buildMetricCard(
          icon: Icons.bolt_rounded,
          iconColor: attentionCount > 0 ? AppColors.attention : AppColors.textMuted,
          iconBg: attentionCount > 0 ? AppColors.attentionLight : AppColors.surfaceSubtle,
          count: attentionCount < 10 ? '0$attentionCount' : '$attentionCount',
          label: 'Action Required',
          highlightBadge: attentionCount > 0 ? 'ACTION' : null,
          onTap: onKycTap,
        );

        // Desktop / Wide Ribbon (>= 720px): All metrics in a single sleek horizontal row
        if (width >= 720) {
          return Row(
            children: [
              Expanded(child: availableCard),
              const SizedBox(width: 8),
              Expanded(child: arrivalsCard),
              const SizedBox(width: 8),
              Expanded(child: inHouseCard),
              const SizedBox(width: 8),
              Expanded(child: departuresCard),
              if (attentionCount > 0) ...[
                const SizedBox(width: 8),
                Expanded(child: actionCard),
              ],
            ],
          );
        }

        // Compact / Mobile (< 720px): 2-column slim grid with horizontal cards
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: availableCard),
                const SizedBox(width: 8),
                Expanded(child: arrivalsCard),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: inHouseCard),
                const SizedBox(width: 8),
                Expanded(child: departuresCard),
              ],
            ),
            if (attentionCount > 0) ...[
              const SizedBox(height: 6),
              actionCard,
            ],
          ],
        );
      },
    );
  }

  /// Compact 5-Star Operational Metric Card — Horizontal Icon + Stat layout
  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String count,
    required String label,
    String? highlightBadge,
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(
          color: highlightBadge != null ? AppColors.attention.withValues(alpha: 0.5) : AppColors.border,
          width: highlightBadge != null ? 1.0 : 0.8,
        ),
        boxShadow: const [AppColors.shadowSm],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Icon(icon, size: 16, color: iconColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: highlightBadge != null ? AppColors.attention : AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (highlightBadge != null) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.attention,
                          borderRadius: BorderRadius.circular(3.5),
                        ),
                        child: Text(
                          highlightBadge,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.roundedSm,
        hoverColor: AppColors.surfaceHover,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
