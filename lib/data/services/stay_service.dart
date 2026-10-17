import 'package:flutter/foundation.dart';
import '../../services/supabase_service.dart';
import '../../services/pms/pms_factory.dart';

/// Clean Domain Service for Stays and Reservations
/// Wraps existing queries and logic without modifying backend rules.
class StayService {
  final SupabaseService _supabaseService;

  StayService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Fetch all upcoming stays for the current property.
  /// CENTRAL ENGINE: Reads exclusively from v_reception_feed.
  /// The view applies the operational window and phantom guard server-side.
  Future<List<Map<String, dynamic>>> fetchUpcomingStays({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];

    try {
      // Pull the full operational feed from the central view
      final feed = await _supabaseService.fetchReceptionFeed(propId);

      // Filter to Upcoming status only (the view already gates the date window)
      return feed.where((s) {
        final status = (s['status'] as String? ?? '').toLowerCase();
        return status == 'upcoming';
      }).map((s) {
        // Flatten to the shape the UI providers expect
        final map = Map<String, dynamic>.from(s);
        // guest_name comes directly from the view
        map['guest_name'] = s['guest_name'] ?? 'Valued Guest';
        map['phone_number'] = s['guest_phone'] ?? '';
        map['room_number'] = s['room_number'];
        map['pms_reservation_id'] = s['pms_reservation_id'];
        return map;
      }).toList();
    } catch (e) {
      debugPrint('[StayService] fetchUpcomingStays error: $e');
      return [];
    }
  }

  /// Fetch all active (checked-in) stays.
  /// CENTRAL ENGINE: Reads exclusively from v_reception_feed.
  Future<List<Map<String, dynamic>>> fetchActiveStays({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];

    try {
      final feed = await _supabaseService.fetchReceptionFeed(propId);

      // Filter to Active status only
      return feed.where((s) {
        final status = (s['status'] as String? ?? '').toLowerCase();
        return status == 'active';
      }).map((s) {
        final map = Map<String, dynamic>.from(s);
        map['guest_name'] = s['guest_name'] ?? 'Valued Guest';
        map['phone_number'] = s['guest_phone'] ?? '';
        map['room_number'] = s['room_number'];
        map['room_id'] = s['room_id'];
        map['pms_reservation_id'] = s['pms_reservation_id'];
        return map;
      }).toList();
    } catch (e) {
      debugPrint('[StayService] fetchActiveStays error: $e');
      return [];
    }
  }

  /// Activate stay (complete check-in)
  Future<void> activateStay({
    required String stayId,
    required String roomId,
    bool assignRoom = false,
    String? checkinRequestId,
    String? acceptType,
  }) async {
    await _supabaseService.activateStay(
      stayId: stayId,
      roomId: roomId,
      assignRoom: assignRoom,
      checkinRequestId: checkinRequestId,
      acceptType: acceptType,
    );
  }

  /// Check if room is available for dates
  Future<bool> checkRoomAvailable({
    required String roomId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? excludeStayId,
  }) async {
    return await _supabaseService.checkRoomAvailable(
      roomId: roomId,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
      excludeStayId: excludeStayId,
    );
  }

