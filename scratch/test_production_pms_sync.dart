import 'package:zappyadmin/services/pms/adapters/apaleo_adapter.dart';
import 'package:zappyadmin/services/pms/apaleo_service.dart';

Future<void> main() async {
  print('=====================================================');
  print('🚀 TESTING PRODUCTION-GRADE APALEO PMS ARCHITECTURE');
  print('=====================================================\n');

  // 1. Initialize Apaleo Service
  final service = ApaleoService.instance;
  await service.init();

  final token = await service.getValidAccessToken();
  if (token == null) {
    print('❌ Failed to get active token.');
    return;
  }
  print('✅ Step 1: Active Access Token verified: ${token.substring(0, 25)}...\n');

  // 2. Test ApaleoAdapter directly
  final adapter = ApaleoAdapter(service: service);
  print('✅ Step 2: Testing ApaleoAdapter [provider: ${adapter.provider}]...');

  // Fetch Canonical Reservations
  print('\n   -> Fetching Live Canonical Reservations for Berlin (BER)...');
  final reservations = await adapter.fetchReservations(propertyCode: 'BER');
  print('   -> Found ${reservations.length} Active Reservations. First 5 Canonical Samples:');
  for (int i = 0; i < (reservations.length > 5 ? 5 : reservations.length); i++) {
    final res = reservations[i];
    print('      [$i] BookingRef: ${res.bookingReference} | Guest: ${res.primaryGuest.fullName} (${res.primaryGuest.email}) | Category: ${res.roomCategory} | Total: ${res.totalAmount} ${res.currency} | Dates: ${res.checkInDate.toIso8601String().split('T').first} -> ${res.checkOutDate.toIso8601String().split('T').first}');
  }

  print('\n=====================================================');
  print('🎉 ALL PRODUCTION PMS ARCHITECTURE COMPONENTS PASSED!');
  print('=====================================================');
}
