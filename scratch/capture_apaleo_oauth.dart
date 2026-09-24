import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const clientId = 'ZIKG-AC-CONCIGOAPP';
  const clientSecret = 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo';
  const redirectUri = 'http://localhost:8080/callback';

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  print('===============================================================');
  print('🚀 LOCAL OAUTH LISTENER RUNNING ON http://localhost:8080');
  print('===============================================================');
  print('\n👉 If your redirect URI in Apaleo is set to http://localhost:8080/callback:');
  print('Open this authorization link in your browser:');
  print('https://identity.apaleo.com/connect/authorize?client_id=$clientId&response_type=code&scope=openid%20offline_access%20reservations.read%20reservations.manage%20availability.read%20availability.manage%20folios.read%20folios.manage&redirect_uri=${Uri.encodeComponent(redirectUri)}\n');
  print('Waiting for authorization callback...');

  await for (HttpRequest request in server) {
    final uri = request.uri;
    if (uri.path == '/callback') {
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..headers.contentType = ContentType.html
          ..write('<h1>OAuth Error: $error</h1><p>${uri.queryParameters['error_description']}</p>');
        await request.response.close();
        print('❌ OAuth Error: $error - ${uri.queryParameters['error_description']}');
        continue;
      }

      if (code != null) {
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('<h1>🎉 Authorization Successful!</h1><p>You can close this tab and return to the terminal.</p>');
        await request.response.close();

        print('\n✅ Received Authorization Code: $code');
        print('🔄 Exchanging code for Access Token & Refresh Token...');

        final client = HttpClient();
        final tokenUri = Uri.parse('https://identity.apaleo.com/connect/token');
        final req = await client.postUrl(tokenUri);
        req.headers.set('Content-Type', 'application/x-www-form-urlencoded');

        final bodyData = 'grant_type=authorization_code&client_id=$clientId&client_secret=$clientSecret&redirect_uri=${Uri.encodeComponent(redirectUri)}&code=$code';
        req.add(utf8.encode(bodyData));

        final resp = await req.close();
        final respBody = await resp.transform(utf8.decoder).join();
        print('Token Response ($respBody):');

        if (resp.statusCode == 200) {
          final tokenData = jsonDecode(respBody);
          final accessToken = tokenData['access_token'];
          final refreshToken = tokenData['refresh_token'];
          final expiresIn = tokenData['expires_in'] ?? 3600;

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

          print('\n🎉🎉 SUCCESS! Access Token obtained!');
          print('Access Token: $accessToken');
          print('Refresh Token: $refreshToken');

          // Test live properties endpoint with authorized token
          final propReq = await client.getUrl(Uri.parse('https://api.apaleo.com/inventory/v1/properties'));
          propReq.headers.set('Authorization', 'Bearer $accessToken');
          final propResp = await propReq.close();
          final propBody = await propResp.transform(utf8.decoder).join();
          print('\n🏨 Live Properties Response (${propResp.statusCode}): $propBody');

          // Test live reservations endpoint
          final resReq = await client.getUrl(Uri.parse('https://api.apaleo.com/booking/v1/reservations'));
          resReq.headers.set('Authorization', 'Bearer $accessToken');
          final resResp = await resReq.close();
          final resBody = await resResp.transform(utf8.decoder).join();
          print('\n📅 Live Reservations Response (${resResp.statusCode}): $resBody');
        } else {
          print('❌ Failed to exchange code for token: $respBody');
        }
        break;
      }
    }
  }

  await server.close();
}
