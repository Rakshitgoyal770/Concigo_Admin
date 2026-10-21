import '../../core/utils/stay_times.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import 'supabase_providers.dart';

/// Refresh Triggers to invalidate data after mutations
final receptionRefreshSignalProvider = StateProvider<int>((ref) => 0);

/// Active Selected Property ID (can be set explicitly from UI/Router)
final activePropertyIdProvider = StateProvider<String?>((ref) => null);

/// Resolved Property ID with fallback to session or first active property in DB
final resolvedPropertyIdProvider = FutureProvider<String>((ref) async {
  final explicitPropId = ref.watch(activePropertyIdProvider);
  if (explicitPropId != null && explicitPropId.isNotEmpty) {
    return explicitPropId;
  }
  final sessionPropId = SupabaseService.instance.currentSession?.propertyId;
  if (sessionPropId != null && sessionPropId.isNotEmpty) {
    return sessionPropId;
  }
  // Try loading persisted session from local storage (survives web page refreshes)
  try {
    final persisted = await SupabaseService.instance.loadPersistedSession();
    if (persisted != null && persisted.propertyId.isNotEmpty) {
      return persisted.propertyId;
    }
  } catch (_) {}
  // No verified session → no property. (Previously fell back to the first
  // active hotel, exposing its data to anyone who reached this screen.)
  return '';
});

/// All Rooms Provider for the Live Room Matrix
final receptionRoomsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  final roomService = ref.watch(roomServiceProvider);
  return await roomService.fetchRooms(propertyId: propId);
});

/// Upcoming Stays (Arrivals Queue)
final upcomingStaysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  final stayService = ref.watch(stayServiceProvider);
  return await stayService.fetchUpcomingStays(propertyId: propId);
});

/// Active In-House Stays
final activeStaysProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  final stayService = ref.watch(stayServiceProvider);
  return await stayService.fetchActiveStays(propertyId: propId);
});

/// Pending KYC & Pre-Check-in Requests
final checkinRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  final guestService = ref.watch(guestServiceProvider);
  return await guestService.fetchCheckinRequests(propertyId: propId);
});

/// Bellboy Luggage Queue Provider
final bellboyQueueProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  final bellboyService = ref.watch(bellboyServiceProvider);
  return await bellboyService.fetchLuggageRequests(propertyId: propId);
});

/// Active Room Upgrades Provider
final roomUpgradesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  final offerService = ref.watch(offerServiceProvider);
  return await offerService.fetchRoomUpgrades(propertyId: propId);
});

/// Active Promotional Offers Provider
final activeOffersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  final offerService = ref.watch(offerServiceProvider);
  return await offerService.fetchActiveOffers(propertyId: propId);
});

/// The selected hotel's standard check-in / check-out times.
final hotelTimesProvider = FutureProvider<HotelTimes>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return const HotelTimes();
  final row = await SupabaseService.instance.fetchHotelTimes(propId);
  return HotelTimes.fromRow(row);
});

/// Confirmed early / late passes per open stay (stay_id -> passes).
/// Unconfirmed claims (abandoned or failed payments) are left out.
final stayPassesProvider = FutureProvider<Map<String, List<StayPass>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return const {};
  final rows = await SupabaseService.instance.fetchOpenStayPassRows(propId);
  final byStay = <String, List<StayPass>>{};
  for (final row in rows) {
    final pass = StayPass.fromAccept(row);
    final stayId = row['stay_id']?.toString();
    if (pass == null || stayId == null) continue;
    byStay.putIfAbsent(stayId, () => []).add(pass);
  }
  return byStay;
});

/// Early Check-In Offers Provider
final earlyCheckinOffersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  return await SupabaseService.instance.fetchEarlyLateOffers(propId, 'early_in');
});

/// Late Check-Out Offers Provider
final lateCheckoutOffersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  return await SupabaseService.instance.fetchEarlyLateOffers(propId, 'late_out');
});

/// Early / Late Offer Accepts Provider
final earlyLateAcceptsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(receptionRefreshSignalProvider);
  final propId = await ref.watch(resolvedPropertyIdProvider.future);
  if (propId.isEmpty) return [];
  // Let failures propagate: the tabs show an error with a Retry button
  // instead of claiming "no requests yet" when the query actually failed.
  return await SupabaseService.instance.fetchEarlyLateAccepts(propId);
});

