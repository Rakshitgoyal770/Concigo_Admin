import 'dart:convert';
import 'dart:io';
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

  // 1. Query Supabase rooms
  final res = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/rooms?property_id=eq.$propertyId&select=*'),
    headers: headers,
  );
  final supaRooms = jsonDecode(res.body) as List;
  print('=== ALL ROOMS IN SUPABASE FOR BERLIN (${supaRooms.length} rooms) ===');
  for (var r in supaRooms) {
    print('Room: ${r['room_number']}, Type: ${r['type']}, is_booked: ${r['is_booked']}, is_active: ${r['is_active']}');
  }

  // 2. Query Apaleo PMS Units API
  final configFile = File('lib/services/pms/apaleo_config.json');
  final config = jsonDecode(await configFile.readAsString());
  final token = config['access_token'];

  final apaleoRes = await http.get(
    Uri.parse('https://api.apaleo.com/inventory/v1/units?propertyId=BER'),
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    },
  );
  if (apaleoRes.statusCode == 200) {
    final apaleoData = jsonDecode(apaleoRes.body);
    final units = apaleoData['units'] as List? ?? [];
    print('\n=== TOTAL UNITS IN APALEO FOR BER (${units.length} units) ===');
    for (var u in units.take(15)) {
      print('Unit: ${u['name']}, UnitGroup: ${u['unitGroupId']}, Status: ${u['status']}');
    }
  } else {
    print('Apaleo units API returned: ${apaleoRes.statusCode} ${apaleoRes.body}');
  }
}