  /// Create upcoming scheduled reservation with single or multiple rooms
  Future<String> createUpcomingStay({
    required String propertyId,
    required String mobileNo,
    required String guestName,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? roomId,
    List<String>? roomIds,
  }) async {
    // Collect all unique room IDs to assign
    final List<String> targetRoomIds = [];
    if (roomIds != null && roomIds.isNotEmpty) {
      targetRoomIds.addAll(
        roomIds.where((r) => r.isNotEmpty && r != 'null' && r != 'N/A'),
      );
    } else if (roomId != null &&
        roomId.isNotEmpty &&
        roomId != 'null' &&
        roomId != 'N/A') {
      targetRoomIds.add(roomId);
    }

    // Validate availability for each selected room
    for (final rid in targetRoomIds) {
      final isAvail = await checkRoomAvailable(
        roomId: rid,
        checkInDate: checkInDate,
        checkOutDate: checkOutDate,
      );
      if (!isAvail) {
        throw Exception('Room ID $rid is already booked for these dates.');
      }
    }

    final stayId = await _supabaseService.createUpcomingStay(
      propertyId: propertyId,
      mobileNo: mobileNo,
      guestName: guestName,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
    );

    // ISSUE-15: Store a MANUAL: tag in checkin_requests so the PMS sync loop
    // can distinguish this booking and never creates a duplicate stay for it.
    try {
      final userId = await _supabaseService.client
          .from('users')
          .select('user_id')
          .eq('mobile_no', mobileNo)
          .maybeSingle();

      await _supabaseService.client.from('checkin_requests').insert({
        'stay_id': stayId,
        if (userId != null) 'main_user_id': userId['user_id'],
        'status': 'pending',
        'remark': 'MANUAL:$stayId',
        'submitted_req': [],
      });
    } catch (_) {
      // Non-fatal — stay is created, tag insertion failure won't break anything
    }

    final uniqueRoomIds = targetRoomIds.toSet().toList();
    if (uniqueRoomIds.isNotEmpty) {
      await _supabaseService.client.from('stay_rooms').insert(
        uniqueRoomIds.map((rid) => {'stay_id': stayId, 'room_id': rid}).toList(),
      );
    }

    return stayId;
  }

  /// Create a new stay (for Walk-In or booking)
  Future<String> createStay({
    required String propertyId,
    required List<String> guestMobiles,
    required List<String> roomIds,
    required DateTime checkInDate,
    required DateTime checkOutDate,
  }) async {
    return await _supabaseService.createStay(
      propertyId: propertyId,
      guestMobiles: guestMobiles,
      roomIds: roomIds,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
    );
  }

  /// Update stay dates (extend stay or modify dates)
  Future<void> updateStayDates({
    required String stayId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
  }) async {
    await _supabaseService.client.from('stay').update({
      'check_in_date': checkInDate.toIso8601String().split('T')[0],
      'check_out_date': checkOutDate.toIso8601String().split('T')[0],
    }).eq('stay_id', stayId);
  }

