import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';
  final client = SupabaseClient(supabaseUrl, supabaseKey);

  final res = await client
      .from('rooms')
      .select('room_id, room_number, floor, type, is_booked')
      .eq('property_id', 'b0000001-0000-0000-0000-000000000001');

  print('Total rooms in Berlin: ${res.length}');
  print('Sample rooms:');
  for (final r in res.take(15)) {
    print(' - ${r['room_number']} (Floor ${r['floor']}, Type: ${r['type']}, Booked: ${r['is_booked']})');
  }
}
