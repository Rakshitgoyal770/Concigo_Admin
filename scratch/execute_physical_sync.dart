import 'package:supabase/supabase.dart';
import 'package:zappyadmin/services/pms/pms_sync_service.dart';

void main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  final syncService = PmsSyncService(client);
  const propertyId = 'b0000001-0000-0000-0000-000000000001';

  print('=== STEP 1: DYNAMIC PHYSICAL ROOM INVENTORY SYNC ===');
  final syncedRooms = await syncService.syncPhysicalRooms(propertyId: propertyId);
  print('Synced physical rooms: $syncedRooms');

  print('\n=== STEP 2: VERIFY ROOMS IN SUPABASE ===');
  final countRes = await client
      .from('rooms')
      .select('room_number, floor, type, is_booked')
      .eq('property_id', propertyId)
      .order('room_number', ascending: true);

  print('Total rooms now in Supabase for Berlin: ${countRes.length}');
  print('\nBreakdown of some rooms:');
  for (final r in countRes.take(20)) {
    print('Room ${r['room_number']} | Floor: ${r['floor']} | Type: ${r['type']} | Booked: ${r['is_booked']}');
  }

  print('\n=== STEP 3: RESERVATIONS SYNC ===');
  final resResult = await syncService.syncReservations(propertyId: propertyId);
  print('Reservations synced: success=${resResult.isSuccess}, fetched=${resResult.totalFetched}, synced=${resResult.totalSynced}');
}
