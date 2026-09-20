import 'dart:convert';
import 'dart:io';

Future<dynamic> request(String method, String urlStr, [dynamic body]) async {
  final client = HttpClient();
  final uri = Uri.parse(urlStr);
  final req = await client.openUrl(method, uri);
  const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';
  req.headers.set('apikey', key);
  req.headers.set('Authorization', 'Bearer $key');
  if (body != null) {
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode(body));
  }
  final resp = await req.close();
  final respBody = await resp.transform(utf8.decoder).join();
  client.close();
  if (respBody.isEmpty) return null;
  return jsonDecode(respBody);
}

void main() async {
  const baseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1';
  final schema = await request('GET', '$baseUrl/');
  print('Schema top keys: ${schema?.keys}');
  if (schema?['components'] != null) {
    print('Components keys: ${schema['components']?.keys}');
    if (schema['components']['schemas'] != null) {
      print('order_allotments schema:');
      print(jsonEncode(schema['components']['schemas']['order_allotments']));
    }
  }
}
