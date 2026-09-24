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

  // 1. Check rooms in Supabase
  final res = await http.get(
    Uri.parse('$supabaseUrl/rest/v1/rooms?property_id=eq.$propertyId&select=*'),
    headers: headers,
  );
  final supaRooms = jsonDecode(res.body) as List;
  print('=== TOTAL ROOMS IN SUPABASE FOR BERLIN: ${supaRooms.length} ===');
  int booked = 0;
  int vacant = 0;
  for (var r in supaRooms) {
    if (r['is_booked'] == true) {
      booked++;
    } else {
      vacant++;
    }
  }
  print('Vacant: $vacant, Booked: $booked');
  print('Vacant rooms: ${supaRooms.where((r) => r['is_booked'] != true).map((r) => r['room_number']).toList()}');

  // 2. Refresh Apaleo token and check /inventory/v1/units
  final configFile = File('lib/services/pms/apaleo_config.json');
  final config = jsonDecode(await configFile.readAsString());
  final clientId = config['client_id'];
  final clientSecret = config['client_secret'];
  final refreshToken = config['refresh_token'];

  final tokenRes = await http.post(
    Uri.parse('https://identity.apaleo.com/connect/token'),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic ' + base64Encode(utf8.encode('$clientId:$clientSecret')),
    },
    body: {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    },
  );

  print('Token refresh status: ${tokenRes.statusCode}');
  if (tokenRes.statusCode == 200) {
    final tokenData = jsonDecode(tokenRes.body);
    final newAccessToken = tokenData['access_token'];
    config['access_token'] = newAccessToken;
    if (tokenData['refresh_token'] != null) {
      config['refresh_token'] = tokenData['refresh_token'];
    }
    await configFile.writeAsString(JsonEncoder.withIndent('  ').convert(config));

    // Test /inventory/v1/units
    final unitsRes = await http.get(
      Uri.parse('https://api.apaleo.com/inventory/v1/units?propertyId=BER&pageSize=100'),
      headers: {
        'Authorization': 'Bearer $newAccessToken',
        'Accept': 'application/json',
      },
    );
    print('Units API status: ${unitsRes.statusCode}');
    if (unitsRes.statusCode == 200) {
      final data = jsonDecode(unitsRes.body);
      print('Apaleo total units count: ${data['count']}, units: ${(data['units'] as List).length}');
    } else {
      print('Units API body: ${unitsRes.body}');
    }
  }
}
