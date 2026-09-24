import 'dart:io';

Future<void> main() async {
  final client = HttpClient();
  final req = await client.openUrl('GET', Uri.parse('https://api.apaleo.com/finance/v1/folios?reservationIds=VISOAOJC-1'));
  final resp = await req.close();
  print('/finance/v1/folios status: ${resp.statusCode}');
}
