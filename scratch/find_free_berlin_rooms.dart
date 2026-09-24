import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final headers = {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
    'Content-Type': 'application/json',
  };

  final propertyId = 'b0000001-0000-0000-0000-000000000001';

  // Get all rooms in Berlin
  final res = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/rooms?property_id=eq.$propertyId&select=*'),
    headers: headers,
  );
  final allRooms = jsonDecode(res.body) as List;
  print('Total rooms in Berlin: ${allRooms.length}');

  final freeRooms = [];
  for (var r in allRooms) {
    final rpcRes = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/rpc/check_room_available'),
      headers: headers,
      body: jsonEncode({
        'p_room_id': r['room_id'],
        'p_check_in': '2026-09-24',
        'p_check_out': '2026-09-26',
        'p_exclude_stay_id': '4fdc6870-9e06-48a7-a1e2-478ff5b159d0',
      }),
    );
    if (rpcRes.body == 'true') {
      freeRooms.add('${r['room_number']} (${r['type']})');
    }
  }

  print('Free rooms for 2026-09-24 -> 2026-09-26:');
  print(freeRooms);
}
