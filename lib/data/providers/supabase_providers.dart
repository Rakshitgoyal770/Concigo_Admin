import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../services/stay_service.dart';
import '../services/room_service.dart';
import '../services/guest_service.dart';
import '../services/billing_service.dart';
import '../services/offer_service.dart';
import '../services/bellboy_service.dart';

/// Core Supabase Service Singleton Provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService.instance;
});

/// Current Authenticated Employee Session Provider
final employeeSessionProvider = StateProvider<EmployeeSession?>((ref) {
  return SupabaseService.instance.currentSession;
});

/// Domain Service Providers
final stayServiceProvider = Provider<StayService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return StayService(supabaseService: supabase);
});

final roomServiceProvider = Provider<RoomService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return RoomService(supabaseService: supabase);
});

final guestServiceProvider = Provider<GuestService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return GuestService(supabaseService: supabase);
});

final billingServiceProvider = Provider<BillingService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return BillingService(supabaseService: supabase);
});

final offerServiceProvider = Provider<OfferService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return OfferService(supabaseService: supabase);
});

final bellboyServiceProvider = Provider<BellboyService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return BellboyService(supabaseService: supabase);
});
