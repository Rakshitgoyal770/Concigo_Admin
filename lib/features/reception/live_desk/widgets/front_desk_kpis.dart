import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
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
        final isMobile = constraints.maxWidth < 520;

        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.hotel_rounded,
                      iconColor: AppColors.primary,
                      iconBg: AppColors.primaryLight,
                      count: '${kpis.vacantRooms}',
                      label: 'Available Rooms',
                    ),
                  ),
                  AppSpacing.gapH12,
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.flight_land_rounded,
                      iconColor: AppColors.success,
                      iconBg: AppColors.successLight,
                      count: kpis.expectedArrivals < 10 ? '0${kpis.expectedArrivals}' : '${kpis.expectedArrivals}',
                      label: 'Today Arrivals',
                      onTap: onArrivalsTap,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapV12,
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.people_outline_rounded,
                      iconColor: AppColors.primary,
                      iconBg: AppColors.surfaceSubtle,
                      count: kpis.occupiedRooms < 10 ? '0${kpis.occupiedRooms}' : '${kpis.occupiedRooms}',
                      label: 'In-House Guests',
                    ),
                  ),
                  AppSpacing.gapH12,
                  Expanded(
                    child: _buildMetricCard(
                      icon: Icons.flight_takeoff_rounded,
                      iconColor: AppColors.textSecondary,
                      iconBg: AppColors.surfaceSubtle,
                      count: kpis.activeStays < 10 ? '0${kpis.activeStays}' : '${kpis.activeStays}',
                      label: 'Due Departures',
                      onTap: onBillingTap,
                    ),
                  ),
                ],
              ),
              if (attentionCount > 0) ...[
                AppSpacing.gapV12,
                _buildMetricCard(
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.attention,
                  iconBg: AppColors.attentionLight,
                  count: attentionCount < 10 ? '0$attentionCount' : '$attentionCount',
                  label: 'Action Required (Pre-Checkin & KYC Queue)',
                  isFullWidth: true,
                  onTap: onKycTap,
                ),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.hotel_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primaryLight,
                count: '${kpis.vacantRooms}',
                label: 'Available Rooms',
              ),
            ),
            AppSpacing.gapH12,
            Expanded(
              child: _buildMetricCard(
                icon: Icons.flight_land_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.primaryLight,
                count: kpis.expectedArrivals < 10 ? '0${kpis.expectedArrivals}' : '${kpis.expectedArrivals}',
                label: 'Today Arrivals',
                onTap: onArrivalsTap,
              ),
            ),
            AppSpacing.gapH12,
            Expanded(
              child: _buildMetricCard(
                icon: Icons.people_outline_rounded,
                iconColor: AppColors.primary,
                iconBg: AppColors.surfaceSubtle,
                count: kpis.occupiedRooms < 10 ? '0${kpis.occupiedRooms}' : '${kpis.occupiedRooms}',
                label: 'In-House Guests',
              ),
            ),
            AppSpacing.gapH12,
            Expanded(
              child: _buildMetricCard(
                icon: Icons.flight_takeoff_rounded,
                iconColor: AppColors.textSecondary,
                iconBg: AppColors.surfaceSubtle,
                count: kpis.activeStays < 10 ? '0${kpis.activeStays}' : '${kpis.activeStays}',
                label: 'Due Departures',
                onTap: onBillingTap,
              ),
            ),
            AppSpacing.gapH12,
            Expanded(
              child: _buildMetricCard(
                icon: Icons.bolt_rounded,
                iconColor: attentionCount > 0 ? AppColors.attention : AppColors.textMuted,
                iconBg: attentionCount > 0 ? AppColors.attentionLight : AppColors.surfaceSubtle,
                count: attentionCount < 10 ? '0$attentionCount' : '$attentionCount',
                label: 'Attention Required',
                highlightBadge: attentionCount > 0 ? 'ACTION' : null,
                onTap: onKycTap,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String count,
    required String label,
    String? highlightBadge,
    bool isFullWidth = false,
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: highlightBadge != null ? AppColors.attention.withValues(alpha: 0.4) : AppColors.border,
          width: highlightBadge != null ? 1.2 : 0.8,
        ),
        boxShadow: const [AppColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: Center(
                  child: Icon(icon, size: 16, color: iconColor),
                ),
              ),
              if (highlightBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.attention,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    highlightBadge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.gapV8,
          Text(
            count,
            style: AppTypography.displayNumber.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: highlightBadge != null ? AppColors.attention : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.roundedMd,
        hoverColor: AppColors.surfaceHover,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
