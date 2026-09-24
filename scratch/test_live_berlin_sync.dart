import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:zappyadmin/services/pms/apaleo_service.dart';
import 'package:zappyadmin/services/pms/pms_sync_service.dart';

void main() {
  test('Live Berlin Sync Test', () async {
    HttpOverrides.global = null;

    print('=====================================================');
    print('🏨 RUNNING LIVE PMS SYNC FOR GRAND HOTEL BERLIN (BER)');
    print('=====================================================\n');

    const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
    const supabaseAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    await ApaleoService.instance.init();

    const berlinPropertyId = 'b0000001-0000-0000-0000-000000000001';

    final syncService = PmsSyncService(client);
    print('Starting PMS sync for Berlin ($berlinPropertyId)...');

    final result = await syncService.syncReservations(
      propertyId: berlinPropertyId,
    );

    print('\n=== SYNC RESULT ===');
    print('Success: ${result.isSuccess}');
    print('Total Reservations Fetched from Apaleo: ${result.totalFetched}');
    print('Total Reservations Synced into Concigo Stays: ${result.totalSynced}');
    print('Failed Count: ${result.failedCount}');
    if (result.errorMessage != null) {
      print('Error: ${result.errorMessage}');
    }

    // Verify stays in Supabase
    final stays = await client
        .from('stay')
        .select('stay_id, check_in_date, check_out_date, status, users(name, mobile_no)')
        .eq('hotel_id', berlinPropertyId)
        .limit(5);

    print('\n=== VERIFIED STAYS IN SUPABASE (First 5) ===');
    for (final s in stays) {
      final user = s['users'] as Map<String, dynamic>?;
      print('• Guest: ${user?['name']} (${user?['mobile_no']}) | Status: ${s['status']} | In: ${s['check_in_date']} -> Out: ${s['check_out_date']}');
    }

    expect(result.isSuccess, isTrue);
    expect(result.totalSynced > 0, isTrue);
    print('\n🎉 LIVE PMS SYNC COMPLETE & VERIFIED IN SUPABASE!');
  });
}
