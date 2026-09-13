import '../../services/supabase_service.dart';

/// Clean Domain Service for Stays and Reservations
/// Wraps existing queries and logic without modifying backend rules.
class StayService {
  final SupabaseService _supabaseService;

  StayService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Fetch all upcoming stays for the current property with rooms and user profiles
  Future<List<Map<String, dynamic>>> fetchUpcomingStays({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];
    return await _supabaseService.fetchUpcomingStaysWithRooms(propId);
  }

  /// Fetch all active (checked-in) stays with flattened guest and room details
  Future<List<Map<String, dynamic>>> fetchActiveStays({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];
    final rawStays = await _supabaseService.fetchActiveStays(propId);

    final List<Map<String, dynamic>> results = [];
    for (final row in rawStays) {
      final status = (row['status'] as String? ?? '').toLowerCase();
      if (status != 'active' && status != 'checked_in') continue;

      final map = Map<String, dynamic>.from(row);
      final userMap = map['users'] as Map<String, dynamic>?;
      map['guest_name'] = userMap?['name'] ?? 'Guest';
      map['phone_number'] = userMap?['mobile_no'] ?? '';

      final stayRooms = map['stay_rooms'] as List?;
      if (stayRooms != null && stayRooms.isNotEmpty) {
        final sr = stayRooms.first as Map<String, dynamic>;
        map['room_id'] = sr['room_id'] as String?;
        final roomMap = sr['rooms'] as Map<String, dynamic>?;
        map['room_number'] = roomMap?['room_number'] as String? ?? 'N/A';
      } else {
        map['room_id'] = null;
        map['room_number'] = 'N/A';
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

  /// Create upcoming scheduled reservation
  Future<String> createUpcomingStay({
    required String propertyId,
    required String mobileNo,
    required String guestName,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? roomId,
  }) async {
    if (roomId != null && roomId.isNotEmpty && roomId != 'null' && roomId != 'N/A') {
      final isAvail = await checkRoomAvailable(
        roomId: roomId,
        checkInDate: checkInDate,
        checkOutDate: checkOutDate,
      );
      if (!isAvail) {
        throw Exception('Selected room is already booked for these dates.');
      }
    }

    final stayId = await _supabaseService.createUpcomingStay(
      propertyId: propertyId,
      mobileNo: mobileNo,
      guestName: guestName,
      checkInDate: checkInDate,
      checkOutDate: checkOutDate,
    );

    if (roomId != null && roomId.isNotEmpty && roomId != 'null' && roomId != 'N/A') {
      await _supabaseService.client.from('stay_rooms').insert({
        'stay_id': stayId,
        'room_id': roomId,
      });
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

  /// Checkout a stay and release room
  Future<void> checkoutStay({
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
  }
}
