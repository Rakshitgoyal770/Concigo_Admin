import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const url = 'https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/users?select=user_id,first_name,last_name,mobile_no,email,status&limit=10';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';

  final client = HttpClient();
  final req = await client.getUrl(Uri.parse(url));
  req.headers.set('apikey', anonKey);
  req.headers.set('Authorization', 'Bearer $anonKey');

  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  print('Users response: $body');
}
