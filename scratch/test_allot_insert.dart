import 'dart:convert';
import 'dart:io';

Future<dynamic> request(String method, String urlStr, [dynamic body]) async {
  final client = HttpClient();
  final uri = Uri.parse(urlStr);
  final req = await client.openUrl(method, uri);
  const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc';
  req.headers.set('apikey', key);
  req.headers.set('Authorization', 'Bearer $key');
  req.headers.set('Prefer', 'return=representation');
  if (body != null) {
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode(body));
  }
  final resp = await req.close();
  final respBody = await resp.transform(utf8.decoder).join();
  client.close();
  print('Status code: ${resp.statusCode}');
  print('Body: $respBody');
  if (respBody.isEmpty) return null;
  return jsonDecode(respBody);
}

void main() async {
  const baseUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1';
  final orders = await request('GET', '$baseUrl/service_orders?limit=1');
  print('Real order: $orders');
  if (orders is List && orders.isNotEmpty) {
    final so = orders.first;
    final soId = so['so_id'];
    print('Testing columns on order_allotments for order $soId:');
    // Let's see what happens if we pass room_number as String "100" vs room_number as uuid
    final test1 = await request('POST', '$baseUrl/order_allotments', {
      'orderid': soId,
      'room_number': '100',
    });
  }
}
