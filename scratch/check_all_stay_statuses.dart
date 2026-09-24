import 'dart:convert';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('=== ALL STAYS IN STAY TABLE ===\n');

  final stays = await client
      .from('stay')
      .select('stay_id, hotel_id, main_user_id, status, check_in_date, check_out_date, created_at, updated_at')
      .order('created_at', ascending: false)
      .limit(10);

  print('Found ${stays.length} stays:');
  for (final s in stays) {
    print('Stay ID: ${s['stay_id']} | Status: "${s['status']}" | check_in: ${s['check_in_date']} | check_out: ${s['check_out_date']} | main_user_id: ${s['main_user_id']}');
  }
}
