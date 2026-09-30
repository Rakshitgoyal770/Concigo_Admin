import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Starts a local HTTP server on port 8765, opens the Apaleo OAuth URL,
/// catches the redirect automatically, exchanges the code, and saves the token.
void main() async {
  const clientId = 'ZIKG-AC-CONCIGOAPP';
  const clientSecret = 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo';
  const redirectUri = 'http://localhost:8765/callback';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';
  const supabaseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co';

  // Build auth URL with localhost redirect
  final authUrl = Uri.https('identity.apaleo.com', '/connect/authorize', {
    'response_type': 'code',
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'scope': 'openid profile offline_access',
    'state': 'localcli',
  });

  print('=== Apaleo OAuth Token Fetcher ===\n');
  print('1. Open this URL in your browser:\n');
  print(authUrl.toString());
  print('\n2. Log in with Apaleo credentials.');
  print('3. After redirect, this script will catch it automatically.\n');
  print('Waiting for callback on http://localhost:8765/callback ...\n');

  // Start local server
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8765);

  await for (final request in server) {
    final uri = request.requestedUri;
    final code = uri.queryParameters['code'];

    if (code == null) {
      request.response
        ..statusCode = 400
        ..write('No code found in callback URL.')
        ..close();
      continue;
    }

    print('Got code: ${code.substring(0, 20)}...');
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write('<html><body><h2>✅ Code received! Exchanging token...</h2><p>You can close this tab.</p></body></html>')
      ..close();

    // Exchange code directly with Apaleo
    print('Exchanging with Apaleo...');
    final tokenResp = await http.post(
      Uri.parse('https://identity.apaleo.com/connect/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'code': code,
      },
    );

    if (tokenResp.statusCode != 200) {
      print('ERROR from Apaleo: ${tokenResp.statusCode} ${tokenResp.body}');
      await server.close();
      return;
    }

    final tokenData = jsonDecode(tokenResp.body) as Map<String, dynamic>;
    final accessToken = tokenData['access_token'] as String;
    final refreshToken = tokenData['refresh_token'] as String?;
    final expiresIn = (tokenData['expires_in'] as num?)?.toInt() ?? 3600;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String();

    print('✅ Token exchange SUCCESS!');
    print('access_token: ${accessToken.substring(0, 40)}...');
    print('expires_in: ${expiresIn}s');
    print('expires_at: $expiresAt');

    // Persist to Supabase pms_tokens via service_role
    print('\nSaving to Supabase pms_tokens...');
    final upsertResp = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/pms_tokens'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $anonKey',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
      },
      body: jsonEncode({
        'provider': 'apaleo',
        'property_id': 'ZIKG',
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'client_id': clientId,
        'client_secret': clientSecret,
        'expires_at': expiresAt,
        'updated_at': DateTime.now().toIso8601String(),
      }),
    );

    if (upsertResp.statusCode >= 200 && upsertResp.statusCode < 300) {
      print('✅ Token saved to Supabase! App will now connect to Apaleo automatically.');
    } else {
      print('⚠️  DB save failed: ${upsertResp.statusCode} ${upsertResp.body}');
      print('Token is still valid — app can use it from local storage after you paste it in the dialog.');
    }

    await server.close();
    print('\nDone! Hot-restart the admin app to pick up the new token.');
    break;
  }
}
