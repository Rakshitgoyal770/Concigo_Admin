import 'package:zappyadmin/services/pms/apaleo_service.dart';

Future<void> main() async {
  print('=== TESTING APALEO SERVICE LAYER ===\n');

  final service = ApaleoService.instance;
  await service.init();

  print('1. Testing Token Refresh & Retrieval...');
  final token = await service.getValidAccessToken();
  if (token != null) {
    print('✅ Token Active: ${token.substring(0, 30)}...\n');
  } else {
    print('❌ Failed to get valid token.');
    return;
  }

  print('2. Fetching Hotel Properties from Apaleo...');
  final props = await service.fetchProperties();
  print('✅ Fetched ${props.length} Properties:');
  for (final p in props) {
    print('   - ${p['name']} (${p['code']}) in ${p['location']?['city']}, ${p['location']?['countryCode']}');
  }

  print('\n3. Fetching Active & In-House Reservations...');
  final resList = await service.fetchReservations(statuses: ['InHouse', 'Confirmed']);
  print('✅ Fetched ${resList.length} Active Reservations. First 3 samples:');
  for (int i = 0; i < (resList.length > 3 ? 3 : resList.length); i++) {
    final r = resList[i];
    final guest = r['primaryGuest'];
    final unit = r['unit'];
    print('   [$i] Guest: ${guest?['firstName']} ${guest?['lastName']} | Room: ${unit?['name'] ?? "Unassigned"} | Status: ${r['status']} | Total: ${r['totalGrossAmount']?['amount']} ${r['totalGrossAmount']?['currency']}');
  }
}
