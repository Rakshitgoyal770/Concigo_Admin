import '../../services/supabase_service.dart';

/// Domain Service for Rooms, Room Statuses, and Inventory
class RoomService {
  final SupabaseService _supabaseService;

  RoomService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Fetch all rooms for current property
  Future<List<Map<String, dynamic>>> fetchRooms({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];
    return await _supabaseService.fetchRooms(propId);
  }

  /// Update room operational status (Vacant, Occupied, Needs Cleaning, Maintenance)
  Future<void> updateRoomStatus(String roomId, String status) async {
    final isBooked = status.toLowerCase() == 'occupied';
    await _supabaseService.updateRoomBookingStatus(roomId, isBooked);
  }

  /// Update room booking status (Available / Booked)
  Future<void> updateRoomBookingStatus(String roomId, bool isBooked) async {
    await _supabaseService.updateRoomBookingStatus(roomId, isBooked);
  }
}
