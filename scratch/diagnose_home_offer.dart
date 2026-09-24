import 'dart:convert';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  print('=== DIAGNOSING ACTIVE & UPCOMING STAYS FOR CONCIGO RESORTS ===\n');

  // Fetch recent active stays
  final stays = await client
      .from('stay')
      .select('*')
      .eq('status', 'Active')
      .order('created_at', ascending: false);

  print('Found ${stays.length} active stays:');
  for (final s in stays) {
    final stayId = s['stay_id'];
    final hotelId = s['hotel_id'];
    print('\nStay ID: $stayId | hotel_id: $hotelId | check_in: ${s['check_in_date']} | check_out: ${s['check_out_date']}');

    // 1. Fetch assigned rooms for this stay
    final srResp = await client
        .from('stay_rooms')
        .select('room_id, rooms(room_id, room_number, type)')
        .eq('stay_id', stayId);

    print('Assigned stay_rooms count: ${(srResp as List).length}');
    final categoryCounts = <String, int>{};
    for (final sr in srResp) {
      final rMap = sr['rooms'] as Map<String, dynamic>?;
      final cat = rMap?['type']?.toString().trim() ?? 'Standard';
      final rNum = rMap?['room_number']?.toString();
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      print('   - Room $rNum | Category: "$cat"');
    }

    // 2. Fetch early_late_offers for this hotel
    final offers = await client
        .from('early_late_offers')
        .select('*')
        .eq('property_id', hotelId)
        .eq('type', 'early_in')
        .eq('status', 'active');

    print('Active early_in offers count: ${offers.length}');
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

    print('\nChecking Category Matches for Stay:');
    bool allMatched = true;
    for (final entry in categoryCounts.entries) {
      final cat = entry.key;
      final count = entry.value;
      final matched = categoryOfferMap[cat.toLowerCase()];
      if (matched == null) {
        print('   ❌ MISMATCH! Category "$cat" has NO active offer in early_late_offers! (Looking for "[${cat.toLowerCase()}]")');
        allMatched = false;
      } else {
        print('   ✅ MATCH! Category "$cat" matches offer: "${matched['offer_name']}"');
      }
    }

    if (allMatched) {
      print('\n🎉 All room categories matched successfully!');
    } else {
      print('\n❌ Stay is INELIGIBLE because at least one room category is missing an offer!');
    }
  }
}
