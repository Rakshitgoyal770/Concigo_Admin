import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final headers = {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation',
  };

  final updateRes = await http.patch(
    Uri.parse('$supabaseUrl/rest/v1/hotel_property?property_id=eq.b0000001-0000-0000-0000-000000000001'),
    headers: headers,
    body: jsonEncode({
      'name': 'Grand Hotel Berlin',
      'logo_url': 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1600&q=90',
      'terms_conditions': 'Welcome to Grand Hotel Berlin. Standard European hospitality terms apply.',
      'checkin_time': '15:00:00',
      'checkout_time': '11:00:00',
    }),
  );

  print('Updated Berlin Hotel: ${updateRes.statusCode} ${updateRes.body}');
}
