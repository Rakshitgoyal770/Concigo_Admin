import 'package:flutter/foundation.dart';
import '../../services/supabase_service.dart';
import '../../services/pms/apaleo_service.dart';

/// Clean Domain Service for Stays and Reservations
/// Wraps existing queries and logic without modifying backend rules.
class StayService {
  final SupabaseService _supabaseService;

  StayService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Resolves the PMS hotel code (e.g. 'BER') dynamically from hotel_pms_config
  Future<String> _resolveHotelCode(String propertyId) async {
    try {
      final config = await _supabaseService.client
          .from('hotel_pms_config')
          .select('pms_hotel_code')
          .eq('property_id', propertyId)
          .eq('pms_type', 'apaleo')
          .maybeSingle();
      final code = config?['pms_hotel_code']?.toString();
      if (code != null && code.isNotEmpty) return code;
    } catch (_) {}
    return 'BER';
  }

  /// Fetch all upcoming stays for the current property with rooms and user profiles
  Future<List<Map<String, dynamic>>> fetchUpcomingStays({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];
    final stays = await _supabaseService.fetchUpcomingStaysWithRooms(propId);

    // Resolve PMS metadata for upcoming arrivals
    Map<String, Map<String, dynamic>> pmsResById = {};
    Map<String, Map<String, dynamic>> pmsResByRoom = {};
    try {
      final hotelCode = await _resolveHotelCode(propId);
      final pmsResList = await ApaleoService.instance.fetchReservations(
        propertyId: hotelCode,
        statuses: ['Confirmed', 'InHouse'],
      );
      for (final r in pmsResList) {
        final id = r['id']?.toString() ?? '';
        if (id.isNotEmpty) pmsResById[id] = r;
        final unitName = r['unit']?['name']?.toString() ?? '';
        if (unitName.isNotEmpty) pmsResByRoom[unitName] = r;
      }
    } catch (_) {}

    for (final map in stays) {
      String? pmsResId;
      final crList = map['checkin_requests'] as List?;
      if (crList != null) {
        for (final cr in crList) {
          final rem = (cr as Map)['remark']?.toString() ?? '';
          if (rem.startsWith('PMS:')) {
            pmsResId = rem.replaceFirst('PMS:', '').trim();
            break;
          }
        }
      }

      final roomNum = map['room_number']?.toString();
      Map<String, dynamic>? matchedPms;
      if (pmsResId != null && pmsResById.containsKey(pmsResId)) {
        matchedPms = pmsResById[pmsResId];
      } else if (roomNum != null && pmsResByRoom.containsKey(roomNum)) {
        matchedPms = pmsResByRoom[roomNum];
        pmsResId ??= matchedPms?['id']?.toString();
      }

      if (matchedPms != null) {
        final g = matchedPms['primaryGuest'] as Map<String, dynamic>? ?? {};
        final fName = g['firstName']?.toString().trim() ?? '';
        final lName = g['lastName']?.toString().trim() ?? '';
        final pmsName = '$fName $lName'.trim();
        if (pmsName.isNotEmpty) map['guest_name'] = pmsName;
        final phone = g['phone']?.toString() ?? '';
        if (phone.isNotEmpty) map['mobile_no'] = phone;
        map['pms_reservation_id'] = pmsResId;
      }
    }
    return stays;
  }

