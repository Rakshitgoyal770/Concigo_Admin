import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Production-grade Apaleo PMS Integration Service.
/// Handles OAuth 2.0 token management (automatic refresh), property synchronization,
/// reservation mapping to stays/guests, digital check-in/out syncing, and folio posting.
class ApaleoService {
  ApaleoService._();
  static final ApaleoService instance = ApaleoService._();

  static const String _tokenUrl = 'https://identity.apaleo.com/connect/token';
  static const String _baseUrl = 'https://api.apaleo.com';

  static const String _clientId = 'ZIKG-AC-CONCIGOAPP';
  static const String _clientSecret = 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo';
  static const String _redirectUri = 'https://oauth.pstmn.io/v1/vscode-callback';

  // Config file path for persistent credentials
  static const String _configPath = 'lib/services/pms/apaleo_config.json';

  String? _accessToken =
      'eyJhbGciOiJSUzI1NiIsImtpZCI6IkQ0NkU1MTc3QUY0ODI0Q0M2NTVDOUREOTFDQTY1QkQ0IiwidHlwIjoiYXQrand0In0.eyJpc3MiOiJodHRwczovL2lkZW50aXR5LmFwYWxlby5jb20iLCJuYmYiOjE3OTAyNTgyNDQsImlhdCI6MTc5MDI1ODI0NCwiZXhwIjoxNzkwMjYxODQ0LCJhdWQiOlsiYXBpIiwiaWRlbnRpdHlfc2VydmVyIiwibm90aWZpY2F0aW9ucyIsImFwYWxlbyJdLCJzY29wZSI6WyJvcGVuaWQiLCJyZXNlcnZhdGlvbnMucmVhZCIsInJlc2VydmF0aW9ucy5tYW5hZ2UiLCJmb2xpb3MucmVhZCIsImZvbGlvcy5tYW5hZ2UiLCJhdmFpbGFiaWxpdHkucmVhZCIsImF2YWlsYWJpbGl0eS5tYW5hZ2UiLCJzZXR1cC5yZWFkIiwic2V0dXAubWFuYWdlIiwib3BlcmF0aW9ucy5jaGFuZ2Utcm9vbS1zdGF0ZSIsIm9mZmxpbmVfYWNjZXNzIl0sImFtciI6WyJwd2QiXSwiY2xpZW50X2lkIjoiWklLRy1BQy1DT05DSUdPQVBQIiwic3ViIjoiZTJiMDljY2UtN2Q3MS00ZDQ1LWJkMGUtOGQ3YjIwMTlhNWI2IiwiYXV0aF90aW1lIjoxNzkwMjU0NTgwLCJpZHAiOiJsb2NhbCIsIm5hbWUiOiJyYWtzaGl0Z295YWw3NzBAZ21haWwuY29tIiwicm9sZSI6IkFjY291bnRBZG1pbiIsImFjY291bnRfY29kZSI6IlpJS0ciLCJzaWQiOiI2MEM4QzlGODQ4M0ZEMThEMDQ2MDY5MDQzRTZGQkU3MyIsImp0aSI6IjZBRURDMzJDNDM4ODQ3MjVBNDExNTM3MjhDNEFGMDdCIiwiYWNjb3VudF90eXBlIjoiRGV2ZWxvcG1lbnQifQ.Tou55CKvX8_bKoQpJ1trYRp9WA7U0Fn_2UZz27xgW-ryzqme4-ccBzpUH1vQQVUvsIRCvbRG2qLuGe-WNGDhvj6nJTW3sMKAuWHyy1IXhdEsdLdpFkLkJuAPcBZFu_TsfTFCEOYA-2P3TLkn_x7-2V5O6Si1ErThxvjKD_gTsW8ypgzkZx4EC49IdyqDkokvUwUTUSzOAppZ8v9-4X-utNSM9oxfmCoMpfmAdMggvhTN2Ktu0SU6yU8raahLovN6_JchP-4mmVKRjB41YMesqghmVmGa-szPze23rzqsnvWd_ZObdtXh-k5QV_4MdIKeKcuTzgIHQa8GUBC3SF4FZw';
  String? _refreshToken = '08E8C4E15AB6184E598A4EF8D1B42D59FA89FD5F1AD4937678C8C5C3342F0F8D-1';
  DateTime? _expiresAt = DateTime.parse('2026-09-24T20:27:24');

  bool get isConnected => _refreshToken != null && _refreshToken!.isNotEmpty;

  /// Initialize and load saved tokens if available
  Future<void> init() async {
    if (kIsWeb) return;
    try {
      final file = File(_configPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'] ?? _refreshToken;
        if (data['expires_at'] != null) {
          _expiresAt = DateTime.tryParse(data['expires_at']);
        }
      }
    } catch (e) {
      print('[ApaleoService] init error: $e');
    }
  }

