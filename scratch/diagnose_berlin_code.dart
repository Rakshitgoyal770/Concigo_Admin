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

  final stayId = '4fdc6870-9e06-48a7-a1e2-478ff5b159d0';
  final userId = 'fc2a09e8-eecb-4d30-8ee1-5695cc80a267';

  // 1. Check stay row
  final stayRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/stay?stay_id=eq.$stayId&select=*'),
    headers: headers,
  );
  print('=== STAY ROW ===');
  print(stayRes.body);

  // 2. Check checkin_requests (used by HomeScreen & GuestCheckinFlowScreen)
  final cirRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/checkin_requests?stay_id=eq.$stayId&select=*'),
    headers: headers,
  );
  print('=== CHECKIN_REQUESTS ROW ===');
  print(cirRes.body);

  // 3. Check check_in_requests (used by old checkin flow & reception)
  final checkInReqsRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/check_in_requests?stay_id=eq.$stayId&select=*'),
    headers: headers,
  );
  print('=== CHECK_IN_REQUESTS ROW ===');
  print(checkInReqsRes.body);

  // 4. Check all checkin_requests for this user
  final userCirRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/checkin_requests?main_user_id=eq.$userId&select=*&order=created_at.desc&limit=5'),
    headers: headers,
  );
  print('=== RECENT CHECKIN_REQUESTS FOR USER ===');
  print(userCirRes.body);

  // 5. Check stays for this user to see their statuses
  final userStaysRes = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/stay?main_user_id=eq.$userId&order=created_at.desc&limit=5&select=*'),
    headers: headers,
  );
  print('=== RECENT STAYS FOR USER ===');
  print(userStaysRes.body);
}
