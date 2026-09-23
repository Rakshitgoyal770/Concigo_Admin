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
        : (res.status == 'Canceled' ? 'Ended' : 'Upcoming');

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
