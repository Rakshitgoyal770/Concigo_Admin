import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final configFile = File('lib/services/pms/apaleo_config.json');
  final config = jsonDecode(await configFile.readAsString());
  
  final clientId = config['client_id'];
  final clientSecret = config['client_secret'];
  final refreshToken = config['refresh_token'];

  // Refresh token
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

  if (tokenRes.statusCode != 200) {
    print('Failed to refresh token: ${tokenRes.statusCode} ${tokenRes.body}');
    return;
  }

  final tokenData = jsonDecode(tokenRes.body);
  final newAccessToken = tokenData['access_token'];
  final newRefreshToken = tokenData['refresh_token'] ?? refreshToken;

  // Save new tokens back to config
  config['access_token'] = newAccessToken;
  config['refresh_token'] = newRefreshToken;
  await configFile.writeAsString(JsonEncoder.withIndent('  ').convert(config));
  print('Token refreshed successfully!');

  // Now query reservations
  final url = Uri.parse('https://api.apaleo.com/booking/v1/reservations?propertyIds=BER&expand=timeSlices,booker,primaryGuest&sort=created:desc');
  final res = await http.get(url, headers: {
    'Authorization': 'Bearer $newAccessToken',
    'Accept': 'application/json',
  });

  if (res.statusCode != 200) {
    print('Failed to get reservations: ${res.statusCode} ${res.body}');
    return;
  }

  final data = jsonDecode(res.body);
  final reservations = data['reservations'] as List;
  print('Found ${reservations.length} total reservations in BER. Latest 5:');

  for (var r in reservations.take(5)) {
    print('-----------------------------------------');
    print('ID: ${r['id']}');
    print('Status: ${r['status']}');
    print('Arrival: ${r['arrival']} Departure: ${r['departure']}');
    print('Booker: ${r['booker']}');
    print('PrimaryGuest: ${r['primaryGuest']}');
  }
}
