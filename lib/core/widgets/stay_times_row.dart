import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/reception_providers.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../utils/stay_times.dart';

/// Check-in and check-out time of a stay, with an EARLY / LATE tag when a
/// confirmed pass moves it away from the hotel's standard time.
///
/// Drop it into any screen that lists stays:
///   StayTimesRow(stay: stay)
/// It reads the hotel times and the stay's passes from the reception providers,
/// so the screen needs no extra data. Shows nothing until the hotel's times have
/// loaded (rather than showing a wrong default).
class StayTimesRow extends ConsumerWidget {
  final Map<String, dynamic> stay;
  final bool showCheckIn;
  final bool showCheckOut;

  /// Include the day ("Today, 2:00 PM") instead of just the clock time.
  final bool showDay;

  const StayTimesRow({
    super.key,
    required this.stay,
    this.showCheckIn = true,
    this.showCheckOut = true,
    this.showDay = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotel = ref.watch(hotelTimesProvider).valueOrNull;
    if (hotel == null) return const SizedBox.shrink();

    final stayId = (stay['stay_id'] ?? stay['id'])?.toString();
    final passes = (ref.watch(stayPassesProvider).valueOrNull ?? const {})[stayId] ?? const <StayPass>[];
    final info = StayTimes.resolve(stay: stay, hotel: hotel, passes: passes);

    final chips = <Widget>[
      if (showCheckIn && info.checkIn != null)
        _chip(
          icon: Icons.login_rounded,
          label: 'Check-in ${showDay ? StayTimes.dayAndClock(info.checkIn!) : StayTimes.clock(info.checkIn!)}',
          tag: info.hasEarlyCheckIn ? 'EARLY' : null,
          tagColor: AppColors.success,
          tooltip: info.hasEarlyCheckIn
              ? 'Early check-in pass (standard ${StayTimes.clock(info.standardCheckIn!)})'
              : 'Standard check-in time',
        ),
      if (showCheckOut && info.checkOut != null)
        _chip(
          icon: Icons.logout_rounded,
          label: 'Check-out ${showDay ? StayTimes.dayAndClock(info.checkOut!) : StayTimes.clock(info.checkOut!)}',
          tag: info.hasLateCheckOut ? 'LATE' : null,
          tagColor: AppColors.purple,
          tooltip: info.hasLateCheckOut
              ? 'Late check-out pass (standard ${StayTimes.clock(info.standardCheckOut!)})'
              : 'Standard check-out time',
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: chips);
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required String? tag,
    required Color tagColor,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tag != null ? tagColor : AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: tag != null ? tagColor : AppColors.textSecondary,
              fontWeight: tag != null ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tagColor, letterSpacing: 0.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