  /// Checkout a stay and release room.
  /// Returns a [CheckoutResult] indicating local success and optional PMS warning.
  Future<CheckoutResult> checkoutStay({
    required String stayId,
    String? roomId,
  }) async {
    final validRoomIds = <String>[];
    if (roomId != null &&
        roomId.trim().isNotEmpty &&
        roomId != 'null' &&
        roomId != 'N/A') {
      validRoomIds.add(roomId.trim());
    }
    await _supabaseService.checkoutStay(stayId, validRoomIds);

    // Order cascade: Cancel/close open service orders for this departing stay
    int cancelledOrders = 0;
    int closedOrders = 0;
    double unclearedCharges = 0.0;
    try {
      final orderCascade = await _supabaseService.cancelOpenOrdersForStay(
        stayId,
        roomIds: validRoomIds,
      );
      cancelledOrders = (orderCascade['cancelled'] as num?)?.toInt() ?? 0;
      closedOrders = (orderCascade['closed'] as num?)?.toInt() ?? 0;
      unclearedCharges = (orderCascade['uncleared'] as num?)?.toDouble() ?? 0.0;
      debugPrint(
        '[StayService] Checkout order cascade: $cancelledOrders cancelled, $closedOrders closed, ₹$unclearedCharges uncleared',
      );
    } catch (e) {
      debugPrint('[StayService] Order cascade failed (non-fatal): $e');
    }

    // 2-Way PMS synchronization: Check out in Apaleo if linked
    bool pmsSyncOk = true;
    String? pmsSyncError;
    try {
      String? pmsResId;

      // 1. Fetch checkin_requests where remark contains PMS:
      try {
        final crList = await _supabaseService.client
            .from('checkin_requests')
            .select('remark')
            .eq('stay_id', stayId)
            .not('remark', 'is', null)
            .like('remark', 'PMS:%')
            .order('created_at', ascending: false)
            .limit(1);

        if ((crList as List).isNotEmpty) {
          final remark = crList.first['remark']?.toString() ?? '';
          if (remark.startsWith('PMS:')) {
            pmsResId = remark.replaceFirst('PMS:', '').trim();
          }
        }
      } catch (e) {
        debugPrint('[StayService] Error querying checkin_requests for PMS: $e');
      }

      // 2. Fallback: check all checkin_requests for any Apaleo reservation pattern (e.g. 8 chars - number)
      if (pmsResId == null || pmsResId.isEmpty) {
        try {
          final allCr = await _supabaseService.client
              .from('checkin_requests')
              .select('remark')
              .eq('stay_id', stayId);

          for (final row in (allCr as List)) {
            final rem = row['remark']?.toString() ?? '';
            final match = RegExp(r'([A-Z0-9]{8}-\d+)').firstMatch(rem);
            if (match != null) {
              pmsResId = match.group(1);
              break;
            }
          }
        } catch (_) {}
      }

      // 3. Fallback: If no PMS tag found in checkin_requests, find live reservation in PMS by assigned room
      final propId = currentPropertyId ?? '';
      PmsConfigContext? pmsContext;
      if (propId.isNotEmpty) {
        try {
          pmsContext = await PmsFactory.getContextForHotel(
            client: _supabaseService.client,
            propertyId: propId,
          );
        } catch (_) {}
      }

      if ((pmsResId == null || pmsResId.isEmpty) && validRoomIds.isNotEmpty && pmsContext != null) {
        try {
          final roomRow = await _supabaseService.client
              .from('rooms')
              .select('room_number, property_id')
              .eq('room_id', validRoomIds.first)
              .maybeSingle();

          final roomNum = roomRow?['room_number']?.toString();
          if (roomNum != null && roomNum.isNotEmpty) {
            final activePms = await pmsContext.adapter.fetchReservations(
              propertyCode: pmsContext.propertyCode,
              statuses: ['InHouse', 'Confirmed'],
            );
            for (final r in activePms) {
              if (r.assignedRoomNumber == roomNum) {
                pmsResId = r.pmsReservationId;
                debugPrint('[StayService] Dynamic room fallback resolved ${pmsContext.adapter.provider} reservation $pmsResId for Room $roomNum');
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('[StayService] Room fallback lookup error: $e');
        }
      }

      if (pmsResId != null && pmsResId.isNotEmpty) {
        pmsContext ??= propId.isNotEmpty
            ? await PmsFactory.getContextForHotel(
                client: _supabaseService.client,
                propertyId: propId,
              )
            : null;

        if (pmsContext != null) {
          debugPrint('[StayService] Triggering ${pmsContext.adapter.provider} digital checkout for reservation $pmsResId...');
          final success = await pmsContext.adapter.checkOutReservation(pmsReservationId: pmsResId);
          if (!success) {
            pmsSyncOk = false;
            pmsSyncError = 'Stay checked out locally. ${pmsContext.adapter.provider} PMS sync warning for $pmsResId.';
            debugPrint('[StayService] PMS checkout returned false for $pmsResId');
          } else {
            debugPrint('[StayService] PMS checkout succeeded for $pmsResId');
          }
        }
      }
    } catch (e) {
      pmsSyncOk = false;
      pmsSyncError = 'Stay checked out locally. PMS sync error: $e';
      debugPrint('[StayService] PMS checkout trigger error: $e');
    }


    return CheckoutResult(
      localSuccess: true,
      pmsSynced: pmsSyncOk,
      pmsWarning: pmsSyncError,
      cancelledOrderCount: cancelledOrders,
      closedOrderCount: closedOrders,
      unclearedCharges: unclearedCharges,
    );
  }
}

/// Result of a checkout operation.
class CheckoutResult {
  final bool localSuccess;
  final bool pmsSynced;
  final String? pmsWarning;
  final int cancelledOrderCount;
  final int closedOrderCount;
  final double unclearedCharges;

  const CheckoutResult({
    required this.localSuccess,
    required this.pmsSynced,
    this.pmsWarning,
    this.cancelledOrderCount = 0,
    this.closedOrderCount = 0,
    this.unclearedCharges = 0.0,
  });
}
