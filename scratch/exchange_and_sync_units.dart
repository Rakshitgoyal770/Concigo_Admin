import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final configFile = File('lib/services/pms/apaleo_config.json');
  final config = jsonDecode(await configFile.readAsString());
  
  final clientId = config['client_id'];
  final clientSecret = config['client_secret'];
  final redirectUri = 'https://oauth.pstmn.io/v1/vscode-callback';
  final code = '4D47F236DE067E7FA223F58D0A64B74BD61BA1482CBE1A0236EC355947F41731-1';

  print('Exchanging authorization code...');
  final res = await http.post(
    Uri.parse('https://identity.apaleo.com/connect/token'),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic ' + base64Encode(utf8.encode('$clientId:$clientSecret')),
    },
    body: {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
    },
  );

  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');

  if (res.statusCode != 200) {
    print('Failed to exchange code');
    return;
  }

  final data = jsonDecode(res.body);
  final accessToken = data['access_token'];
  final refreshToken = data['refresh_token'];

  config['access_token'] = accessToken;
  config['refresh_token'] = refreshToken;
  config['updated_at'] = DateTime.now().toIso8601String();
  await configFile.writeAsString(JsonEncoder.withIndent('  ').convert(config));
  print('Saved new token to apaleo_config.json!');

  // Now test /inventory/v1/units
  final unitsRes = await http.get(
    Uri.parse('https://api.apaleo.com/inventory/v1/units?propertyId=BER&pageSize=100'),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    },
  );

  print('Units API Status: ${unitsRes.statusCode}');
  if (unitsRes.statusCode == 200) {
    final unitsData = jsonDecode(unitsRes.body);
    final count = unitsData['count'];
    final units = unitsData['units'] as List;
    print('SUCCESS! Apaleo returned $count total units in BER! First 10:');
    for (var u in units.take(10)) {
      print('Room: ${u['name']} (Type: ${u['unitGroupId']}, Status: ${u['status']})');
    }
  } else {
    print('Units API error: ${unitsRes.body}');
  }
}
