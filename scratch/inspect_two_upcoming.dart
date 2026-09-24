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

  // Query both stays
  final res1 = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/stay?stay_id=eq.bcab419e-d20c-4187-9625-a0c17693afce&select=*,hotel_property:hotel_id(name),stay_rooms(rooms(room_number))'),
    headers: headers,
  );
  print('Stay bcab419e (Sept 21):');
  print(res1.body);

  final res2 = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/stay?stay_id=eq.4fdc6870-9e06-48a7-a1e2-478ff5b159d0&select=*,hotel_property:hotel_id(name),stay_rooms(rooms(room_number))'),
    headers: headers,
  );
  print('Stay 4fdc6870 (Berlin):');
  print(res2.body);
}
