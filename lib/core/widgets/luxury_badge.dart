import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';

enum LuxuryBadgeVariant {
  primary,
  success,
  attention,
  departure,
  info,
  purple,
  neutral,
}

/// Restrained Operational Status Tag for 5-Star Hotel Consoles
class LuxuryBadge extends StatelessWidget {
  final String label;
  final LuxuryBadgeVariant variant;
  final IconData? icon;
  final bool isSmall;

  const LuxuryBadge({
    super.key,
    required this.label,
    this.variant = LuxuryBadgeVariant.neutral,
    this.icon,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    switch (variant) {
      case LuxuryBadgeVariant.primary:
        bg = AppColors.primaryLight;
        border = AppColors.primary.withValues(alpha: 0.2);
        text = AppColors.primary;
        break;
      case LuxuryBadgeVariant.success:
        bg = AppColors.successLight;
        border = AppColors.successBorder;
        text = const Color(0xFF3D6852);
        break;
      case LuxuryBadgeVariant.attention:
        bg = AppColors.attentionLight;
        border = AppColors.attentionBorder;
        text = const Color(0xFF94652A);
        break;
      case LuxuryBadgeVariant.departure:
        bg = AppColors.departureLight;
        border = AppColors.departureBorder;
        text = const Color(0xFF84383E);
        break;
      case LuxuryBadgeVariant.info:
        bg = AppColors.infoLight;
        border = AppColors.infoBorder;
        text = const Color(0xFF2C525D);
        break;
      case LuxuryBadgeVariant.purple:
        bg = AppColors.brassLight;
        border = AppColors.brassBorder;
        text = const Color(0xFF7A643B);
        break;
      case LuxuryBadgeVariant.neutral:
        bg = AppColors.surfaceSubtle;
        border = AppColors.border;
        text = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 7 : 9,
        vertical: isSmall ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppSpacing.roundedSm, // Crisp 4px status tag, not a bubble pill
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 11 : 12, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: (isSmall ? AppTypography.labelSmall : AppTypography.labelMedium).copyWith(
              color: text,
              fontWeight: FontWeight.w600,
              fontSize: isSmall ? 10.5 : 11.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
