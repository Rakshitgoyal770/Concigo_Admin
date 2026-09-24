import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final configFile = File('lib/services/pms/apaleo_config.json');
  final config = jsonDecode(await configFile.readAsString());
  
  final clientId = config['client_id'];
  final clientSecret = config['client_secret'];
  final refreshToken = config['refresh_token'];

  // Try refreshing with explicit scope parameter including setup.read
  final tokenRes = await http.post(
    Uri.parse('https://identity.apaleo.com/connect/token'),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic ' + base64Encode(utf8.encode('$clientId:$clientSecret')),
    },
    body: {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'scope': 'openid reservations.read reservations.manage folios.read folios.manage availability.read availability.manage setup.read setup.manage offline_access',
    },
  );

  print('Refresh with scope status: ${tokenRes.statusCode}');
  print('Refresh response: ${tokenRes.body}');

  if (tokenRes.statusCode == 200) {
    final tokenData = jsonDecode(tokenRes.body);
    final token = tokenData['access_token'];

    // Check payload of JWT
    final parts = token.split('.');
    if (parts.length == 3) {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      print('Token scopes: ${payload['scope']}');
    }

    // Now test /inventory/v1/units
    final unitsRes = await http.get(
      Uri.parse('https://api.apaleo.com/inventory/v1/units?propertyId=BER&pageSize=100'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    print('Units API response: ${unitsRes.statusCode} ${unitsRes.body}');
  }
}
