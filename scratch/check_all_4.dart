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

  final rooms = ['fb6c6c2c-78ae-48bb-8802-8e4eea4cc9f0', 'b005258a-9f6d-4379-8667-e96e09efd17e', 'a052f04a-72a5-4de6-a9b1-7f952f0ae09e', '24ad89d0-bb87-41cd-891b-0ef77331f4e6'];

  for (var rid in rooms) {
    final res = await http.get(
      Uri.parse('$supabaseUrl/rest/v1/stay_rooms?room_id=eq.$rid&select=*,stay(*)'),
      headers: headers,
    );
    print('Room $rid stay_rooms:');
    print(res.body);
  }
}
