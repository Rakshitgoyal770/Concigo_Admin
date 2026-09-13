import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum BadgeStatus {
  pending,
  inProgress,
  delivered,
  cancelled,
  active,
  checkedOut,
  available,
  booked,
  paid,
  custom,
}

class StatusBadgeWidget extends StatelessWidget {
  final BadgeStatus status;
  final String? customLabel;
  final Color? customColor;
  final Color? customBgColor;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.customLabel,
    this.customColor,
    this.customBgColor,
  });

  _BadgeConfig _getConfig() {
    switch (status) {
      case BadgeStatus.pending:
        return _BadgeConfig(
          'Pending',
          AppTheme.pending,
          AppTheme.pendingContainer,
        );
      case BadgeStatus.inProgress:
        return _BadgeConfig(
          'In Progress',
          AppTheme.primary,
          AppTheme.primaryContainer,
        );
      case BadgeStatus.delivered:
        return _BadgeConfig(
          'Delivered',
          AppTheme.success,
          AppTheme.successContainer,
        );
      case BadgeStatus.cancelled:
        return _BadgeConfig(
          'Cancelled',
          AppTheme.error,
          AppTheme.errorContainer,
        );
      case BadgeStatus.active:
        return _BadgeConfig(
          'Active',
          AppTheme.success,
          AppTheme.successContainer,
        );
      case BadgeStatus.checkedOut:
        return _BadgeConfig(
          'Checked Out',
          AppTheme.onSurfaceMuted,
          AppTheme.surfaceVariant,
        );
      case BadgeStatus.available:
        return _BadgeConfig(
          'Available',
          AppTheme.success,
          AppTheme.successContainer,
        );
      case BadgeStatus.booked:
        return _BadgeConfig(
          'Booked',
          AppTheme.warning,
          AppTheme.warningContainer,
        );
      case BadgeStatus.paid:
        return _BadgeConfig(
          'Paid',
          AppTheme.success,
          AppTheme.successContainer,
        );
      case BadgeStatus.custom:
        return _BadgeConfig(
          customLabel ?? 'Unknown',
          customColor ?? AppTheme.onSurfaceMuted,
          customBgColor ?? AppTheme.surfaceVariant,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        config.label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _BadgeConfig {
  final String label;
  final Color color;
  final Color bgColor;
  const _BadgeConfig(this.label, this.color, this.bgColor);
}
