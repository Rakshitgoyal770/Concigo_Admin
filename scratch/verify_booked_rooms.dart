import 'dart:convert';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('=== ROOMS FOR THE 5-ROOM BOOKING ===\n');
  final roomNumbers = ['102', '413', '103', '111', '100'];
  final rooms = await client
      .from('rooms')
      .select('room_id, room_number, type, property_id, is_active, is_booked')
      .inFilter('room_number', roomNumbers);

  for (final r in rooms) {
    print('Room ${r['room_number']}: Type = "${r['type']}" | Room ID: ${r['room_id']} | is_booked: ${r['is_booked']}');
  }

  print('\n=== CHECKING ROOM_CATEGORIES TABLE MATCHES ===\n');
  final cats = await client.from('room_categories').select('*');
  for (final c in cats) {
    print('Category ID: ${c['category_id']} | Name: "${c['category_name']}" | Price: ${c['base_price']}');
  }
}
