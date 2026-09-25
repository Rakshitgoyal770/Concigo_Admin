import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zappyadmin/services/pms/pms_sync_service.dart';
import 'package:zappyadmin/services/supabase_service.dart';

void main() {
  test('Run full PMS sync for Hotel Berlin', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SupabaseService.initialize();
    final syncService = PmsSyncService.instance;
    final result = await syncService.syncReservations(
      propertyId: 'b0000001-0000-0000-0000-000000000001',
    );
    print('Sync result: isSuccess=${result.isSuccess}, fetched=${result.totalFetched}, synced=${result.totalSynced}, failed=${result.failedCount}, error=${result.errorMessage}');
  });
}
