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

    // Accurate status mapping from PMS:
    // - InHouse -> 'Active' (currently in hotel, occupies room, appears in Checkout view)
    // - Confirmed -> 'Upcoming' (scheduled arrival, appears in Arrivals view)
    // - Canceled / CheckedOut -> 'Ended'
    String stayStatus;
    if (res.status == 'Canceled' || res.status == 'CheckedOut') {
      stayStatus = 'Ended';
    } else if (res.status == 'InHouse') {
      stayStatus = 'Active';
    } else {
      stayStatus = 'Upcoming';
    }

    final pmsTag = 'PMS:${res.pmsReservationId}';

    // 1. Check if this specific PMS reservation was ALREADY linked to a stay
    String? stayId;
    if (res.pmsReservationId.isNotEmpty) {
      try {
        final linkedReqList = await _client
            .from('checkin_requests')
            .select('stay_id, stay(status)')
            .eq('remark', pmsTag)
            .limit(1) as List;

        if (linkedReqList.isNotEmpty) {
          final stayData = linkedReqList.first['stay'] as Map<String, dynamic>?;
          final existingStayStatus = stayData?['status'] as String?;
          final linkedStayId = linkedReqList.first['stay_id'] as String?;

          // If the stay linked to this PMS reservation was already Ended (checked out in Concigo),
          // NEVER resurrect or recreate it!
          if (existingStayStatus == 'Ended' && stayStatus != 'Ended') {
            debugPrint('[PmsSyncService] Reservation ${res.pmsReservationId} was checked out in Concigo (Ended). Skipping resurrection.');
            return;
          }

          if (linkedStayId != null) {
            stayId = linkedStayId;
          }
        }
      } catch (_) {}
    }

    // 2. If not already identified by PMS ID, check if an active stay exists for this guest & dates
    if (stayId == null) {
      // First check if a stay for this guest and dates was ALREADY Ended (checked out).
      // If yes, do NOT resurrect it!
      if (guestUserId != null) {
        final endedList = await _client
            .from('stay')
            .select('stay_id')
            .eq('hotel_id', propertyId)
            .eq('main_user_id', guestUserId)
            .eq('check_in_date', checkInStr)
            .eq('status', 'Ended')
            .limit(1) as List;

        if (endedList.isNotEmpty) {
          debugPrint('[PmsSyncService] Stay for guest $guestUserId on $checkInStr was already checked out (Ended). Skipping resurrection.');
          return;
        }
      }

      var query = _client
          .from('stay')
          .select('stay_id, status')
          .eq('hotel_id', propertyId)
          .eq('check_in_date', checkInStr)
          .neq('status', 'Ended');

      if (guestUserId != null) {
        query = query.eq('main_user_id', guestUserId);
      }

      final existingList = await query.limit(1) as List;
      if (existingList.isNotEmpty) {
        stayId = existingList.first['stay_id'] as String;
      }
    }

    // ISSUE-15: Check if a manually created stay (MANUAL: tag) already exists for
    // the same guest and check-in date. If yes, link PMS tag to it instead of creating
    // a duplicate stay. This prevents race condition between manual desk booking & PMS sync.
    if (stayId == null && guestUserId != null) {
      try {
        final manualCrList = await _client
            .from('checkin_requests')
            .select('stay_id, remark')
            .eq('main_user_id', guestUserId)
            .ilike('remark', 'MANUAL:%')
            .limit(5) as List;

        for (final cr in manualCrList) {
          final manualStayId = cr['stay_id']?.toString();
          if (manualStayId == null) continue;
          // Verify this manual stay has the same check-in date
          final matchingStay = await _client
              .from('stay')
              .select('stay_id, check_in_date')
              .eq('stay_id', manualStayId)
              .eq('check_in_date', checkInStr)
              .neq('status', 'Ended')
              .maybeSingle();
          if (matchingStay != null) {
            stayId = manualStayId;
            debugPrint('[PmsSyncService] Linked PMS reservation ${res.pmsReservationId} to existing manual stay $stayId');
            break;
          }
        }
      } catch (_) {}
    }

    if (stayId != null) {
      final currentStay = await _client
          .from('stay')
          .select('status')
          .eq('stay_id', stayId)
          .maybeSingle();

      final currentStatus = currentStay?['status'] as String?;

      // Preserve 'Active' if reception already activated this stay in Concigo
      if (currentStatus == 'Active' && stayStatus != 'Ended') {
        stayStatus = 'Active';
      }

      // Update dates & status & heal guestUserId if needed
      await _client.from('stay').update({
        'check_out_date': checkOutStr,
        'status': stayStatus,
        if (guestUserId != null) 'main_user_id': guestUserId,
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

    // Ensure PMS reservation ID is recorded on checkin_requests for 2-way tracking.
    // BUG-6: Always create/update a checkin_request even when user resolution failed,
    // so the PMS tag is never lost and resurrection prevention always works.
    if (res.pmsReservationId.isNotEmpty) {
      try {
        final existingCr = await _client
            .from('checkin_requests')
            .select('id')
            .eq('stay_id', stayId)
            .limit(1) as List;

        if (existingCr.isNotEmpty) {
          await _client.from('checkin_requests').update({
            'remark': pmsTag,
          }).eq('id', existingCr.first['id']);
        } else {
          // Always insert — resolve main_user_id from stay if guestUserId is null
          var effectiveUserId = guestUserId;
          if (effectiveUserId == null) {
            final stayRow = await _client.from('stay').select('main_user_id').eq('stay_id', stayId).maybeSingle();
            effectiveUserId = stayRow?['main_user_id']?.toString();
          }
          if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
            final code = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
            await _client.from('checkin_requests').insert({
              'stay_id': stayId,
              'main_user_id': effectiveUserId,
              'status': stayStatus == 'Active' ? 'approved' : 'pending',
              'checkin_code': code,
              'remark': pmsTag,
              'submitted_req': [],
            });
          }
        }
      } catch (_) {}
    }

    // 3. Link Room in `rooms` & `stay_rooms`
    if (res.assignedRoomNumber != null && res.assignedRoomNumber!.isNotEmpty) {
      await _linkStayRoom(
        propertyId: propertyId,
        stayId: stayId,
        roomNumber: res.assignedRoomNumber!,
        category: res.roomCategory,
        isStayActive: stayStatus == 'Active',
      );
    }
  }

  /// Resolves an existing active user by phone/email or creates a lightweight guest account.
  /// Edge case handling:
  /// - Multiple entries per phone: Prioritizes active, non-deleted accounts (latest created first).
  /// - Stale/deleted accounts: Ignored so reservations are never attached to deactivated profiles.
  /// - Missing email: Enriches active user with email from PMS if empty.
  Future<String?> _resolveOrCreateGuestUser(CanonicalGuest guest) async {
    try {
      final rawPhone = guest.phone.trim();
      final phone = rawPhone.replaceAll(RegExp(r'[\s\-()]'), '');
      final email = guest.email.trim();
      final incomingName = guest.fullName.trim();

      if (phone.isNotEmpty) {
        // ISSUE-10: Normalize to E.164 before matching to prevent last-10-digit
        // collisions between different country codes (e.g. +1-9518 vs +91-9518).
        final normalized = _normalizeToE164(phone);
        final last10 = phone.length >= 10 ? phone.substring(phone.length - 10) : phone;

        // 1. Look for ACTIVE, non-deleted user with exact normalized phone (latest first)
        var existingByPhone = await _client
            .from('users')
            .select('user_id, name, email')
            .eq('mobile_no', normalized)
            .eq('status', 'active')
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false)
            .limit(1);

        // 2. Fallback to last 10 digits (active, non-deleted, latest first)
        if ((existingByPhone as List).isEmpty && last10.isNotEmpty) {
          existingByPhone = await _client
              .from('users')
              .select('user_id, name, email')
              .ilike('mobile_no', '%$last10')
              .eq('status', 'active')
              .isFilter('deleted_at', null)
              .order('created_at', ascending: false)
              .limit(1);
        }

        if ((existingByPhone as List).isNotEmpty) {
          final userId = existingByPhone.first['user_id'] as String;
          final existingName = (existingByPhone.first['name'] as String? ?? '').trim();
          final existingEmail = (existingByPhone.first['email'] as String? ?? '').trim();

          // BUG-5: Only update name if the stored name is empty or a placeholder.
          // Never overwrite a real name that may have been corrected by a receptionist.
          final isPlaceholder = existingName.isEmpty ||
              existingName.toLowerCase() == 'guest' ||
              existingName.startsWith('Guest (');

          final updateFields = <String, dynamic>{};
          if (isPlaceholder && incomingName.isNotEmpty && incomingName != 'Guest') {
            updateFields['name'] = incomingName;
            if (guest.firstName.isNotEmpty) updateFields['first_name'] = guest.firstName;
            if (guest.lastName.isNotEmpty) updateFields['last_name'] = guest.lastName;
          }
          if (existingEmail.isEmpty && email.isNotEmpty) {
            updateFields['email'] = email;
          }

          if (updateFields.isNotEmpty) {
            try {
              await _client.from('users').update(updateFields).eq('user_id', userId);
            } catch (_) {}
          }
          return userId;
        }
      }

      // 3. Fallback: Search by email (active, non-deleted, latest first)
      if (email.isNotEmpty) {
        final existingByEmail = await _client
            .from('users')
            .select('user_id, name, email')
            .eq('email', email)
            .eq('status', 'active')
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false)
            .limit(1);

        if ((existingByEmail as List).isNotEmpty) {
          final userId = existingByEmail.first['user_id'] as String;
          final existingName = (existingByEmail.first['name'] as String? ?? '').trim();
          final isPlaceholder = existingName.isEmpty ||
              existingName.toLowerCase() == 'guest' ||
              existingName.startsWith('Guest (');

          if (isPlaceholder && incomingName.isNotEmpty && incomingName != 'Guest') {
            try {
              await _client.from('users').update({
                'name': incomingName,
                if (guest.firstName.isNotEmpty) 'first_name': guest.firstName,
                if (guest.lastName.isNotEmpty) 'last_name': guest.lastName,
              }).eq('user_id', userId);
            } catch (_) {}
          }
          return userId;
        }
      }

      // 4. Create new lightweight guest profile (active)
      final fallbackPhone = '+9199${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final normalizedPhone = phone.isNotEmpty ? _normalizeToE164(phone) : fallbackPhone;
      final insertUser = await _client
          .from('users')
          .insert({
            'name': guest.fullName.isNotEmpty ? guest.fullName : 'Guest',
            'mobile_no': normalizedPhone,
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

  /// Normalizes a phone number to E.164 format to avoid last-10-digit collisions.
  String _normalizeToE164(String raw) {
    final stripped = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (stripped.startsWith('+')) return stripped;
    // If 10 digits and no country code, assume India (+91)
    final digits = stripped.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return stripped; // fallback: return as-is
  }

  /// Ensures physical room exists and attaches to `stay_rooms`.
  /// BUG-4: If a room assignment changes in PMS, remove the old stay_rooms entry
  /// and release the old room before linking the new one.
  Future<void> _linkStayRoom({
    required String propertyId,
    required String stayId,
    required String roomNumber,
    required String category,
    bool isStayActive = false,
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
              'is_booked': isStayActive,
            })
            .select('room_id')
            .single();

        roomId = newRoom['room_id'] as String;
      }

      // BUG-4: Detect and clean up stale room assignments.
      // If the PMS assigned a different room, release the old one.
      final existingStayRooms = await _client
          .from('stay_rooms')
          .select('id, room_id')
          .eq('stay_id', stayId) as List;

      for (final existingEntry in existingStayRooms) {
        final existingRoomId = existingEntry['room_id']?.toString();
        if (existingRoomId != null && existingRoomId != roomId) {
          // Room has changed in PMS — remove stale assignment and free old room
          await _client
              .from('stay_rooms')
              .delete()
              .eq('id', existingEntry['id']);
          await _client
              .from('rooms')
              .update({'is_booked': false})
              .eq('room_id', existingRoomId);
          debugPrint('[PmsSyncService] Stale room $existingRoomId removed from stay $stayId (replaced by $roomId)');
        }
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

      // If stay is Active (InHouse), ensure the room is marked as booked/occupied
      if (isStayActive) {
        await _client
            .from('rooms')
            .update({'is_booked': true})
            .eq('room_id', roomId);
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
