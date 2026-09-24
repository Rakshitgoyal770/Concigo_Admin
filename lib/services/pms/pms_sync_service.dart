import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pms_adapter.dart';
import 'pms_factory.dart';

/// Enterprise PMS Synchronization Service.
///
/// Orchestrates bi-directional data flow between PMS adapters and Concigo's Supabase backend.
/// Features:
/// - Concurrency lock to prevent duplicate sync executions.
/// - Batch upserting into `stay`, `stay_rooms`, and `users`.
/// - Automatic folio charge posting for upsells & early arrival passes.
class PmsSyncService {
  final SupabaseClient _client;

  PmsSyncService(this._client);

  static PmsSyncService? _instance;
  static PmsSyncService get instance => _instance ??= PmsSyncService(Supabase.instance.client);

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Timer? _periodicTimer;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;
  VoidCallback? onSyncCompleted;
  int _syncCycleCounter = 0;

  /// Starts an automatic polling loop that queries the PMS periodically (default: every 30 seconds).
  void startPeriodicSync({
    required String propertyId,
    Duration interval = const Duration(seconds: 30),
    VoidCallback? onComplete,
  }) {
    stopPeriodicSync();
    if (onComplete != null) onSyncCompleted = onComplete;
    _syncCycleCounter = 0;
    debugPrint('[PmsSyncService] Auto-sync loop activated for property $propertyId (every ${interval.inSeconds}s)');

    // Immediate initial sync: sync physical rooms first, then reservations
    syncPhysicalRooms(propertyId: propertyId).then((_) {
      syncReservations(propertyId: propertyId).then((res) {
        if (res.isSuccess) onSyncCompleted?.call();
      });
    });

    _periodicTimer = Timer.periodic(interval, (_) async {
      _syncCycleCounter++;
      // Re-sync physical rooms every 10 cycles (~5 minutes) to catch room extensions/modifications
      if (_syncCycleCounter % 10 == 0) {
        await syncPhysicalRooms(propertyId: propertyId);
      }
      final res = await syncReservations(propertyId: propertyId);
      if (res.isSuccess) {
        onSyncCompleted?.call();
      }
    });
  }

  /// Stops the automatic polling loop.
  void stopPeriodicSync() {
    if (_periodicTimer != null) {
      _periodicTimer!.cancel();
      _periodicTimer = null;
      debugPrint('[PmsSyncService] Auto-sync loop stopped.');
    }
  }

  /// Ingests all physical rooms from PMS directly into Supabase `rooms` table.
  /// Dynamically provisions any new rooms or updates category/floor of existing rooms.
  Future<int> syncPhysicalRooms({required String propertyId}) async {
    try {
      final context = await PmsFactory.getContextForHotel(
        client: _client,
        propertyId: propertyId,
      );

      debugPrint('[PmsSyncService] Fetching physical room inventory from ${context.adapter.provider} (${context.propertyCode})...');
      final rooms = await context.adapter.fetchPhysicalRooms(
        propertyCode: context.propertyCode,
      );

      if (rooms.isEmpty) {
        debugPrint('[PmsSyncService] No physical rooms returned by PMS adapter.');
        return 0;
      }

      // Query existing rooms in Supabase for this property
      final existingRows = await _client
          .from('rooms')
          .select('room_id, room_number')
          .eq('property_id', propertyId);

      final Map<String, String> existingMap = {
        for (final r in (existingRows as List))
          r['room_number']?.toString() ?? '': r['room_id']?.toString() ?? '',
      };

      int upsertedCount = 0;
      final List<Map<String, dynamic>> newRoomsToInsert = [];

      for (final r in rooms) {
        if (r.roomNumber.isEmpty) continue;
        final roomId = existingMap[r.roomNumber];
        final roomType = r.categoryName ?? (r.categoryCode.isNotEmpty ? r.categoryCode : 'Standard');

        if (roomId != null) {
          // Update room category & floor if needed
          await _client.from('rooms').update({
            'type': roomType,
            if (r.floor != null) 'floor': r.floor,
            'is_active': true,
          }).eq('room_id', roomId);
          upsertedCount++;
        } else {
          newRoomsToInsert.add({
            'property_id': propertyId,
            'room_number': r.roomNumber,
            'type': roomType,
            'floor': r.floor,
            'is_active': true,
            'is_booked': r.isOccupied,
          });
        }
      }

      if (newRoomsToInsert.isNotEmpty) {
        await _client.from('rooms').insert(newRoomsToInsert);
        upsertedCount += newRoomsToInsert.length;
      }

      debugPrint('[PmsSyncService] Successfully synchronized $upsertedCount physical rooms into Supabase.');
      return upsertedCount;
    } catch (e) {
      debugPrint('[PmsSyncService] Failed to sync physical rooms: $e');
      return 0;
    }
  }

