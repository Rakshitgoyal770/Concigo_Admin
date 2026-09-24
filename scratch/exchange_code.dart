import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart exchange_code.dart <AUTH_CODE_OR_REDIRECT_URL>');
    return;
  }

  String input = args[0];
  String code = input;

  if (input.contains('code=')) {
    final uri = Uri.parse(input);
    code = uri.queryParameters['code'] ?? input;
  }

  print('=== EXCHANGING APALEO AUTH CODE FOR TOKENS ===');
  print('Code: $code\n');

  const clientId = 'ZIKG-AC-CONCIGOAPP';
  const clientSecret = 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo';
  const redirectUri = 'https://oauth.pstmn.io/v1/callback';

  final client = HttpClient();
  final tokenUri = Uri.parse('https://identity.apaleo.com/connect/token');
  final req = await client.postUrl(tokenUri);
  req.headers.set('Content-Type', 'application/x-www-form-urlencoded');

  final bodyData = 'grant_type=authorization_code&client_id=$clientId&client_secret=$clientSecret&redirect_uri=${Uri.encodeComponent(redirectUri)}&code=$code';
  req.add(utf8.encode(bodyData));

  final resp = await req.close();
  final respBody = await resp.transform(utf8.decoder).join();

  if (resp.statusCode != 200) {
    print('❌ Token Exchange Failed (${resp.statusCode}): $respBody');
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

  final configFile = File(r'c:\Users\Rakshit\Desktop\Concigo\Concigo_admin_v2\zappyadmin\lib\services\pms\apaleo_config.json');
  await configFile.parent.create(recursive: true);
  await configFile.writeAsString(const JsonEncoder.withIndent('  ').convert(config));
  print('💾 Saved tokens to: ${configFile.path}');

  print('🎉 SUCCESS! Tokens Generated:');
  print('   - Access Token: ${accessToken.toString().substring(0, 30)}...');
  print('   - Refresh Token: ${refreshToken != null ? refreshToken.toString().substring(0, 30) + "..." : "None"}');
  print('   - Expires in: ${expiresIn}s\n');

  // Test live properties endpoint
  print('🏨 Querying Live Apaleo Properties...');
  final propReq = await client.getUrl(Uri.parse('https://api.apaleo.com/inventory/v1/properties'));
  propReq.headers.set('Authorization', 'Bearer $accessToken');
  final propResp = await propReq.close();
  final propBody = await propResp.transform(utf8.decoder).join();
  print('   Status: ${propResp.statusCode}');
  print('   Properties: $propBody\n');

  // Test live reservations endpoint
  print('📅 Querying Live Apaleo Reservations...');
  final resReq = await client.getUrl(Uri.parse('https://api.apaleo.com/booking/v1/reservations'));
  resReq.headers.set('Authorization', 'Bearer $accessToken');
  final resResp = await resReq.close();
  final resBody = await resResp.transform(utf8.decoder).join();
  print('   Status: ${resResp.statusCode}');
  print('   Reservations: $resBody\n');
}
