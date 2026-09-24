import 'dart:convert';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('=== DEEP INSPECTION OF UPCOMING STAYS & ROOMS ===\n');

  // 1. Fetch recent/upcoming stays from 'stay'
  final stays = await client
      .from('stay')
      .select('*')
      .order('created_at', ascending: false)
      .limit(5);

  print('Found ${stays.length} recent stays:');
  for (final s in stays) {
    final stayId = s['stay_id'];
    print('\n============================================================');
    print('Stay ID: $stayId');
    print('Status: ${s['status']} | Check-In: ${s['check_in']} | Check-Out: ${s['check_out']}');
    print('All Columns in stay row: $s');

    // 2. Fetch stay_rooms for this stay
    final stayRooms = await client
        .from('stay_rooms')
        .select('*')
        .eq('stay_id', stayId);

    print('Stay Rooms count in DB: ${stayRooms.length}');
    for (int i = 0; i < stayRooms.length; i++) {
      final sr = stayRooms[i];
      final roomId = sr['room_id'];
      final r = await client.from('rooms').select('*').eq('room_id', roomId).maybeSingle();
      String catName = 'Unknown';
      if (r != null && r['room_category_id'] != null) {
        final cat = await client.from('room_categories').select('*').eq('category_id', r['room_category_id']).maybeSingle();
        catName = cat?['category_name'] ?? 'Unknown';
      }
      print('   [$i] stay_room_id: ${sr['stay_room_id']} | room_id: $roomId | room_number: ${r?['room_number']} | category_id: ${r?['room_category_id']} | category: $catName');
    }
  }
}
