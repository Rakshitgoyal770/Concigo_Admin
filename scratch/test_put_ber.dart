import 'dart:io';

Future<void> main() async {
  final client = HttpClient();
  final req = await client.openUrl('PUT', Uri.parse('https://api.apaleo.com/inventory/v1/properties/BER'));
  final resp = await req.close();
  print('PUT /properties/BER -> status: ${resp.statusCode}');
}
