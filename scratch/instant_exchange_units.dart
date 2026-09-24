import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const clientId = 'ZIKG-AC-CONCIGOAPP';
  const clientSecret = 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo';
  const redirectUri = 'https://oauth.pstmn.io/v1/vscode-callback';
  const code = '542AC0925843B7D48E380422E02A1F754E737CE8BD74D4DB8F93A687E0C687E5-1';

  print('=== EXCHANGING APALEO AUTH CODE FOR TOKENS ===');

  final client = HttpClient();
  final tokenUri = Uri.parse('https://identity.apaleo.com/connect/token');
  final req = await client.postUrl(tokenUri);
  req.headers.set('Content-Type', 'application/x-www-form-urlencoded');

  final bodyData = 'grant_type=authorization_code&client_id=$clientId&client_secret=$clientSecret&redirect_uri=${Uri.encodeComponent(redirectUri)}&code=$code';
  req.add(utf8.encode(bodyData));

  final resp = await req.close();
  final respBody = await resp.transform(utf8.decoder).join();

  print('Response status: ${resp.statusCode}');
  print('Response body: $respBody');

  if (resp.statusCode != 200) {
    print('Failed to exchange code');
    return;
  }

  final tokenData = jsonDecode(respBody);
  final accessToken = tokenData['access_token'];
  final refreshToken = tokenData['refresh_token'];
  final expiresIn = tokenData['expires_in'] ?? 3600;

  // Persist to apaleo_config.json
  final config = {
    'client_id': clientId,
    'client_secret': clientSecret,
    'redirect_uri': redirectUri,
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'expires_at': DateTime.now().add(Duration(seconds: (expiresIn as num).toInt())).toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  final configFile = File('lib/services/pms/apaleo_config.json');
  await configFile.writeAsString(const JsonEncoder.withIndent('  ').convert(config));
  print('SUCCESS: Saved new tokens with setup.read to apaleo_config.json!');

  // Now test querying units from Apaleo!
  final unitsReq = await client.getUrl(Uri.parse('https://api.apaleo.com/inventory/v1/units?propertyId=BER&pageSize=150'));
  unitsReq.headers.set('Authorization', 'Bearer $accessToken');
  unitsReq.headers.set('Accept', 'application/json');

  final unitsResp = await unitsReq.close();
  final unitsBody = await unitsResp.transform(utf8.decoder).join();
  print('\n=== UNITS API TEST ===');
  print('Status: ${unitsResp.statusCode}');
  if (unitsResp.statusCode == 200) {
    final unitsData = jsonDecode(unitsBody);
    final count = unitsData['count'];
    final units = unitsData['units'] as List;
    print('SUCCESS! Apaleo returned $count total units in BER!');
    print('Fetched ${units.length} units:');
    for (var u in units.take(15)) {
      print('- ${u['name']} (Group: ${u['unitGroupId']}, Status: ${u['status']})');
    }
  } else {
    print('Units error: $unitsBody');
  }
}
