import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // Read full task log to extract refresh_token and access_token
  final logFile = File(r'C:\Users\Rakshit\.gemini\antigravity-ide\brain\76c9e0e1-36e1-46e7-821b-ca6f689014d2\.system_generated\tasks\task-7152.log');
  if (await logFile.exists()) {
    final text = await logFile.readAsString();
    final match = RegExp(r'Token Response \((.*?)\):').firstMatch(text);
    if (match != null) {
      final jsonStr = match.group(1);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr);
        final config = {
          'client_id': 'ZIKG-AC-CONCIGOAPP',
          'client_secret': 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo',
          'redirect_uri': 'https://oauth.pstmn.io/v1/callback',
          'access_token': data['access_token'],
          'refresh_token': data['refresh_token'],
          'expires_in': data['expires_in'],
          'token_type': data['token_type'],
          'updated_at': DateTime.now().toIso8601String(),
        };

        final targetFile = File(r'c:\Users\Rakshit\Desktop\Concigo\Concigo_admin_v2\zappyadmin\lib\services\pms\apaleo_config.json');
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsString(const JsonEncoder.withIndent('  ').convert(config));
        print('✅ Saved Apaleo credentials & Refresh Token to: ${targetFile.path}');
      }
    }
  }
}
