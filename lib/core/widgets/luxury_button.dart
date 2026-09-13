import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';

enum LuxuryButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  danger,
  success,
}

class LuxuryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final LuxuryButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final double? height;

  const LuxuryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = LuxuryButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case LuxuryButtonVariant.primary:
        bg = AppColors.primary;
        fg = AppColors.textInverted;
        border = BorderSide.none;
        break;
      case LuxuryButtonVariant.secondary:
        bg = AppColors.surfaceSubtle;
        fg = AppColors.textPrimary;
        border = const BorderSide(color: AppColors.border, width: 1);
        break;
      case LuxuryButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.primary;
        border = const BorderSide(color: AppColors.primary, width: 1.2);
        break;
      case LuxuryButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.textSecondary;
        border = BorderSide.none;
        break;
      case LuxuryButtonVariant.danger:
        bg = AppColors.departure;
        fg = AppColors.textInverted;
        border = BorderSide.none;
        break;
      case LuxuryButtonVariant.success:
        bg = AppColors.success;
        fg = AppColors.textInverted;
        border = BorderSide.none;
        break;
    }

    final buttonContent = Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: AppTypography.labelLarge.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final widget = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.6),
        disabledForegroundColor: fg.withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        side: border,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
      ),
      child: buttonContent,
    );

    if (isExpanded) {
      return SizedBox(
        width: double.infinity,
        height: height ?? 44,
        child: widget,
      );
    }

    if (height != null) {
      return SizedBox(height: height, child: widget);
    }

    return widget;
  }
}
