import '../../services/supabase_service.dart';

/// Domain Service for Folios, Billing, Charges & Payment Settlement
class BillingService {
  final SupabaseService _supabaseService;

  BillingService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Fetch full folio & billing details for a stay
  Future<Map<String, dynamic>?> fetchStayBilling(String stayId) async {
    try {
      final response = await _supabaseService.client
          .from('checkout_orders')
          .select()
          .eq('stay_id', stayId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Add extra charge/surcharge to a stay's folio
  Future<void> addSurcharge({
    required String stayId,
    required String chargeName,
    required double amount,
    String? category,
  }) async {
    await _supabaseService.client.from('checkout_orders').insert({
      'stay_id': stayId,
      'order_name': chargeName,
      'amount': amount,
      'category': category ?? 'INCIDENTAL',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Record a payment (Cash, Card, UPI, Room Charge)
  Future<void> recordPayment({
    required String stayId,
    required double amount,
    required String paymentMode,
    String? transactionRef,
  }) async {
    await _supabaseService.client.from('checkout_orders').insert({
      'stay_id': stayId,
      'amount': amount,
      'payment_mode': paymentMode,
      'transaction_ref': transactionRef,
      'status': 'PAID',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Settle and finalize folio billing
  Future<void> settleBilling(String stayId) async {
    await _supabaseService.client.from('checkout_orders').update({
      'status': 'SETTLED',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('stay_id', stayId);
  }
}
