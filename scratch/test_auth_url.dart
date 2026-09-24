import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final client = HttpClient();

  final urls = {
    'With offline_access':
        'https://identity.apaleo.com/connect/authorize?client_id=ZIKG-AC-CONCIGOAPP&response_type=code&scope=openid%20offline_access%20reservations.read%20reservations.manage%20availability.read%20availability.manage%20folios.read%20folios.manage&redirect_uri=https%3A%2F%2Foauth.pstmn.io%2Fv1%2Fcallback',
    'Without offline_access':
        'https://identity.apaleo.com/connect/authorize?client_id=ZIKG-AC-CONCIGOAPP&response_type=code&scope=openid%20account.manage%20availability.manage%20availability.read%20folios.manage%20folios.read%20invoices.manage%20payments.manage%20reservations.manage%20reservations.read&redirect_uri=https%3A%2F%2Foauth.pstmn.io%2Fv1%2Fcallback',
  };

  for (final entry in urls.entries) {
    final req = await client.getUrl(Uri.parse(entry.value));
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    final hasError = body.contains('Something went wrong') || body.contains('invalid_');
    print('${entry.key}: status ${resp.statusCode}, hasError: $hasError');
    if (hasError) {
      final match = RegExp(r'<div class="lead">(.*?)<\/div>', dotAll: true).firstMatch(body);
      print('  Error details: ${match?.group(1)?.trim()}');
    }
  }
}
