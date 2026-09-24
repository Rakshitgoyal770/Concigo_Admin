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

  // Check stay for user_id fc2a09e8-eecb-4d30-8ee1-5695cc80a267
  final stayRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/stay?main_user_id=eq.fc2a09e8-eecb-4d30-8ee1-5695cc80a267&select=*'),
    headers: headers,
  );
  print('Stays for user fc2a09e8-eecb-4d30-8ee1-5695cc80a267:');
  final list = jsonDecode(stayRes.body) as List;
  for (var s in list) {
    print('Stay ID: ${s['stay_id']}, Hotel: ${s['hotel_id']}, Dates: ${s['check_in_date']} -> ${s['check_out_date']}, Status: ${s['status']}');
  }
}
