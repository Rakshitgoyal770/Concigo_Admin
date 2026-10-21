import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/luxury_badge.dart';

/// How a pass claim is shown to staff, from SupabaseService.passState():
/// paid / room_bill / held / failed / abandoned.
class PassStateStyle {
  final String label;
  final String amountLabel;
  final IconData icon;
  final Color color;
  final LuxuryBadgeVariant badge;
  final bool counts;

  const PassStateStyle(this.label, this.amountLabel, this.icon, this.color, this.badge, this.counts);

  static PassStateStyle of(String? state) {
    switch (state) {
      case 'room_bill':
        return const PassStateStyle('On room bill', 'Due at checkout', Icons.receipt_long_rounded,
            AppColors.info, LuxuryBadgeVariant.info, true);
      case 'held':
        return const PassStateStyle('Payment in progress', 'Awaiting', Icons.hourglass_top_rounded,
            AppColors.textMuted, LuxuryBadgeVariant.attention, true);
      case 'failed':
        return const PassStateStyle('Payment failed', 'Not paid', Icons.error_outline_rounded,
            AppColors.departure, LuxuryBadgeVariant.departure, false);
      case 'abandoned':
        return const PassStateStyle('Not completed', 'Not paid', Icons.cancel_outlined,
            AppColors.textMuted, LuxuryBadgeVariant.neutral, false);
      case 'paid':
      default:
        return const PassStateStyle('Paid online', 'Paid', Icons.check_circle_rounded,
            AppColors.success, LuxuryBadgeVariant.success, true);
    }
  }
}
