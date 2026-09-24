import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const clientId = 'ZIKG-AC-CONCIGOAPP';
  const clientSecret = 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo';

  print('=== APALEO SANDBOX CONNECTION TEST ===\n');

  final client = HttpClient();

  try {
    // 1. Request Token
    final tokenUri = Uri.parse('https://identity.apaleo.com/connect/token');
    final req = await client.postUrl(tokenUri);
    req.headers.set('Content-Type', 'application/x-www-form-urlencoded');

    final bodyData = 'grant_type=client_credentials&client_id=$clientId&client_secret=$clientSecret';
    req.add(utf8.encode(bodyData));

    final resp = await req.close();
    final respBody = await resp.transform(utf8.decoder).join();

    if (resp.statusCode != 200) {
      print('❌ OAuth Token Error (${resp.statusCode}): $respBody');
      return;
    }

    final authData = jsonDecode(respBody);
    final accessToken = authData['access_token'];
    print('✅ Token successfully generated! (Expires in: ${authData['expires_in']}s)');

    // Decode JWT payload (without secret verification) to see granted scopes and subject
    final parts = (accessToken as String).split('.');
    if (parts.length >= 2) {
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decodedJson = utf8.decode(base64Url.decode(payload));
      final claims = jsonDecode(decodedJson);
      print('\n🔍 Token Claims & Scopes:');
      print('   - Client ID: ${claims['client_id']}');
      print('   - Scopes Granted: ${claims['scope']}');
      print('   - Account / Sub: ${claims['sub'] ?? claims['account_code'] ?? 'None'}');
    }

    // 2. Test Core Endpoints
    print('\n📡 Testing Resource Endpoints:');
    final endpoints = {
      'Properties': 'https://api.apaleo.com/inventory/v1/properties',
      'Reservations': 'https://api.apaleo.com/booking/v1/reservations',
      'Rate Plans': 'https://api.apaleo.com/rateplan/v1/rate-plans',
      'Account Info': 'https://api.apaleo.com/account/v1/account',
    };

    for (final entry in endpoints.entries) {
      final r = await client.getUrl(Uri.parse(entry.value));
      r.headers.set('Authorization', 'Bearer $accessToken');
      final res = await r.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 200) {
        print('   ✅ [${entry.key}]: 200 OK -> ${body.length > 100 ? body.substring(0, 100) + '...' : body}');
      } else {
        print('   ❌ [${entry.key}]: ${res.statusCode} ${res.reasonPhrase} -> $body');
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
