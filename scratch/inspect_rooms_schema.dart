import 'dart:convert';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('=== ROOMS TABLE SCHEMA & SAMPLES ===\n');

  final rooms = await client.from('rooms').select('*').limit(5);
  for (final r in rooms) {
    print('Room row: $r');
  }

  print('\n=== STAY_ROOMS TABLE SAMPLES ===\n');
  final sr = await client.from('stay_rooms').select('*').limit(5);
  for (final s in sr) {
    print('stay_room row: $s');
  }
}
