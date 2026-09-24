import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';
  final propertyId = 'b0000001-0000-0000-0000-000000000001';

  final headers = {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
    'Content-Type': 'application/json',
  };

  final rooms = ['1.009', '2.019', '1.008', '1.005', '1.010', '2.005'];

  for (var rNum in rooms) {
    final res = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/rooms?property_id=eq.$propertyId&room_number=eq.$rNum&select=*'),
      headers: headers,
    );
    final roomList = jsonDecode(res.body) as List;
    if (roomList.isEmpty) continue;
    final r = roomList.first;
    final rid = r['room_id'];

    // Check stays
    final srRes = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/stay_rooms?room_id=eq.$rid&select=*,stay(*)'),
      headers: headers,
    );
    print('Room $rNum: is_booked=${r['is_booked']}, stays=${srRes.body}');
  }
}