  /// Ingests live reservations from the hotel's configured PMS into Concigo Supabase.
  Future<PmsSyncResult> syncReservations({
    required String propertyId,
    DateTime? from,
    DateTime? to,
  }) async {
    if (_isSyncing) {
      debugPrint('[PmsSyncService] Sync already in progress for property $propertyId. Skipping.');
      return const PmsSyncResult(
        isSuccess: false,
        totalFetched: 0,
        totalSynced: 0,
        errorMessage: 'A sync is already in progress.',
      );
    }

    _isSyncing = true;
    int syncedCount = 0;
    int errorCount = 0;

    try {
      final context = await PmsFactory.getContextForHotel(
        client: _client,
        propertyId: propertyId,
      );

      debugPrint(
        '[PmsSyncService] Starting sync for hotel $propertyId using ${context.adapter.provider} (${context.propertyCode})...',
      );

      final reservations = await context.adapter.fetchReservations(
        propertyCode: context.propertyCode,
        from: from,
        to: to,
      );

      debugPrint('[PmsSyncService] Fetched ${reservations.length} live reservations from PMS.');

      for (final res in reservations) {
        try {
          await _ingestSingleReservation(
            propertyId: propertyId,
            res: res,
          );
          syncedCount++;
        } catch (e) {
          errorCount++;
          debugPrint('[PmsSyncService] Failed to ingest reservation ${res.bookingReference}: $e');
        }
      }

      _lastSyncTime = DateTime.now();
      return PmsSyncResult(
        isSuccess: true,
        totalFetched: reservations.length,
        totalSynced: syncedCount,
        failedCount: errorCount,
      );
    } catch (e) {
      debugPrint('[PmsSyncService] Critical error during PMS sync: $e');
      return PmsSyncResult(
        isSuccess: false,
        totalFetched: 0,
        totalSynced: syncedCount,
        failedCount: errorCount,
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Ingests a single canonical reservation into Supabase `stay`, `stay_rooms`, and `users`.
  Future<void> _ingestSingleReservation({
    required String propertyId,
    required CanonicalReservation res,
  }) async {
    // 1. Resolve or Create the Guest in `users`
    String? guestUserId = await _resolveOrCreateGuestUser(res.primaryGuest);

    final checkInStr = res.checkInDate.toIso8601String().split('T')[0];
    final checkOutStr = res.checkOutDate.toIso8601String().split('T')[0];
    final stayStatus = res.status == 'InHouse'
        ? 'Active'
        : (res.status == 'Canceled' || res.status == 'CheckedOut' ? 'Ended' : 'Upcoming');

    // 2. Check if a stay row already exists for this guest & dates
    String stayId;
    var query = _client
        .from('stay')
        .select('stay_id, status')
        .eq('hotel_id', propertyId)
        .eq('check_in_date', checkInStr);

    if (guestUserId != null) {
      query = query.eq('main_user_id', guestUserId);
    }

    final existingList = await query.limit(1) as List;

    if (existingList.isNotEmpty) {
      stayId = existingList.first['stay_id'] as String;
      // Update dates & status
      await _client.from('stay').update({
        'check_out_date': checkOutStr,
        'status': stayStatus,
      }).eq('stay_id', stayId);

      // If stay ended (checked out in PMS), release assigned room(s)
      if (stayStatus == 'Ended') {
        final linkedStayRooms = await _client
            .from('stay_rooms')
            .select('room_id')
            .eq('stay_id', stayId);
        for (final sr in (linkedStayRooms as List)) {
          final rid = sr['room_id']?.toString();
          if (rid != null && rid.isNotEmpty) {
            await _client.from('rooms').update({'is_booked': false}).eq('room_id', rid);
          }
        }
      }
    } else {
      // Insert new stay
      final insertData = <String, dynamic>{
        'hotel_id': propertyId,
        'check_in_date': checkInStr,
        'check_out_date': checkOutStr,
        'status': stayStatus,
        if (guestUserId != null) 'main_user_id': guestUserId,
      };

      final newStay = await _client
          .from('stay')
          .insert(insertData)
          .select('stay_id')
          .single();

      stayId = newStay['stay_id'] as String;

      // Add to stay_guests
      if (guestUserId != null) {
        try {
          await _client.from('stay_guests').insert({
            'stay_id': stayId,
            'user_id': guestUserId,
          });
        } catch (_) {}
      }
    }

    // 3. Link Room in `rooms` & `stay_rooms`
    if (res.assignedRoomNumber != null && res.assignedRoomNumber!.isNotEmpty) {
      await _linkStayRoom(
        propertyId: propertyId,
        stayId: stayId,
        roomNumber: res.assignedRoomNumber!,
        category: res.roomCategory,
      );
    }
  }

  /// Resolves an existing user by phone/email or creates a lightweight guest account.
  Future<String?> _resolveOrCreateGuestUser(CanonicalGuest guest) async {
    try {
      final phone = guest.phone.trim();
      final email = guest.email.trim();

      if (phone.isNotEmpty) {
        final existingByPhone = await _client
            .from('users')
            .select('user_id')
            .eq('mobile_no', phone)
            .limit(1);

        if ((existingByPhone as List).isNotEmpty) {
          return existingByPhone.first['user_id'] as String;
        }
      }

      if (email.isNotEmpty) {
        final existingByEmail = await _client
            .from('users')
            .select('user_id')
            .eq('email', email)
            .limit(1);

        if ((existingByEmail as List).isNotEmpty) {
          return existingByEmail.first['user_id'] as String;
        }
      }

      // Create new lightweight guest profile
      final insertUser = await _client
          .from('users')
          .insert({
            'name': guest.fullName.isNotEmpty ? guest.fullName : 'Guest',
            'mobile_no': phone.isNotEmpty ? phone : '+910000000000',
            'email': email.isNotEmpty ? email : null,
            'status': 'active',
          })
          .select('user_id')
          .single();

      return insertUser['user_id'] as String;
    } catch (_) {
      return null;
    }
  }

  /// Ensures physical room exists and attaches to `stay_rooms`.
  Future<void> _linkStayRoom({
    required String propertyId,
    required String stayId,
    required String roomNumber,
    required String category,
  }) async {
    try {
      // Find room in hotel inventory
      final roomRows = await _client
          .from('rooms')
          .select('room_id')
          .eq('property_id', propertyId)
          .eq('room_number', roomNumber)
          .limit(1);

      String roomId;
      if ((roomRows as List).isNotEmpty) {
        roomId = roomRows.first['room_id'] as String;
      } else {
        // Auto-create room in inventory
        final newRoom = await _client
            .from('rooms')
            .insert({
              'property_id': propertyId,
              'room_number': roomNumber,
              'type': category,
              'is_active': true,
            })
            .select('room_id')
            .single();

        roomId = newRoom['room_id'] as String;
      }

      // Attach to stay_rooms if not already attached
      final existingStayRoom = await _client
          .from('stay_rooms')
          .select('id')
          .eq('stay_id', stayId)
          .eq('room_id', roomId)
          .maybeSingle();

      if (existingStayRoom == null) {
        await _client.from('stay_rooms').insert({
          'stay_id': stayId,
          'room_id': roomId,
        });
      }
    } catch (e) {
      debugPrint('[PmsSyncService] Room link error: $e');
    }
  }

  /// Posts an Early Arrival Pass, Late Checkout, or Upsell directly to Apaleo Folio.
  Future<FolioChargeResult> postUpsellChargeToFolio({
    required String propertyId,
    required String pmsReservationId,
    required double amount,
    required String currency,
    required String description,
    String serviceType = 'Extra',
  }) async {
    final context = await PmsFactory.getContextForHotel(
      client: _client,
      propertyId: propertyId,
    );

    return await context.adapter.postFolioCharge(
      pmsReservationId: pmsReservationId,
      amount: amount,
      currency: currency,
      description: description,
      serviceType: serviceType,
    );
  }
}

class PmsSyncResult {
  final bool isSuccess;
  final int totalFetched;
  final int totalSynced;
  final int failedCount;
  final String? errorMessage;

  const PmsSyncResult({
    required this.isSuccess,
    required this.totalFetched,
    required this.totalSynced,
    this.failedCount = 0,
    this.errorMessage,
  });
}
