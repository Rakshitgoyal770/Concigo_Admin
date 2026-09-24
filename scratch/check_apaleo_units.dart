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

  final tokenData = jsonDecode(tokenRes.body);
  final newAccessToken = tokenData['access_token'];

  // Query Apaleo units
  final apaleoRes = await http.get(
    Uri.parse('https://api.apaleo.com/inventory/v1/units?propertyId=BER&pageSize=100'),
    headers: {
      'Authorization': 'Bearer $newAccessToken',
      'Accept': 'application/json',
    },
  );

  print('Status: ${apaleoRes.statusCode}');
  print('Body: ${apaleoRes.body}');
}