  /// Fetch all active (checked-in) stays with flattened guest and room details
  Future<List<Map<String, dynamic>>> fetchActiveStays({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];
    final rawStays = await _supabaseService.fetchActiveStays(propId);

    // Fetch live Apaleo reservations for real-time guest metadata resolution
    Map<String, Map<String, dynamic>> pmsResById = {};
    Map<String, Map<String, dynamic>> pmsResByRoom = {};
    try {
      final hotelCode = await _resolveHotelCode(propId);
      final pmsResList = await ApaleoService.instance.fetchReservations(
        propertyId: hotelCode,
        statuses: ['InHouse', 'Confirmed'],
      );
      for (final r in pmsResList) {
        final id = r['id']?.toString() ?? '';
        if (id.isNotEmpty) pmsResById[id] = r;
        final unitName = r['unit']?['name']?.toString() ?? '';
        if (unitName.isNotEmpty) pmsResByRoom[unitName] = r;
      }
    } catch (_) {}

    final List<Map<String, dynamic>> results = [];
    for (final row in rawStays) {
      final status = (row['status'] as String? ?? '').toLowerCase();
      if (status != 'active' && status != 'checked_in') continue;

      final map = Map<String, dynamic>.from(row);

      final stayRooms = map['stay_rooms'] as List?;
      String? primaryRoomNum;
      if (stayRooms != null && stayRooms.isNotEmpty) {
        final roomNumbers = stayRooms
            .map((sr) {
              final roomMap = (sr as Map<String, dynamic>)['rooms'] as Map<String, dynamic>?;
              return roomMap?['room_number']?.toString();
            })
            .where((n) => n != null && n.isNotEmpty)
            .cast<String>()
            .toList();

        final sr = stayRooms.first as Map<String, dynamic>;
        map['room_id'] = sr['room_id'] as String?;
        map['room_number'] = roomNumbers.isNotEmpty ? roomNumbers.join(', ') : 'N/A';
        map['room_numbers'] = roomNumbers;
        if (roomNumbers.isNotEmpty) primaryRoomNum = roomNumbers.first;
      } else {
        map['room_id'] = null;
        map['room_number'] = 'N/A';
        map['room_numbers'] = <String>[];
      }

      // Check if linked to PMS reservation
      String? pmsResId;
      final crList = map['checkin_requests'] as List?;
      if (crList != null) {
        for (final cr in crList) {
          final rem = (cr as Map)['remark']?.toString() ?? '';
          if (rem.startsWith('PMS:')) {
            pmsResId = rem.replaceFirst('PMS:', '').trim();
            break;
          }
        }
      }

      Map<String, dynamic>? matchedPms;
      if (pmsResId != null && pmsResById.containsKey(pmsResId)) {
        matchedPms = pmsResById[pmsResId];
      } else if (primaryRoomNum != null && pmsResByRoom.containsKey(primaryRoomNum)) {
        matchedPms = pmsResByRoom[primaryRoomNum];
        pmsResId ??= matchedPms?['id']?.toString();
      }

      final userMap = map['users'] as Map<String, dynamic>?;
      if (matchedPms != null) {
        final g = matchedPms['primaryGuest'] as Map<String, dynamic>? ?? {};
        final fName = g['firstName']?.toString().trim() ?? '';
        final lName = g['lastName']?.toString().trim() ?? '';
        final pmsName = '$fName $lName'.trim();
        map['guest_name'] = pmsName.isNotEmpty ? pmsName : (userMap?['name'] ?? 'Guest');
        map['phone_number'] = g['phone']?.toString() ?? userMap?['mobile_no'] ?? '';
        map['pms_reservation_id'] = pmsResId;
      } else {
        map['guest_name'] = userMap?['name'] ?? 'Guest';
        map['phone_number'] = userMap?['mobile_no'] ?? '';
      }

      results.add(map);
    }
    return results;
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

      // 3. Fallback: If no PMS tag found in checkin_requests, find live reservation in Apaleo by assigned room
      if ((pmsResId == null || pmsResId.isEmpty) && validRoomIds.isNotEmpty) {
        try {
          final roomRow = await _supabaseService.client
              .from('rooms')
              .select('room_number, property_id')
              .eq('room_id', validRoomIds.first)
              .maybeSingle();

          final roomNum = roomRow?['room_number']?.toString();
          if (roomNum != null && roomNum.isNotEmpty) {
            final propId = roomRow?['property_id']?.toString() ?? currentPropertyId ?? '';
            final hotelCode = await _resolveHotelCode(propId);
            final activePms = await ApaleoService.instance.fetchReservations(
              propertyId: hotelCode,
              statuses: ['InHouse', 'Confirmed'],
            );
            for (final r in activePms) {
              final unitName = r['unit']?['name']?.toString();
              if (unitName == roomNum) {
                pmsResId = r['id']?.toString();
                debugPrint('[StayService] Dynamic room fallback resolved Apaleo reservation $pmsResId for Room $roomNum');
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('[StayService] Room fallback lookup error: $e');
        }
      }

      if (pmsResId != null && pmsResId.isNotEmpty) {
        debugPrint('[StayService] Triggering Apaleo digital checkout for reservation $pmsResId...');
        final success = await ApaleoService.instance.checkOutReservation(pmsResId);
        if (!success) {
          pmsSyncOk = false;
          pmsSyncError = 'Stay checked out locally. Apaleo PMS sync warning for $pmsResId.';
          debugPrint('[StayService] Apaleo checkout returned false for $pmsResId');
        } else {
          debugPrint('[StayService] Apaleo checkout succeeded for $pmsResId');
        }
      }
    } catch (e) {
      pmsSyncOk = false;
      pmsSyncError = 'Stay checked out locally. PMS sync error: $e';
      debugPrint('[StayService] PMS checkout trigger error: $e');
    }


    return CheckoutResult(localSuccess: true, pmsSynced: pmsSyncOk, pmsWarning: pmsSyncError);
  }
}

/// Result of a checkout operation.
class CheckoutResult {
  final bool localSuccess;
  final bool pmsSynced;
  final String? pmsWarning;

  const CheckoutResult({
    required this.localSuccess,
    required this.pmsSynced,
    this.pmsWarning,
  });
}
