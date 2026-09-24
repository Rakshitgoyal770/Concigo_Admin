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

  // Check hotel_property columns
  final res1 = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/hotel_property?limit=1'),
    headers: headers,
  );
  print('hotel_property sample: ${res1.body}');

  // Check property_images
  final res2 = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/property_images?limit=1'),
    headers: headers,
  );
  print('property_images status: ${res2.statusCode}, sample: ${res2.body}');
}
