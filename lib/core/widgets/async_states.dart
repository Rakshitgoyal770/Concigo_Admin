import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'luxury_button.dart';

/// Loading and error states for data panels.
///
/// A panel that renders nothing while it loads, or when its query fails, is
/// indistinguishable from "there is nothing to show". For a front desk that means
/// a broken connection reads as "no arrivals today". Use these so staff can tell
/// the difference, and can retry without reloading the whole app.
class PanelLoading extends StatelessWidget {
  final String label;
  const PanelLoading({super.key, this.label = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(height: 8),
              Text(label, style: AppTypography.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class PanelError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  /// What failed, in the staff's words: "arrivals", "in-house guests"…
  final String what;

  const PanelError({super.key, required this.error, required this.onRetry, this.what = 'this list'});

  /// Short, human text for an exception.
  static String describe(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('timeout') ||
        lower.contains('connection')) {
      return 'No connection to the server. Check the internet and try again.';
    }
    if (lower.contains('jwt') || lower.contains('permission denied') || lower.contains('401') || lower.contains('403')) {
      return 'Your session may have expired or you lack access. Sign in again.';
    }
    return raw.length > 160 ? '${raw.substring(0, 160)}…' : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Could not load $what',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.departure.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.departure.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.departure, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Couldn\'t load $what', style: AppTypography.labelMedium),
                  const SizedBox(height: 2),
                  Text(describe(error), style: AppTypography.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 10),
            LuxuryButton(text: 'Retry', variant: LuxuryButtonVariant.outline, height: 34, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
