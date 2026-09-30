import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const code = 'E6049562DBD7D910CCD208E33F31CF027563224DDE35411187E8680D3242D0B0-1';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';
  const proxyUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co/functions/v1/apaleo-token';

  // Try exchange via edge function
  print('=== Trying edge function exchange ===');
  final resp = await http.post(
    Uri.parse(proxyUrl),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $anonKey',
      'apikey': anonKey,
    },
    body: jsonEncode({'action': 'exchange', 'code': code}),
  );
  print('Status: ${resp.statusCode}');
  print('Body: ${resp.body}');

  if (resp.statusCode == 200) {
    final data = jsonDecode(resp.body);
    print('\n=== SUCCESS ===');
    print('access_token: ${(data['access_token'] as String?)?.substring(0, 40)}...');
    print('expires_at: ${data['expires_at']}');
  } else {
    // Try direct Apaleo token endpoint
    print('\n=== Trying direct Apaleo token endpoint ===');
    final directResp = await http.post(
      Uri.parse('https://identity.apaleo.com/connect/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': 'ZIKG-AC-CONCIGOAPP',
        'client_secret': 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo',
        'redirect_uri': 'https://oauth.pstmn.io/v1/vscode-callback',
        'code': code,
      },
    );
    print('Direct Status: ${directResp.statusCode}');
    print('Direct Body: ${directResp.body}');
  }
}
