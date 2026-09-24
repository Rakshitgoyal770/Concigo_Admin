import 'dart:io';

Future<void> main() async {
  final client = HttpClient();

  // Test PATCH without Content-Type
  final req1 = await client.openUrl('PATCH', Uri.parse('https://api.apaleo.com/inventory/v1/properties/BER'));
  final resp1 = await req1.close();
  print('PATCH without Content-Type -> status: ${resp1.statusCode}');

  // Test PATCH with application/json
  final req2 = await client.openUrl('PATCH', Uri.parse('https://api.apaleo.com/inventory/v1/properties/BER'));
  req2.headers.set('Content-Type', 'application/json');
  final resp2 = await req2.close();
  print('PATCH with application/json -> status: ${resp2.statusCode}');

  // Test PATCH with application/json-patch+json
  final req3 = await client.openUrl('PATCH', Uri.parse('https://api.apaleo.com/inventory/v1/properties/BER'));
  req3.headers.set('Content-Type', 'application/json-patch+json');
  final resp3 = await req3.close();
  print('PATCH with application/json-patch+json -> status: ${resp3.statusCode}');
}
