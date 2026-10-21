import 'package:flutter_test/flutter_test.dart';
import 'package:zappyadmin/core/utils/stay_times.dart';

Map<String, dynamic> accept(String type, String time, List<String> payStatuses, {String created = '2026-10-20T10:00:00'}) => {
      'type': type,
      'time_selected': time,
      'created_at': created,
      'early_late_offer_payments': [for (final s in payStatuses) {'status': s}],
    };

void main() {
  const berlin = HotelTimes(checkInHour: 15, checkOutHour: 11);
  final stay = {'check_in_date': '2026-10-21', 'check_out_date': '2026-10-22'};

  test('standard times come from the hotel', () {
    final i = StayTimes.resolve(stay: stay, hotel: berlin);
    expect(StayTimes.clock(i.checkIn!), '3:00 PM');
    expect(StayTimes.clock(i.checkOut!), '11:00 AM');
    expect(i.hasEarlyCheckIn, false);
    expect(i.hasLateCheckOut, false);
  });

  test('HotelTimes.fromRow reads postgres time strings', () {
    final h = HotelTimes.fromRow({'checkin_time': '12:30:00', 'checkout_time': '10:00:00'});
    expect([h.checkInHour, h.checkInMinute, h.checkOutHour], [12, 30, 10]);
    expect(HotelTimes.fromRow(null).checkInHour, 14); // fallback
  });

  test('paid and room-bill passes move the time; wall clock is not timezone-shifted', () {
    final passes = [
      StayPass.fromAccept(accept('early_in', '2026-10-21T08:00:00', ['success']))!,
      StayPass.fromAccept(accept('late_out', '2026-10-22T14:00:00', ['pending']))!,
    ];
    final i = StayTimes.resolve(stay: stay, hotel: berlin, passes: passes);
    expect(StayTimes.clock(i.checkIn!), '8:00 AM');
    expect(StayTimes.clock(i.checkOut!), '2:00 PM');
    expect(i.hasEarlyCheckIn, true);
    expect(i.hasLateCheckOut, true);
  });

  test('abandoned or failed claims are not passes', () {
    expect(StayPass.fromAccept(accept('late_out', '2026-10-22T14:00:00', [])), isNull);
    expect(StayPass.fromAccept(accept('late_out', '2026-10-22T14:00:00', ['failed'])), isNull);
  });

  test('a pass cannot move the time the wrong way', () {
    final passes = [
      StayPass.fromAccept(accept('early_in', '2026-10-21T16:00:00', ['success']))!,
      StayPass.fromAccept(accept('late_out', '2026-10-22T09:00:00', ['success']))!,
    ];
    final i = StayTimes.resolve(stay: stay, hotel: berlin, passes: passes);
    expect(StayTimes.clock(i.checkIn!), '3:00 PM');
    expect(StayTimes.clock(i.checkOut!), '11:00 AM');
    expect(i.hasEarlyCheckIn || i.hasLateCheckOut, false);
  });

  test('the newest pass wins', () {
    final passes = [
      StayPass.fromAccept(accept('late_out', '2026-10-22T13:00:00', ['success'], created: '2026-10-20T09:00:00'))!,
      StayPass.fromAccept(accept('late_out', '2026-10-22T15:00:00', ['success'], created: '2026-10-20T11:00:00'))!,
    ];
    expect(StayTimes.clock(StayTimes.resolve(stay: stay, hotel: berlin, passes: passes).checkOut!), '3:00 PM');
  });

  test('past check-out is judged against the pass time, not 11:00', () {
    final late = [StayPass.fromAccept(accept('late_out', '2026-10-22T14:00:00', ['success']))!];
    final withPass = StayTimes.resolve(stay: stay, hotel: berlin, passes: late);
    final without = StayTimes.resolve(stay: stay, hotel: berlin);
    final noon = DateTime(2026, 10, 22, 12, 0);
    expect(without.isPastCheckOut(noon), true);
    expect(withPass.isPastCheckOut(noon), false);
    expect(withPass.isPastCheckOut(DateTime(2026, 10, 22, 14, 1)), true);
  });

  test('day labels', () {
    final now = DateTime(2026, 10, 21, 9, 0);
    expect(StayTimes.dayAndClock(DateTime(2026, 10, 21, 15), now: now), 'Today, 3:00 PM');
    expect(StayTimes.dayAndClock(DateTime(2026, 10, 22, 11), now: now), 'Tomorrow, 11:00 AM');
    expect(StayTimes.dayAndClock(DateTime(2026, 10, 25, 11), now: now), '25 Oct, 11:00 AM');
  });
}
