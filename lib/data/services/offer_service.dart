import '../../services/supabase_service.dart';

/// Domain Service for Offers, Packages, and Room Upgrades
class OfferService {
  final SupabaseService _supabaseService;

  OfferService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Fetch active promotional stay offers
  Future<List<Map<String, dynamic>>> fetchActiveOffers({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];
    return await _supabaseService.fetchActiveStayOffers(propId);
  }

  /// Create a new promotional offer / package
  Future<void> createOffer(Map<String, dynamic> offerData) async {
    await _supabaseService.client.from('active_stay_offers').insert(offerData);
  }

  /// Delete / deactivate an offer
  Future<void> deleteOffer(String offerId) async {
    await _supabaseService.client.from('active_stay_offers').delete().eq('offer_id', offerId);
  }

  /// Fetch pending and processed room upgrade offers
  Future<List<Map<String, dynamic>>> fetchRoomUpgrades({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];
    return await _supabaseService.fetchUpgradeOffers(propId);
  }

  /// Update upgrade status
  Future<void> updateRoomUpgradeStatus({
    required String upgradeId,
    required String status,
  }) async {
    await _supabaseService.client.from('room_upgrade_offers').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('offer_id', upgradeId);
  }
}
