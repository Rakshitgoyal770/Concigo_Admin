import 'dart:convert';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  const stayId = 'bcab419e-d20c-4187-9625-a0c17693afce';
  print('=== INSPECTING NEW STAY $stayId ===\n');

  final stay = await client.from('stay').select('*').eq('stay_id', stayId).single();
  print('Stay row: $stay');

  final hotelId = stay['hotel_id'];
  print('Hotel ID: $hotelId');

  final srResp = await client
      .from('stay_rooms')
      .select('room_id, rooms(room_id, room_number, type)')
      .eq('stay_id', stayId);

  print('Assigned stay_rooms: ${(srResp as List).length}');
  final categoryCounts = <String, int>{};
  for (final sr in srResp) {
    final rMap = sr['rooms'] as Map<String, dynamic>?;
    final cat = rMap?['type']?.toString().trim() ?? 'Standard';
    final rNum = rMap?['room_number']?.toString();
    categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    print('   - Room $rNum | Category: "$cat"');
  }

  // Fetch active early_in offers for this hotel
  final offers = await client
      .from('early_late_offers')
      .select('*')
      .eq('property_id', hotelId)
      .eq('type', 'early_in')
      .eq('status', 'active');

  print('\nActive early_in offers count for property $hotelId: ${offers.length}');
  final categoryOfferMap = <String, Map<String, dynamic>>{};
  for (final off in offers) {
    final offerName = off['offer_name']?.toString() ?? '';
    print('   - Offer ID: ${off['offer_id']} | Name: "$offerName" | Limit: ${off['limit']} | Price: ${off['price_per_hour']}');
    final match = RegExp(r'^\[(.*?)\]').firstMatch(offerName);
    if (match != null) {
      final catName = match.group(1)?.trim().toLowerCase() ?? '';
      if (catName.isNotEmpty) {
        categoryOfferMap[catName] = off;
      }
    }
  }

  print('\nMatching Categories:');
  for (final entry in categoryCounts.entries) {
    final cat = entry.key;
    final count = entry.value;
    final matched = categoryOfferMap[cat.toLowerCase()];
    if (matched == null) {
      print('   ❌ NO OFFER for category "$cat" (searched: "[${cat.toLowerCase()}]")');
    } else {
      print('   ✅ Matched category "$cat" -> "${matched['offer_name']}" (limit: ${matched['limit']})');
    }
  }
}