  /// Ensure a valid Access Token is active (auto-refreshes if expired)
  Future<String?> getValidAccessToken() async {
    if (_accessToken != null && _expiresAt != null && DateTime.now().isBefore(_expiresAt!.subtract(const Duration(minutes: 2)))) {
      return _accessToken;
    }

    if (_refreshToken == null || _refreshToken!.isEmpty) {
      print('[ApaleoService] No refresh token available.');
      return null;
    }

    try {
      print('[ApaleoService] Refreshing Apaleo Access Token...');
      final resp = await http.post(
        Uri.parse(_tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': _refreshToken!,
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _accessToken = data['access_token'];
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token'];
        }
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

        await _saveConfig();
        print('[ApaleoService] Token successfully refreshed! Valid for ${expiresIn}s');
        return _accessToken;
      } else {
        print('[ApaleoService] Refresh token failed: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      print('[ApaleoService] Error refreshing token: $e');
    }
    return null;
  }

  Future<void> _saveConfig() async {
    if (kIsWeb) return;
    try {
      final file = File(_configPath);
      await file.parent.create(recursive: true);
      final config = {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'redirect_uri': _redirectUri,
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
        'expires_at': _expiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(config));
    } catch (_) {}
  }

  /// 1. Fetch All Hotel Properties from Apaleo
  Future<List<Map<String, dynamic>>> fetchProperties() async {
    final token = await getValidAccessToken();
    if (token == null) throw Exception('Apaleo is not authenticated.');

    final resp = await http.get(
      Uri.parse('$_baseUrl/inventory/v1/properties'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final list = (data['properties'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return list;
    }
    throw Exception('Failed to fetch properties: ${resp.statusCode} ${resp.body}');
  }

  /// 1b. Fetch Room Categories (Unit Groups) for a Property
  Future<List<Map<String, dynamic>>> fetchUnitGroups({required String propertyId}) async {
    final token = await getValidAccessToken();
    if (token == null) throw Exception('Apaleo is not authenticated.');

    final uri = Uri.parse('$_baseUrl/inventory/v1/unit-groups?propertyId=$propertyId&pageSize=100');
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return (data['unitGroups'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    }
    throw Exception('Failed to fetch unit groups: ${resp.statusCode} ${resp.body}');
  }

  /// 1c. Fetch Physical Rooms (Units) for a Property with complete dynamic pagination
  Future<List<Map<String, dynamic>>> fetchUnits({required String propertyId}) async {
    final token = await getValidAccessToken();
    if (token == null) throw Exception('Apaleo is not authenticated.');

    final List<Map<String, dynamic>> allUnits = [];
    int pageNumber = 1;
    const int pageSize = 100;
    int totalCount = 0;

    do {
      final uri = Uri.parse(
        '$_baseUrl/inventory/v1/units?propertyId=$propertyId&pageNumber=$pageNumber&pageSize=$pageSize',
      );
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['units'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        allUnits.addAll(list);
        totalCount = (data['count'] as num?)?.toInt() ?? allUnits.length;
        if (list.length < pageSize || allUnits.length >= totalCount) {
          break;
        }
        pageNumber++;
      } else {
        throw Exception('Failed to fetch units: ${resp.statusCode} ${resp.body}');
      }
    } while (allUnits.length < totalCount);

    return allUnits;
  }

  /// 2. Fetch Live Reservations
  Future<List<Map<String, dynamic>>> fetchReservations({
    String? propertyId,
    DateTime? from,
    DateTime? to,
    List<String>? statuses,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) throw Exception('Apaleo is not authenticated.');

    final params = <String, String>{};
    if (propertyId != null && propertyId.isNotEmpty) params['propertyId'] = propertyId;
    if (from != null) params['from'] = from.toUtc().toIso8601String();
    if (to != null) params['to'] = to.toUtc().toIso8601String();
    if (statuses != null && statuses.isNotEmpty) params['status'] = statuses.join(',');

    final uri = Uri.parse('$_baseUrl/booking/v1/reservations').replace(queryParameters: params.isNotEmpty ? params : null);
    final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final list = (data['reservations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return list;
    }
    throw Exception('Failed to fetch reservations: ${resp.statusCode} ${resp.body}');
  }

  /// 3. Digital Check-In Reservation in Apaleo
  Future<bool> checkInReservation(String reservationId) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    final uri = Uri.parse('$_baseUrl/booking/v1/reservation-actions/$reservationId/check-in');
    final resp = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return resp.statusCode == 200 || resp.statusCode == 204;
  }

  /// 4. Digital Check-Out Reservation in Apaleo
  Future<bool> checkOutReservation(String reservationId) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    final uri = Uri.parse('$_baseUrl/booking/v1/reservation-actions/$reservationId/check-out');
    final resp = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return resp.statusCode == 200 || resp.statusCode == 204;
  }

  /// 5. Post Charge / Upsell (Early Checkin, Late Checkout, In-Room Dining) to Apaleo Folio
  Future<Map<String, dynamic>?> postChargeToFolio({
    required String reservationId,
    required double amount,
    required String currency,
    required String serviceType,
    required String description,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) return null;

    // First fetch primary folio for reservation
    final foliosUri = Uri.parse('$_baseUrl/booking/v1/reservations/$reservationId');
    final resResp = await http.get(foliosUri, headers: {'Authorization': 'Bearer $token'});
    if (resResp.statusCode != 200) return null;

    // Post charge payload to folio charges
    final chargeUri = Uri.parse('$_baseUrl/folio/v1/charges');
    final body = jsonEncode({
      'reservationId': reservationId,
      'amount': {
        'amount': amount,
        'currency': currency,
      },
      'name': description,
      'serviceType': serviceType,
    });

    final chargeResp = await http.post(
      chargeUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (chargeResp.statusCode == 200 || chargeResp.statusCode == 201) {
      return jsonDecode(chargeResp.body) as Map<String, dynamic>?;
    }
    return null;
  }
}
