import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/function_region.dart';
import '../../services/supabase_service.dart';

/// What happened when staff added a charge or recorded a payment.
///
/// The bill is saved in Concigo first (that is the guest's record). Posting it
/// to the hotel's PMS is a second step that can fail on its own, so the UI is
/// told about each separately instead of always showing "success".
class BillingResult {
  /// Saved in Concigo.
  final bool saved;

  /// Posted to the PMS folio. `null` when the stay has no PMS reservation.
  final bool? pmsPosted;
  final String? pmsError;

  /// Payments only: how many bills this payment fully settled, and what is left.
  final int billsSettled;
  final double stillDue;

  const BillingResult({
    required this.saved,
    this.pmsPosted,
    this.pmsError,
    this.billsSettled = 0,
    this.stillDue = 0,
  });

  bool get pmsFailed => pmsPosted == false;
}

/// Domain Service for Folios, Billing, Charges & Payment Settlement
class BillingService {
  final SupabaseService _supabaseService;

  BillingService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  SupabaseClient get _client => _supabaseService.client;
  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Fetch full folio & billing details for a stay
  Future<Map<String, dynamic>?> fetchStayBilling(String stayId) async {
    try {
      final response = await _client
          .from('checkout_orders')
          .select()
          .eq('stay_id', stayId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[BillingService] fetchStayBilling failed: $e');
      return null;
    }
  }

  /// Calls push-charges-to-pms. Returns null on success, else the reason.
  Future<String?> _pushToPms(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(
        'push-charges-to-pms',
        queryParameters: kFunctionRegion,
        body: body,
      );
      final data = res.data;
      if (data is Map && data['success'] == false) {
        return data['error']?.toString() ?? 'The PMS rejected the request.';
      }
      return null;
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map ? (d['error'] ?? d['message'])?.toString() : d?.toString();
      return msg == null || msg.isEmpty ? 'PMS request failed (${e.status}).' : msg;
    } catch (e) {
      return e.toString();
    }
  }

  /// Add an extra charge/surcharge to a stay's folio.
  /// Throws if the charge could not be saved.
  Future<BillingResult> addSurcharge({
    required String stayId,
    required String chargeName,
    required double amount,
    String? category,
  }) async {
    final stayRes = await _client
        .from('stay')
        .select('hotel_id, main_user_id, pms_reservation_id, stay_rooms(rooms(room_number))')
        .eq('stay_id', stayId)
        .maybeSingle();
    if (stayRes == null) throw Exception('Stay not found.');

    var roomNo = '';
    final rooms = stayRes['stay_rooms'];
    if (rooms is List && rooms.isNotEmpty) {
      final room = (rooms.first as Map)['rooms'];
      if (room is Map) roomNo = room['room_number']?.toString() ?? '';
    }

    final inserted = await _client
        .from('service_bills')
        .insert({
          'stay_id': stayId,
          'property_id': stayRes['hotel_id'] ?? currentPropertyId,
          'user_id': stayRes['main_user_id'],
          'room_no': roomNo,
          'amt': amount,
          'charge_category': category ?? 'Incidentals',
          'description': chargeName,
          'payment_status': 'unpaid',
          'service_date': DateTime.now().toIso8601String().split('T').first,
        })
        .select('bill_id')
        .single();

    final hasPms = (stayRes['pms_reservation_id'] ?? '').toString().isNotEmpty;
    if (!hasPms) return const BillingResult(saved: true);

    // Push exactly this charge (not "everything unpushed").
    final err = await _pushToPms({
      'source_type': 'service_bill',
      'source_id': inserted['bill_id'],
      'stay_id': stayId,
    });
    return BillingResult(saved: true, pmsPosted: err == null, pmsError: err);
  }

  /// Record a payment (Cash, Card, UPI).
  ///
  /// The amount is applied to the stay's unpaid bills oldest-first; a bill is
  /// marked paid only when the payment fully covers it (marking every unpaid
  /// bill paid on any payment, however small, was wrong). Anything that does
  /// not cover a whole bill stays due and is reported back.
  /// Throws if nothing could be saved.
  Future<BillingResult> recordPayment({
    required String stayId,
    required double amount,
    required String paymentMode,
    String? transactionRef,
  }) async {
    final bills = await _client
        .from('service_bills')
        .select('bill_id, amt, created_at')
        .eq('stay_id', stayId)
        .eq('payment_status', 'unpaid')
        .isFilter('deleted_at', null)
        .order('created_at', ascending: true);

    var remaining = amount;
    final toSettle = <String>[];
    var due = 0.0;
    for (final b in (bills as List)) {
      final amt = double.tryParse(b['amt'].toString()) ?? 0;
      if (remaining + 0.005 >= amt) {
        toSettle.add(b['bill_id'].toString());
        remaining -= amt;
      } else {
        due += amt;
      }
    }

    if (toSettle.isNotEmpty) {
      await _client.from('service_bills').update({
        'payment_status': 'paid',
        'payment_method': paymentMode,
        'updated_at': DateTime.now().toIso8601String(),
      }).inFilter('bill_id', toSettle);
    }

    final stayRes = await _client.from('stay').select('pms_reservation_id').eq('stay_id', stayId).maybeSingle();
    final hasPms = (stayRes?['pms_reservation_id'] ?? '').toString().isNotEmpty;
    if (!hasPms) {
      return BillingResult(saved: true, billsSettled: toSettle.length, stillDue: due);
    }

    // The receipt doubles as the server's duplicate-payment key, so it is
    // generated once per submission.
    final err = await _pushToPms({
      'source_type': 'payment',
      'stay_id': stayId,
      'amount': amount,
      'currency': 'INR',
      'payment_method': paymentMode,
      'receipt': transactionRef ?? 'ADMIN-PAY-${DateTime.now().millisecondsSinceEpoch}',
    });
    return BillingResult(
      saved: true,
      pmsPosted: err == null,
      pmsError: err,
      billsSettled: toSettle.length,
      stillDue: due,
    );
  }
}