/// Aggregated Live Desk KPIs Model
class LiveDeskKpis {
  final int totalRooms;
  final int occupiedRooms;
  final int vacantRooms;
  final int cleaningRooms;
  final int maintenanceRooms;
  final int expectedArrivals;
  final int todayArrivals;
  final int overdueArrivals;
  final int activeStays;
  final int dueDepartures;
  final int pendingKYC;
  final int pendingLuggage;

  const LiveDeskKpis({
    this.totalRooms = 0,
    this.occupiedRooms = 0,
    this.vacantRooms = 0,
    this.cleaningRooms = 0,
    this.maintenanceRooms = 0,
    this.expectedArrivals = 0,
    this.todayArrivals = 0,
    this.overdueArrivals = 0,
    this.activeStays = 0,
    this.dueDepartures = 0,
    this.pendingKYC = 0,
    this.pendingLuggage = 0,
  });

  double get occupancyRate =>
      totalRooms > 0 ? (occupiedRooms / totalRooms) * 100 : 0.0;
}

/// Live Desk KPI Aggregator Provider
final liveDeskKpiProvider = Provider<LiveDeskKpis>((ref) {
  final roomsAsync = ref.watch(receptionRoomsProvider);
  final upcomingAsync = ref.watch(upcomingStaysProvider);
  final activeAsync = ref.watch(activeStaysProvider);
  final kycAsync = ref.watch(checkinRequestsProvider);
  final luggageAsync = ref.watch(bellboyQueueProvider);

  final rooms = roomsAsync.asData?.value ?? [];
  final upcoming = upcomingAsync.asData?.value ?? [];
  final active = activeAsync.asData?.value ?? [];
  final kyc = kycAsync.asData?.value ?? [];
  final luggage = luggageAsync.asData?.value ?? [];

  int occupied = 0;
  int vacant = 0;
  int cleaning = 0;
  int maintenance = 0;

  for (final r in rooms) {
    final status = (r['status'] as String? ?? '').toLowerCase();
    if (status == 'occupied') {
      occupied++;
    } else if (status == 'cleaning' || status == 'needs cleaning') {
      cleaning++;
    } else if (status == 'maintenance') {
      maintenance++;
    } else {
      vacant++;
    }
  }

  // Calculate Today Arrivals vs Overdue Arrivals vs Future
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  int todayArrivalsCount = 0;
  int overdueArrivalsCount = 0;
  for (final u in upcoming) {
    final dStr = u['check_in_date']?.toString();
    if (dStr != null) {
      final dt = DateTime.tryParse(dStr.split('T')[0]);
      if (dt != null) {
        final d = DateTime(dt.year, dt.month, dt.day);
        if (d.isBefore(today)) {
          overdueArrivalsCount++;
        } else if (d.year == today.year && d.month == today.month && d.day == today.day) {
          todayArrivalsCount++;
        }
      }
    }
  }

  // Calculate Due Departures (in-house active stays checking out today or earlier)
  int dueDeparturesCount = 0;
  for (final a in active) {
    final dStr = a['check_out_date']?.toString();
    if (dStr != null) {
      final dt = DateTime.tryParse(dStr.split('T')[0]);
      if (dt != null) {
        final d = DateTime(dt.year, dt.month, dt.day);
        if (d.isBefore(today) || (d.year == today.year && d.month == today.month && d.day == today.day)) {
          dueDeparturesCount++;
        }
      }
    }
  }

  final pendingKycCount = kyc.where((k) {
    final st = (k['status'] as String? ?? '').toLowerCase();
    final hasDocs = k['has_documents'] == true || (k['submitted_documents'] as List? ?? []).isNotEmpty;
    return st != 'approved' && st != 'rejected' && st != 'denied' && hasDocs;
  }).length;

  final pendingLuggageCount = luggage.where((l) {
    final st = (l['status'] as String? ?? '').toLowerCase();
    return st == 'pending' || st == 'requested';
  }).length;

  return LiveDeskKpis(
    totalRooms: rooms.length,
    occupiedRooms: occupied,
    vacantRooms: vacant,
    cleaningRooms: cleaning,
    maintenanceRooms: maintenance,
    expectedArrivals: todayArrivalsCount + overdueArrivalsCount,
    todayArrivals: todayArrivalsCount,
    overdueArrivals: overdueArrivalsCount,
    activeStays: active.length,
    dueDepartures: dueDeparturesCount,
    pendingKYC: pendingKycCount,
    pendingLuggage: pendingLuggageCount,
  );
});
