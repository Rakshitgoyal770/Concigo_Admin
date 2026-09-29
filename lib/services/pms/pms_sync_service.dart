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

  /// Tracks how many consecutive sync cycles have failed (ClientException / 503).
  /// Used to trigger adaptive backoff: skip a cycle when DB is clearly unhealthy.
  int _consecutiveFailures = 0;

  /// In-memory cache: pmsReservationId → last seen PMS `modified` timestamp.
  /// Used to skip DB work for reservations that haven't changed between sync cycles.
  /// Cache is cleared when the sync service is stopped or app restarts.
  final Map<String, DateTime> _lastSeenModifiedAt = {};

  /// In-memory cache: pmsReservationId → last synced status in Concigo.
  /// Lets us fast-path skip Ended+Ended reservations without any DB lookup.
  final Map<String, String> _lastSeenStatus = {};

  /// Delta sync watermark: the timestamp of the last successful sync cycle.
  /// On cold-start (null), we do a full Stay-window fetch to build baseline.
  /// On subsequent cycles, we fetch only reservations MODIFIED since this timestamp.
  /// This reduces Apaleo API load from O(all reservations) to O(changed reservations).
  DateTime? _deltaWatermark;

  /// Fires every time a sync cycle completes successfully.
  /// UI widgets can listen to this to show "last synced X ago" indicators.
  static final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier(null);

  // ── Retry constants ──────────────────────────────────────────────────────────
  /// Max retry attempts per reservation on transient fetch errors.
  static const int _kMaxRetries = 2;
  /// Delay between retries (doubles each attempt: 1s → 2s).
  static const _kRetryBaseDelay = Duration(seconds: 1);


  /// Starts a reconciliation polling loop against the PMS (default: every 5 minutes).
  ///
  /// Role: SAFETY NET only. Apaleo webhooks (apaleo-webhook Edge Function) handle
  /// real-time reservation changes instantly. This loop uses a delta watermark so
  /// it fetches ONLY modifications since the last cycle — costing 0 DB writes when
  /// the hotel is idle. A full cold-start fetch runs once on session start.
  void startPeriodicSync({
    required String propertyId,
    Duration interval = const Duration(minutes: 5),
    VoidCallback? onComplete,
  }) {
    stopPeriodicSync();
    if (onComplete != null) onSyncCompleted = onComplete;
    _syncCycleCounter = 0;
    _isSyncing = false;
    debugPrint('[PmsSyncService] Auto-sync loop activated for property $propertyId (every ${interval.inSeconds}s)');

    // Immediate initial sync: sync physical rooms first, then reservations
    syncPhysicalRooms(propertyId: propertyId).then((_) {
      syncReservations(propertyId: propertyId).then((res) {
        if (res.isSuccess) onSyncCompleted?.call();
      });
    });

    _periodicTimer = Timer.periodic(interval, (_) async {
      // Skip this tick if sync is already running
      if (_isSyncing) {
        debugPrint('[PmsSyncService] ⏭ Skipping sync tick — sync already in progress.');
        return;
      }

      // ── Adaptive backoff: if we have had ≥2 consecutive failures, skip this
      // cycle and allow Supabase to recover before hammering it again.
      if (_consecutiveFailures >= 2) {
        // Allow recovery every 2nd skipped cycle
        if (_syncCycleCounter % 2 != 0) {
          debugPrint('[PmsSyncService] ⏸ Adaptive backoff — $_consecutiveFailures consecutive failures. Waiting for DB to recover...');
          _syncCycleCounter++;
          return;
        }
      }

      // ── Pre-flight health check: abort the entire sync cycle if Supabase
      // cannot even answer a simple ping query. This prevents the 34-reservation
      // burst from making 170 failing requests against an unhealthy database.
      if (!await _isSupabaseHealthy()) {
        _consecutiveFailures++;
        debugPrint('[PmsSyncService] ❌ Pre-flight health check failed (Supabase unreachable). Aborting sync cycle. Failures: $_consecutiveFailures');
        _syncCycleCounter++;
        return;
      }

      try {
        _syncCycleCounter++;
        // Re-sync physical rooms every 6 cycles (= every ~30 min at 5min interval)
        if (_syncCycleCounter % 6 == 0) {
          await syncPhysicalRooms(propertyId: propertyId)
              .timeout(const Duration(seconds: 25));
        }
        final res = await syncReservations(propertyId: propertyId)
            .timeout(const Duration(seconds: 60));
        if (res.isSuccess) {
          _consecutiveFailures = 0; // Reset failure counter on success
          _lastSyncTime = DateTime.now();
          lastSyncNotifier.value = _lastSyncTime;
          onSyncCompleted?.call();
        } else {
          _consecutiveFailures++;
        }
      } catch (e) {
        _consecutiveFailures++;
        debugPrint('[PmsSyncService] ⚠️ Sync cycle error/timeout: $e');
      }
    });
  }

  /// Lightweight Supabase health probe: queries 1 row from a small table.
  /// Returns true if Supabase is reachable, false on any network/503/521 error.
  Future<bool> _isSupabaseHealthy() async {
    try {
      await _client
          .from('hotel_pms_config')
          .select('property_id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retries [fn] up to [_kMaxRetries] times on transient ClientException
  /// ("Failed to fetch" / network errors). Waits [_kRetryBaseDelay] * attempt
  /// between each attempt. Throws the last error if all retries fail.
  Future<T> _withRetry<T>(Future<T> Function() fn, {String label = ''}) async {
    Object? lastError;
    for (int attempt = 0; attempt <= _kMaxRetries; attempt++) {
      try {
        return await fn();
      } catch (e) {
        lastError = e;
        final isTransient = e.toString().contains('Failed to fetch') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('503') ||
            e.toString().contains('PGRST002');
        if (!isTransient || attempt == _kMaxRetries) rethrow;
        final delay = _kRetryBaseDelay * (attempt + 1);
        debugPrint('[PmsSyncService] Retry ${attempt + 1}/$_kMaxRetries for $label in ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
      }
    }
    throw lastError!;
  }

  /// Stops the automatic polling loop.
  void stopPeriodicSync() {
    if (_periodicTimer != null) {
      _periodicTimer!.cancel();
      _periodicTimer = null;
      debugPrint('[PmsSyncService] Auto-sync loop stopped.');
    }
    _lastSeenModifiedAt.clear();
    _lastSeenStatus.clear();
    _deltaWatermark = null; // Reset so next session starts fresh with cold-start
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

      // Fetch existing rooms WITH type+floor so we can detect actual changes.
      // Previously we ran UPDATE for every room every time — now we only write
      // rows where something actually changed, making idle cycles 0-write.
      final existingRows = await _client
          .from('rooms')
          .select('room_id, room_number, type, floor')
          .eq('property_id', propertyId);

      // room_number → { room_id, type, floor }
      final Map<String, Map<String, dynamic>> existingMap = {
        for (final r in (existingRows as List))
          if (r['room_number'] != null)
            r['room_number'].toString(): r as Map<String, dynamic>,
      };

      int upsertedCount = 0;
      int skippedCount = 0;
      final List<Map<String, dynamic>> newRoomsToInsert = [];

      for (final r in rooms) {
        if (r.roomNumber.isEmpty) continue;
        final existing = existingMap[r.roomNumber];
        final roomType = r.categoryName ?? (r.categoryCode.isNotEmpty ? r.categoryCode : 'Standard');

        if (existing != null) {
          final roomId = existing['room_id'] as String;
          final storedType = existing['type'] as String? ?? '';
          final storedFloor = existing['floor']?.toString();
          final incomingFloor = r.floor?.toString();

          // ⚡ CHANGE DETECTION: only UPDATE if type or floor actually changed
          final typeChanged = storedType != roomType;
          final floorChanged = r.floor != null && storedFloor != incomingFloor;

          if (typeChanged || floorChanged) {
            await _client.from('rooms').update({
              'type': roomType,
              if (r.floor != null) 'floor': r.floor,
              'is_active': true,
            }).eq('room_id', roomId);
            upsertedCount++;
          } else {
            skippedCount++; // Nothing changed — skip this room entirely (0 DB write)
          }
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

      debugPrint('[PmsSyncService] Physical rooms: $upsertedCount updated/inserted, $skippedCount unchanged (skipped).');
      return upsertedCount;
    } catch (e) {
      debugPrint('[PmsSyncService] Failed to sync physical rooms: $e');
      return 0;
    }
  }

  /// Ingests live reservations from the hotel's configured PMS into Concigo Supabase.
  ///
  /// ROOT CAUSE FIX: Apaleo does NOT return CheckedOut reservations when no date window
  /// is provided (it defaults to upcoming/active). We now always pass a date window and
  /// do a separate targeted fetch for recent CheckedOut reservations (past 48 h) so that
  /// PMS checkouts are never silently missed.
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

      // ── DELTA SYNC ALGORITHM ──────────────────────────────────────────────────
      // COLD START: _deltaWatermark is null on first run or after stopPeriodicSync().
      //   → Do a full Stay-window fetch (today-2d to today+30d) to build the baseline.
      //   → This happens ONCE per admin session.
      //
      // DELTA CYCLES: _deltaWatermark is set after each successful cycle.
      //   → Fetch ONLY reservations modified since the watermark (dateFilter=Modification).
      //   → With 1 hotel + idle guests, this returns 0-1 records.
      //   → 0-1 records = 0-1 DB upserts vs previous 510 per cycle.
      final now = DateTime.now();
      final List<CanonicalReservation> allReservations;

      final bool isColdStart = _deltaWatermark == null || from != null;

      if (isColdStart) {
        // ── COLD START: Full baseline fetch ────────────────────────────────────
        debugPrint('[PmsSyncService] 🔁 COLD START — fetching full reservation window...');
        final effectiveFrom = from ?? now.subtract(const Duration(days: 2));
        final effectiveTo = to ?? now.add(const Duration(days: 30));

        final baseFetch = await context.adapter.fetchReservations(
          propertyCode: context.propertyCode,
          from: effectiveFrom,
          to: effectiveTo,
          dateFilter: 'Stay',
        );
        allReservations = baseFetch;
        debugPrint('[PmsSyncService] Cold start fetched ${allReservations.length} reservations.');
      } else {
        // ── DELTA CYCLE: Modification-filter fetch since last watermark ─────────
        // Subtract 30 seconds from watermark as a safety overlap to avoid
        // missing records modified exactly at the boundary (clock skew).
        final deltaFrom = _deltaWatermark!.subtract(const Duration(seconds: 30));
        debugPrint('[PmsSyncService] ⚡ DELTA SYNC — fetching changes since ${deltaFrom.toUtc().toIso8601String()}...');

        final deltaFetch = await context.adapter.fetchReservations(
          propertyCode: context.propertyCode,
          from: deltaFrom,
          to: now.add(const Duration(minutes: 5)), // small future buffer
          dateFilter: 'Modification',
        );
        allReservations = deltaFetch;
        debugPrint('[PmsSyncService] ⚡ DELTA SYNC — ${allReservations.length} reservations changed since last sync.');

        // If nothing changed, short-circuit immediately — no DB work needed.
        if (allReservations.isEmpty) {
          _deltaWatermark = now;
          _isSyncing = false;
          return const PmsSyncResult(isSuccess: true, totalFetched: 0, totalSynced: 0);
        }
      }


      debugPrint('[PmsSyncService] Fetched ${allReservations.length} total reservations from PMS.');

      int skippedCount = 0;
      for (final res in allReservations) {
        try {
          // Fast path: skip unchanged Ended reservations (cache hit, no DB work)
          if (res.pmsModifiedAt != null && res.pmsReservationId.isNotEmpty) {
            final cachedMod = _lastSeenModifiedAt[res.pmsReservationId];
            final cachedStatus = _lastSeenStatus[res.pmsReservationId];
            if (cachedMod != null &&
                cachedMod.isAtSameMomentAs(res.pmsModifiedAt!) &&
                cachedStatus == 'Ended') {
              skippedCount++;
              continue;
            }
          }

          await _withRetry(
            () => _ingestSingleReservation(
              propertyId: propertyId,
              res: res,
            ),
            label: res.bookingReference,
          );

          // Update cache after successful ingest
          if (res.pmsReservationId.isNotEmpty) {
            if (res.pmsModifiedAt != null) {
              _lastSeenModifiedAt[res.pmsReservationId] = res.pmsModifiedAt!;
            }
            final concigoStatus = (res.status == 'Canceled' || res.status == 'CheckedOut')
                ? 'Ended'
                : (res.status == 'InHouse' ? 'Active' : 'Upcoming');
            _lastSeenStatus[res.pmsReservationId] = concigoStatus;
          }
          syncedCount++;
        } catch (e) {
          errorCount++;
          debugPrint('[PmsSyncService] Failed to ingest reservation ${res.bookingReference}: $e');
        }
      }

      if (skippedCount > 0) {
        debugPrint('[PmsSyncService] ⚡ Skipped $skippedCount unchanged/Ended reservations (cache hit).');
      }

      _lastSyncTime = DateTime.now();
      _deltaWatermark = now; // ⚡ Advance watermark — next cycle fetches ONLY changes after this point
      return PmsSyncResult(
        isSuccess: true,
        totalFetched: allReservations.length,
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

          // Guard 1: If Concigo stay is Ended and PMS is NOT Ended → prevent resurrection
          if (existingStayStatus == 'Ended' && stayStatus != 'Ended') {
            debugPrint('[PmsSyncService] Reservation ${res.pmsReservationId} was checked out in Concigo (Ended). Skipping resurrection.');
            return;
          }

          // Guard 2 (fast path): If BOTH are Ended → stay already synced, skip expensive DB ops
          if (existingStayStatus == 'Ended' && stayStatus == 'Ended') {
            debugPrint('[PmsSyncService] Reservation ${res.pmsReservationId} already Ended in both PMS and Concigo. Skipping.');
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

      // If stay ended (checked out in PMS), release assigned room(s) and cascade cancel open service requests
      if (stayStatus == 'Ended') {
        final linkedStayRooms = await _client
            .from('stay_rooms')
            .select('room_id')
            .eq('stay_id', stayId);
        for (final sr in (linkedStayRooms as List)) {
          final rid = sr['room_id']?.toString();
          if (rid != null && rid.isNotEmpty) {
            await _client.from('rooms').update({
              'is_booked': false,
            }).eq('room_id', rid);
          }
        }

        // Void open service orders (food/beverage/amenities) so staff do not prepare for departed guests
        try {
          await _client
              .from('service_orders')
              .update({
                'status': 'cancelled',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('stay_id', stayId)
              .inFilter('status', ['ordered', 'in_progress']);
        } catch (_) {}

        // Cancel open laundry pickup requests
        try {
          await _client
              .from('laundry_requests')
              .update({
                'status': 'cancelled',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('stay_id', stayId)
              .inFilter('status', ['pending', 'assigned']);
        } catch (_) {}
      }
    } else {
      // If the reservation is already Ended/CheckedOut in PMS and not in Concigo, do not create it
      if (stayStatus == 'Ended') {
        return;
      }

      // Clean up orphan Upcoming stays for same guest+date that have NO checkin_request.
      // These are phantom duplicates from earlier sync cycles before PMS-tag linking was in place.
      // Without this, cancellations only fix the PMS-tagged stay but orphans keep showing in the UI.
      if (guestUserId != null) {
        try {
          final orphanStays = await _client
              .from('stay')
              .select('stay_id')
              .eq('hotel_id', propertyId)
              .eq('main_user_id', guestUserId)
              .eq('check_in_date', checkInStr)
              .eq('status', 'Upcoming') as List;

          for (final orphan in orphanStays) {
            final orphanId = orphan['stay_id']?.toString();
            if (orphanId == null) continue;
            final crCheck = await _client
                .from('checkin_requests')
                .select('id')
                .eq('stay_id', orphanId)
                .limit(1) as List;
            if (crCheck.isEmpty) {
              // True orphan — no checkin_request, no PMS link → end it
              await _client.from('stay').update({'status': 'Ended', 'updated_at': DateTime.now().toIso8601String()}).eq('stay_id', orphanId);
              debugPrint('[PmsSyncService] Ended orphan duplicate stay $orphanId for guest $guestUserId on $checkInStr');
            }
          }
        } catch (e) {
          debugPrint('[PmsSyncService] Orphan cleanup (non-fatal): $e');
        }
      }


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
          // FIX: also promote status to 'approved' when stay becomes Active (InHouse in PMS)
          // Previously only 'remark' was updated — checkin_request stayed 'pending' forever
          final crStatusUpdate = <String, dynamic>{
            'remark': pmsTag,
          };
          if (stayStatus == 'Active') {
            crStatusUpdate['status'] = 'approved';
          } else if (stayStatus == 'Ended') {
            crStatusUpdate['status'] = 'cancelled';
          }
          await _client.from('checkin_requests')
              .update(crStatusUpdate)
              .eq('id', existingCr.first['id']);
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

      // Attach to stay_rooms if not already attached.
      // Use .limit(1) instead of .maybeSingle() to tolerate any pre-existing
      // duplicate rows gracefully (avoids PGRST 406 when >1 row matches).
      final existingStayRoomRows = await _client
          .from('stay_rooms')
          .select('id')
          .eq('stay_id', stayId)
          .eq('room_id', roomId)
          .limit(1) as List;

      if (existingStayRoomRows.isEmpty) {
        // No existing link — insert fresh
        await _client.from('stay_rooms').insert({
          'stay_id': stayId,
          'room_id': roomId,
        });
      } else {
        // Already linked — deduplicate any accidental duplicate rows silently.
        // Keep the first row (lowest id) and remove any extras.
        try {
          final allDupes = await _client
              .from('stay_rooms')
              .select('id')
              .eq('stay_id', stayId)
              .eq('room_id', roomId) as List;
          if (allDupes.length > 1) {
            final idsToDelete = allDupes
                .skip(1)
                .map((r) => r['id'] as String)
                .toList();
            await _client
                .from('stay_rooms')
                .delete()
                .inFilter('id', idsToDelete);
            debugPrint('[PmsSyncService] Deduplicated ${idsToDelete.length} extra stay_rooms row(s) for stay $stayId / room $roomId');
          }
        } catch (_) {
          // Non-fatal — dedup failure does not break sync
        }
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
