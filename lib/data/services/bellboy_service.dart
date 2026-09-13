import '../../services/supabase_service.dart';

/// Domain Service for Bellboy & Luggage Pickup / Delivery Management
class BellboyService {
  final SupabaseService _supabaseService;

  BellboyService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Fetch all bellboy / luggage requests for the property
  Future<List<Map<String, dynamic>>> fetchLuggageRequests({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];
    return await _supabaseService.fetchBellboyRequests(propId);
  }

  /// Update luggage request status ('called', 'reached', 'completed')
  Future<void> updateLuggageStatus({
    required String requestId,
    required String status,
    String? assignedTo,
  }) async {
    String dbStatus = status.toLowerCase();
    if (dbStatus == 'in_progress' || dbStatus == 'dispatched' || dbStatus == 'reached') {
      dbStatus = 'reached';
    } else if (dbStatus == 'completed' || dbStatus == 'done') {
      dbStatus = 'completed';
    } else {
      dbStatus = 'called';
    }

    await _supabaseService.client.from('bellboy_calls').update({
      'status': dbStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }
}
