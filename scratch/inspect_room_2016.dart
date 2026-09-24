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

  // 1. Check room 2.016 in rooms table
  final roomRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/rooms?property_id=eq.$propertyId&room_number=eq.2.016&select=*'),
    headers: headers,
  );
  print('=== ROOM 2.016 IN ROOMS TABLE ===');
  print(roomRes.body);

  final roomList = jsonDecode(roomRes.body) as List;
  if (roomList.isNotEmpty) {
    final roomId = roomList.first['room_id'];
    
    // 2. Check stay_rooms for this roomId
    final srRes = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/stay_rooms?room_id=eq.$roomId&select=*,stay(*)'),
      headers: headers,
    );
    print('=== STAY_ROOMS FOR 2.016 ===');
    print(srRes.body);

    // 3. Test check_room_available RPC
    final today = DateTime.now().toIso8601String().split('T')[0];
    final tmrw = DateTime.now().add(Duration(days: 1)).toIso8601String().split('T')[0];
    final rpcRes = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/rpc/check_room_available'),
      headers: headers,
      body: jsonEncode({
        'p_room_id': roomId,
        'p_check_in': today,
        'p_check_out': tmrw,
        'p_exclude_stay_id': '4fdc6870-9e06-48a7-a1e2-478ff5b159d0',
      }),
    );
    print('=== RPC check_room_available RESULT ===');
    print('${rpcRes.statusCode}: ${rpcRes.body}');
  }
}
