import 'dart:convert';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  const stayId = 'bcab419e-d20c-4187-9625-a0c17693afce';
  const propertyId = '1f47276a-8ed2-4cec-9bb7-24cdcc5dedf5';

  print('=== SIMULATING ELIGIBILITY FOR NEW STAY ===\n');

  // Check counts
  final srResp = await client
      .from('stay_rooms')
      .select('rooms(type)')
      .eq('stay_id', stayId);

  final counts = <String, int>{};
  for (final sr in srResp) {
    final cat = (sr['rooms'] as Map)['type']?.toString().trim() ?? '';
    counts[cat] = (counts[cat] ?? 0) + 1;
  }
  print('Stay Room Needs: $counts');

  final offers = await client
      .from('early_late_offers')
      .select('*')
      .eq('property_id', propertyId)
      .eq('type', 'early_in')
      .eq('status', 'active');

  for (final off in offers) {
    final name = off['offer_name'];
    final limit = off['limit'];
    print('Offer: $name -> Limit: $limit');
  }
}
