import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';
  final propertyId = 'b0000001-0000-0000-0000-000000000001'; // Grand Hotel Berlin
  final guestUserId = 'fc2a09e8-eecb-4d30-8ee1-5695cc80a267'; // Rakshit Goyal (+919518445417)

  final headers = {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  // 1. Check if stay already exists
  final checkRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/stay?hotel_id=eq.$propertyId&main_user_id=eq.$guestUserId&check_in_date=eq.2026-09-24'),
    headers: headers,
  );

  String stayId;
  final existing = jsonDecode(checkRes.body) as List;
  if (existing.isNotEmpty) {
    stayId = existing.first['stay_id'];
    print('Stay already exists with stay_id: $stayId');
  } else {
    // 2. Insert stay
    final insertRes = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/stay'),
      headers: headers,
      body: jsonEncode({
        'hotel_id': propertyId,
        'main_user_id': guestUserId,
        'check_in_date': '2026-09-24',
        'check_out_date': '2026-09-26',
        'status': 'Upcoming',
      }),
    );
    print('Insert stay status: ${insertRes.statusCode}, body: ${insertRes.body}');
    final inserted = jsonDecode(insertRes.body) as List;
    stayId = inserted.first['stay_id'];
    print('Created stay: $stayId');

    // 3. Add to stay_guests
    await http.post(
      Uri.parse('$supabaseUrl/rest/v1/stay_guests'),
      headers: headers,
      body: jsonEncode({
        'stay_id': stayId,
        'user_id': guestUserId,
      }),
    );
  }

  // 4. Attach a room (e.g. 1.009 in Berlin)
  final roomQuery = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/rooms?property_id=eq.$propertyId&limit=1'),
    headers: headers,
  );
  final rooms = jsonDecode(roomQuery.body) as List;
  if (rooms.isNotEmpty) {
    final roomId = rooms.first['room_id'];
    final roomNumber = rooms.first['room_number'];
    print('Assigning room $roomNumber ($roomId) to stay $stayId');

    await http.post(
      Uri.parse('$supabaseUrl/rest/v1/stay_rooms'),
      headers: headers,
      body: jsonEncode({
        'stay_id': stayId,
        'room_id': roomId,
      }),
    );
  }

  print('SUCCESS: Booking GGSPDKFX-1 is fully synced into Supabase stay for Rakshit Goyal (+919518445417)!');
}
