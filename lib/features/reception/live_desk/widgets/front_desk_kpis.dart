import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../data/providers/reception_providers.dart';

/// Ultra-Slim 5-Star Operational Metric Ribbon (Approach 1)
/// Compresses 4 metrics into a single sleek ~38px horizontal operational ticker
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: const [AppColors.shadowSm],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;

          final items = [
            _buildTickerItem(
              icon: Icons.hotel_rounded,
              iconColor: AppColors.primary,
              count: '${kpis.vacantRooms}',
              label: isWide ? 'Available Rooms' : 'Avail',
            ),
            _buildTickerItem(
              icon: Icons.flight_land_rounded,
              iconColor: AppColors.success,
              count: kpis.expectedArrivals < 10 ? '0${kpis.expectedArrivals}' : '${kpis.expectedArrivals}',
              label: isWide ? 'Today Arrivals' : 'Arr',
              onTap: onArrivalsTap,
            ),
            _buildTickerItem(
              icon: Icons.people_outline_rounded,
              iconColor: AppColors.primary,
              count: kpis.occupiedRooms < 10 ? '0${kpis.occupiedRooms}' : '${kpis.occupiedRooms}',
              label: isWide ? 'In-House Guests' : 'In-House',
            ),
            _buildTickerItem(
              icon: Icons.flight_takeoff_rounded,
              iconColor: AppColors.textSecondary,
              count: kpis.dueDepartures < 10 ? '0${kpis.dueDepartures}' : '${kpis.dueDepartures}',
              label: isWide ? 'Due Departures' : 'Dep',
              onTap: onBillingTap,
            ),
            if (attentionCount > 0)
              _buildTickerItem(
                icon: Icons.bolt_rounded,
                iconColor: AppColors.attention,
                count: attentionCount < 10 ? '0$attentionCount' : '$attentionCount',
                label: 'Action',
                countColor: AppColors.attention,
                isAlert: true,
                onTap: onKycTap,
              ),
          ];

          if (isWide) {
            return Row(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) _buildDivider(),
                  Expanded(child: Center(child: items[i])),
                ],
              ],
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) _buildDivider(),
                  items[i],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTickerItem({
    required IconData icon,
    required Color iconColor,
    required String count,
    required String label,
    Color? countColor,
    bool isAlert = false,
    VoidCallback? onTap,
  }) {
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      hoverColor: AppColors.surfaceHover,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(
              count,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: countColor ?? AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isAlert ? AppColors.attention : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    return content;
  }

  Widget _buildDivider() {
    return Container(
      height: 16,
      width: 0.8,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}
