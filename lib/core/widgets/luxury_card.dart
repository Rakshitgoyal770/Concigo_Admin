import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Structured Operational Surface for 5-Star Hotel Workstation
class LuxuryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final bool isSelected;
  final bool isHoverable;

  const LuxuryCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.width,
    this.height,
    this.isSelected = false,
    this.isHoverable = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = isSelected
        ? Border.all(color: AppColors.primary, width: 1.2)
        : Border.all(color: borderColor ?? AppColors.border, width: 0.8);

    final effectiveBg = isSelected
        ? AppColors.primaryLight.withValues(alpha: 0.5)
        : (backgroundColor ?? AppColors.surface);

    final card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: AppSpacing.roundedMd, // Crisp 8px radius
        border: effectiveBorder,
        boxShadow: const [AppColors.shadowSm],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.roundedMd,
        hoverColor: AppColors.surfaceHover,
        splashColor: AppColors.primaryLight.withValues(alpha: 0.4),
        child: card,
      );
    }

    return card;
  }
}
