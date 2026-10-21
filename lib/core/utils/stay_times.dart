/// How a stay's check-in / check-out TIME is worked out.
///
/// The `stay` table stores only DATES (`check_in_date`, `check_out_date`).
/// The time of day comes from two places:
///
///   1. the hotel's standard times (`hotel_property.checkin_time/checkout_time`);
///   2. a CONFIRMED Early Check-In / Late Check-Out pass, whose chosen time is
///      stored on `early_late_offer_accepts.time_selected`.
///
/// A pass counts only when it is paid online (`success`) or booked to the room
/// bill (`pending`). A claim that was abandoned or failed does not move the time.
///
/// Times are wall-clock hours at the hotel, compared with the device clock, so
/// staff devices are expected to be on the hotel's local time.
library;

import 'package:intl/intl.dart';

/// Standard check-in / check-out time of a hotel.
class HotelTimes {
  final int checkInHour;
  final int checkInMinute;
  final int checkOutHour;
  final int checkOutMinute;

  const HotelTimes({
    this.checkInHour = 14,
    this.checkInMinute = 0,
    this.checkOutHour = 11,
    this.checkOutMinute = 0,
  });

  /// Reads `{checkin_time: '15:00:00', checkout_time: '11:00:00'}`.
  factory HotelTimes.fromRow(Map<String, dynamic>? row) {
    (int, int) parse(Object? v, int h, int m) {
      final parts = v?.toString().split(':') ?? const [];
      if (parts.isEmpty) return (h, m);
      return (int.tryParse(parts[0]) ?? h, parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
    }

    final cin = parse(row?['checkin_time'], 14, 0);
    final cout = parse(row?['checkout_time'], 11, 0);
    return HotelTimes(
      checkInHour: cin.$1,
      checkInMinute: cin.$2,
      checkOutHour: cout.$1,
      checkOutMinute: cout.$2,
    );
  }
}

/// A confirmed early check-in / late check-out pass on a stay.
class StayPass {
  final String type; // 'early_in' | 'late_out'
  final String? timeSelected;
  final String createdAt;

  /// 'paid' (online) or 'room_bill' (pay at checkout).
  final String state;

  const StayPass({
    required this.type,
    required this.timeSelected,
    required this.createdAt,
    required this.state,
  });

  /// Builds a pass from an accept row with embedded
  /// `early_late_offer_payments(status)`. Returns null for an unconfirmed claim.
  static StayPass? fromAccept(Map<String, dynamic> row) {
    final pays = (row['early_late_offer_payments'] as List?) ?? const [];
    final statuses = pays.map((p) => (p as Map)['status']?.toString()).toSet();
    final String? state = statuses.contains('success')
        ? 'paid'
        : statuses.contains('pending')
            ? 'room_bill'
            : null;
    if (state == null) return null;
    final type = row['type']?.toString();
    if (type != 'early_in' && type != 'late_out') return null;
    return StayPass(
      type: type!,
      timeSelected: row['time_selected']?.toString(),
      createdAt: row['created_at']?.toString() ?? '',
      state: state,
    );
  }

  /// Hour and minute as the guest picked them: "2026-10-21T08:00:00" -> (8, 0).
  /// Read from the text, never through a timezone conversion.
  (int, int)? get wallClock {
    final m = RegExp(r'T(\d{2}):(\d{2})').firstMatch(timeSelected ?? '');
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }
}

/// The resolved times of one stay.
class StayTimeInfo {
  final DateTime? checkIn;
  final DateTime? checkOut;
  final DateTime? standardCheckIn;
  final DateTime? standardCheckOut;
  final StayPass? earlyPass;
  final StayPass? latePass;

  const StayTimeInfo({
    required this.checkIn,
    required this.checkOut,
    required this.standardCheckIn,
    required this.standardCheckOut,
    required this.earlyPass,
    required this.latePass,
  });

  bool get hasEarlyCheckIn => earlyPass != null && _differs(checkIn, standardCheckIn);
  bool get hasLateCheckOut => latePass != null && _differs(checkOut, standardCheckOut);

  /// True once the guest should have left (device clock past the check-out moment).
  bool isPastCheckOut([DateTime? now]) =>
      checkOut != null && (now ?? DateTime.now()).isAfter(checkOut!);

  static bool _differs(DateTime? a, DateTime? b) => a != null && b != null && !a.isAtSameMomentAs(b);
}

class StayTimes {
  StayTimes._();

  /// Resolves check-in / check-out for [stay] (needs `check_in_date` and
  /// `check_out_date`) with the hotel's standard times and the stay's confirmed [passes].
  static StayTimeInfo resolve({
    required Map<String, dynamic> stay,
    required HotelTimes hotel,
    List<StayPass> passes = const [],
  }) {
    final inDay = _day(stay['check_in_date']);
    final outDay = _day(stay['check_out_date']);

    final stdIn = inDay == null
        ? null
        : DateTime(inDay.year, inDay.month, inDay.day, hotel.checkInHour, hotel.checkInMinute);
    final stdOut = outDay == null
        ? null
        : DateTime(outDay.year, outDay.month, outDay.day, hotel.checkOutHour, hotel.checkOutMinute);

    StayPass? latest(String type) {
      final list = passes.where((p) => p.type == type && p.wallClock != null).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list.isEmpty ? null : list.last;
    }

    final early = latest('early_in');
    final late = latest('late_out');

    DateTime? checkIn = stdIn;
    if (early != null && inDay != null) {
      final (h, m) = early.wallClock!;
      final t = DateTime(inDay.year, inDay.month, inDay.day, h, m);
      // An early pass can only move check-in earlier than the standard time.
      if (stdIn == null || t.isBefore(stdIn)) checkIn = t;
    }

    DateTime? checkOut = stdOut;
    if (late != null && outDay != null) {
      final (h, m) = late.wallClock!;
      final t = DateTime(outDay.year, outDay.month, outDay.day, h, m);
      // A late pass can only move check-out later than the standard time.
      if (stdOut == null || t.isAfter(stdOut)) checkOut = t;
    }

    return StayTimeInfo(
      checkIn: checkIn,
      checkOut: checkOut,
      standardCheckIn: stdIn,
      standardCheckOut: stdOut,
      earlyPass: early,
      latePass: late,
    );
  }

  static DateTime? _day(Object? v) {
    final s = v?.toString().split('T').first;
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  /// "2:00 PM"
  static String clock(DateTime t) => DateFormat('h:mm a').format(t);

  /// "Today, 2:00 PM" / "Tomorrow, 11:00 AM" / "22 Oct, 11:00 AM"
  static String dayAndClock(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = day.difference(today).inDays;
    final prefix = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Tomorrow'
            : diff == -1
                ? 'Yesterday'
                : DateFormat('d MMM').format(t);
    return '$prefix, ${clock(t)}';
  }
}
