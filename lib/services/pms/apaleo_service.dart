import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Production-grade Apaleo PMS Integration Service.
/// Handles OAuth 2.0 token management (automatic refresh), property synchronization,
/// reservation mapping to stays/guests, digital check-in/out syncing, and folio posting.
class ApaleoService {
  ApaleoService._();
  static final ApaleoService instance = ApaleoService._();

  static const String _tokenUrl = 'https://identity.apaleo.com/connect/token';
  static const String _proxyUrl = 'https://qmgrkogxqfqaimtcfvsp.supabase.co/functions/v1/apaleo-token';
  static const String _authUrl = 'https://identity.apaleo.com/connect/authorize';
  static const String _baseUrl = 'https://api.apaleo.com';

  // NOTE: In production, move client credentials to server-side config or
  // environment variables (--dart-define) to avoid exposure in source code.
  static const String _clientId = 'ZIKG-AC-CONCIGOAPP';
  static const String _clientSecret = 'n4cUcFMBSBLpmDge3YzeDW4FqGzBBo';

  // Redirect URI: exact match configured in Apaleo Developer Console
  static const String _redirectUri = 'https://oauth.pstmn.io/v1/vscode-callback';

  // Config file path for native platforms
  static const String _configPath = 'lib/services/pms/apaleo_config.json';
  // SharedPreferences keys for web token persistence
  static const String _kAccessToken = 'apaleo_access_token';
  static const String _kRefreshToken = 'apaleo_refresh_token';
  static const String _kExpiresAt = 'apaleo_expires_at';

  // ── AUTH STATE NOTIFIER ─────────────────────────────────────────
  /// Fires true when token refresh fails so the UI can show a reconnect banner.
  static final ValueNotifier<bool> tokenExpiredNotifier = ValueNotifier(false);
  static final ValueNotifier<String?> tokenErrorMessage = ValueNotifier(null);

  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  /// True only when we have a non-null access token that is not yet expired.
  bool get isConnected {
    if (_accessToken == null || _accessToken!.isEmpty) return false;
    if (tokenExpiredNotifier.value) return false;
    if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) return false;
    return true;
  }

  DateTime? _extractJwtExpiry(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      final exp = (payload['exp'] as num?)?.toInt();
      if (exp != null) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
    } catch (_) {}
    return null;
  }

  /// Initialize and load saved tokens from all available sources.
  /// Priority: SharedPreferences/file → Supabase pms_tokens table.
  Future<void> init() async {
    // 1. Try local storage first (fastest)
    await _loadFromLocalStorage();

    // 2. If still no token, try Supabase pms_tokens table as fallback
    if ((_accessToken == null || _accessToken!.isEmpty) ||
        (_expiresAt != null && DateTime.now().isAfter(_expiresAt!))) {
      await _loadFromSupabase();
    }

    // 3. Parse expiry from JWT if not already set
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      _expiresAt ??= _extractJwtExpiry(_accessToken!);
    }

    debugPrint(
      '[ApaleoService] init complete. Token present: ${_accessToken != null && _accessToken!.isNotEmpty}. '
      'Expires: $_expiresAt. Valid: $isConnected',
    );
  }

  Future<void> _loadFromLocalStorage() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final storedAccess = prefs.getString(_kAccessToken);
        final storedRefresh = prefs.getString(_kRefreshToken);
        if (storedAccess != null && storedAccess.isNotEmpty) _accessToken = storedAccess;
        if (storedRefresh != null && storedRefresh.isNotEmpty) _refreshToken = storedRefresh;
        final expiresAtStr = prefs.getString(_kExpiresAt);
        if (expiresAtStr != null) _expiresAt = DateTime.tryParse(expiresAtStr);
      } else {
        final file = File(_configPath);
        if (await file.exists()) {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          if (data['access_token'] != null) _accessToken = data['access_token']?.toString();
          if (data['refresh_token'] != null) _refreshToken = data['refresh_token']?.toString();
          if (data['expires_at'] != null) _expiresAt = DateTime.tryParse(data['expires_at']?.toString() ?? '');
        }
      }
    } catch (e) {
      debugPrint('[ApaleoService] _loadFromLocalStorage error: $e');
    }
  }

  Future<void> _loadFromSupabase() async {
    try {
      final resp = await http.post(
        Uri.parse(_proxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get_token'}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['access_token'] != null) {
          _accessToken = data['access_token']?.toString();
          if (data['refresh_token'] != null) {
            _refreshToken = data['refresh_token']?.toString();
          }
          final expStr = data['expires_at']?.toString();
          if (expStr != null) _expiresAt = DateTime.tryParse(expStr);
          tokenExpiredNotifier.value = false;
          tokenErrorMessage.value = null;
          await _saveConfig();
          debugPrint('[ApaleoService] Loaded tokens from Edge Function proxy.');
          return;
        }
      }
    } catch (e) {
      debugPrint('[ApaleoService] _loadFromSupabase via proxy (non-fatal): $e');
    }

    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('pms_tokens')
          .select('access_token, refresh_token, expires_at')
          .eq('provider', 'apaleo')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        _accessToken = row['access_token']?.toString();
        _refreshToken = row['refresh_token']?.toString();
        final expStr = row['expires_at']?.toString();
        if (expStr != null) _expiresAt = DateTime.tryParse(expStr);
        debugPrint('[ApaleoService] Loaded tokens from Supabase pms_tokens table.');
        // Immediately write to local storage so next cold-start skips the DB call
        await _saveConfig();
        debugPrint('[ApaleoService] Tokens saved to local storage from Supabase fallback.');
      }
    } catch (e) {
      debugPrint('[ApaleoService] _loadFromSupabase (non-fatal): $e');
    }
  }

  /// Ensures a valid Access Token is active.
  /// Auto-refreshes 2 minutes before expiry. Surfaces errors via [tokenExpiredNotifier].
  Future<String?> getValidAccessToken({bool forceRefresh = false}) async {
    final token = _accessToken;
    final exp = _expiresAt ?? (token != null ? _extractJwtExpiry(token) : null);
    final isExpiringSoon = exp != null && DateTime.now().isAfter(exp.subtract(const Duration(minutes: 2)));

    // If token is fine and not force-refreshing, return immediately
    if (!forceRefresh && !isExpiringSoon && token != null && token.isNotEmpty) {
      return token;
    }

    var refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _loadFromSupabase();
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        final newExp = _expiresAt ?? _extractJwtExpiry(_accessToken!);
        final stillExpiring = newExp != null && DateTime.now().isAfter(newExp.subtract(const Duration(minutes: 2)));
        if (!forceRefresh && !stillExpiring) {
          return _accessToken;
        }
      }
      refreshToken = _refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('[ApaleoService] ❌ No refresh token available. Cannot refresh access token.');
        _setTokenError('Apaleo not connected. Please reconnect via PMS settings.');
        return _accessToken; // return whatever we have (may be null)
      }
    }

    try {
      debugPrint('[ApaleoService] 🔄 Refreshing Apaleo Access Token (forceRefresh=$forceRefresh)...');
      final http.Response resp;
      if (kIsWeb) {
        resp = await http.post(
          Uri.parse(_proxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'refresh',
            'refresh_token': refreshToken,
          }),
        ).timeout(const Duration(seconds: 15));
      } else {
        resp = await http.post(
          Uri.parse(_tokenUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'refresh_token',
            'client_id': _clientId,
            'client_secret': _clientSecret,
            'refresh_token': refreshToken,
          },
        ).timeout(const Duration(seconds: 15));
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _accessToken = data['access_token']?.toString();
        if (data['refresh_token'] != null) {
          _refreshToken = data['refresh_token']?.toString();
        }
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        // ✅ Clear any previous auth error
        tokenExpiredNotifier.value = false;
        tokenErrorMessage.value = null;
        await _saveConfig();
        await _persistTokensToSupabase();
        debugPrint('[ApaleoService] ✅ Token refreshed successfully. Valid for ${expiresIn}s.');
        return _accessToken;
      } else {
        final msg = 'Apaleo token refresh failed (HTTP ${resp.statusCode}). '
            'Response: ${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}';
        debugPrint('[ApaleoService] ❌ $msg');
        _setTokenError(msg);
        return token; // return stale token — caller handles 401
      }
    } catch (e) {
      final msg = 'Apaleo token refresh exception: $e';
      debugPrint('[ApaleoService] ❌ $msg');
      _setTokenError(msg);
      return token;
    }
  }

  void _setTokenError(String message) {
    tokenExpiredNotifier.value = true;
    tokenErrorMessage.value = message;
  }

  /// Persist current tokens to Supabase `pms_tokens` table so server-side
  /// edge functions (cron, webhook) can use them without depending on the admin app.
  Future<void> _persistTokensToSupabase() async {
    if (_accessToken == null || _refreshToken == null) return;
    try {
      final client = Supabase.instance.client;
      await client.from('pms_tokens').upsert({
        'provider': 'apaleo',
        'property_id': 'ZIKG', // account code — updated per-property by sync
        'access_token': _accessToken,
        'refresh_token': _refreshToken,
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'expires_at': _expiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'provider,property_id');
    } catch (e) {
      // Non-fatal: local storage is the primary source
      debugPrint('[ApaleoService] _persistTokensToSupabase (non-fatal): $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      if (kIsWeb) {
        // Web: persist in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        if (_accessToken != null) await prefs.setString(_kAccessToken, _accessToken!);
        if (_refreshToken != null) await prefs.setString(_kRefreshToken, _refreshToken!);
        if (_expiresAt != null) await prefs.setString(_kExpiresAt, _expiresAt!.toIso8601String());
      } else {
        // Native: persist in config file
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
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────
  // OAUTH LOGIN FLOW
  // ─────────────────────────────────────────────────────────────────

  /// Returns the Apaleo authorization URL the user must open in a browser.
  /// After the user approves, Apaleo redirects to [_redirectUri]?code=XXX&state=YYY
  String getAuthorizationUrl({String? state}) {
    final params = {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': 'openid profile offline_access',
      if (state != null) 'state': state,
    };
    return Uri.parse(_authUrl).replace(queryParameters: params).toString();
  }

  /// Exchange an authorization code (received after user logs in) for tokens.
  /// Returns true on success.
  Future<bool> exchangeAuthCode(String code) async {
    try {
      debugPrint('[ApaleoService] Exchanging auth code for tokens...');
      final http.Response resp;
      if (kIsWeb) {
        resp = await http.post(
          Uri.parse(_proxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'exchange',
            'code': code,
          }),
        );
      } else {
        resp = await http.post(
          Uri.parse(_tokenUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'authorization_code',
            'client_id': _clientId,
            'client_secret': _clientSecret,
            'redirect_uri': _redirectUri,
            'code': code,
          },
        );
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;
        _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
        await _saveConfig();
        debugPrint('[ApaleoService] ✅ Auth code exchange successful! Token valid for ${expiresIn}s');
        return true;
      } else {
        debugPrint('[ApaleoService] ❌ Auth code exchange failed: ${resp.statusCode} ${resp.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[ApaleoService] ❌ Auth code exchange error: $e');
      return false;
    }
  }

  /// Clears all stored tokens (disconnect from Apaleo).
  Future<void> disconnect() async {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kAccessToken);
        await prefs.remove(_kRefreshToken);
        await prefs.remove(_kExpiresAt);
      } else {
        final file = File(_configPath);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
    debugPrint('[ApaleoService] Disconnected from Apaleo.');
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
  /// Fetches ALL live reservations with full pagination and automatic 401 → force-refresh retry.
  Future<List<Map<String, dynamic>>> fetchReservations({
    String? propertyId,
    DateTime? from,
    DateTime? to,
    List<String>? statuses,
  }) async {
    var token = await getValidAccessToken();
    if (token == null || token.isEmpty) {
      _setTokenError('Apaleo not authenticated — cannot fetch reservations.');
      throw Exception('Apaleo is not authenticated.');
    }

    final baseQueryParts = <String>[];
    if (propertyId != null && propertyId.isNotEmpty) {
      baseQueryParts.add('propertyIds=$propertyId');
    }
    if (from != null) baseQueryParts.add('from=${from.toUtc().toIso8601String()}');
    if (to != null) baseQueryParts.add('to=${to.toUtc().toIso8601String()}');
    if (statuses != null && statuses.isNotEmpty) {
      for (final s in statuses) {
        baseQueryParts.add('status=$s');
      }
    }

    const int pageSize = 100;
    int pageNumber = 1;
    int totalCount = 0;
    final List<Map<String, dynamic>> allReservations = [];

    do {
      final queryParts = [...baseQueryParts, 'pageSize=$pageSize', 'pageNumber=$pageNumber'];
      final url = '$_baseUrl/booking/v1/reservations?${queryParts.join('&')}';
      final uri = Uri.parse(url);

      var resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      // Auto-retry once on 401
      if (resp.statusCode == 401) {
        debugPrint('[ApaleoService] 401 on fetchReservations (page $pageNumber) — force-refreshing token and retrying...');
        final freshToken = await getValidAccessToken(forceRefresh: true);
        if (freshToken != null && freshToken.isNotEmpty && freshToken != token) {
          token = freshToken;
          resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
        }
        if (resp.statusCode == 401) {
          _setTokenError('Apaleo returned 401 after token refresh. Please reconnect in PMS settings.');
          throw Exception('Apaleo authentication failed (401). Please reconnect.');
        }
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final page = (data['reservations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        allReservations.addAll(page);
        totalCount = (data['count'] as num?)?.toInt() ?? allReservations.length;
        debugPrint('[ApaleoService] fetchReservations page $pageNumber: ${page.length} records (total: $totalCount)');
        if (page.length < pageSize || allReservations.length >= totalCount) break;
        pageNumber++;
      } else {
        throw Exception('Failed to fetch reservations (page $pageNumber): ${resp.statusCode} ${resp.body}');
      }
    } while (allReservations.length < totalCount);

    // Clear any stale auth error if we succeeded
    if (tokenExpiredNotifier.value) {
      tokenExpiredNotifier.value = false;
      tokenErrorMessage.value = null;
    }
    debugPrint('[ApaleoService] fetchReservations total: ${allReservations.length} reservations fetched.');
    return allReservations;
  }

  /// 2b. Assign a physical room/unit to a reservation in Apaleo PMS
  Future<bool> assignUnitReservation({
    required String reservationId,
    required String roomNumber,
    String? propertyId,
  }) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    try {
      final pId = propertyId ?? 'BER';
      final unitsUri = Uri.parse('$_baseUrl/inventory/v1/units?propertyId=$pId&pageSize=100');
      final unitsResp = await http.get(unitsUri, headers: {'Authorization': 'Bearer $token'});
      if (unitsResp.statusCode != 200) {
        debugPrint('[ApaleoService] Failed to fetch units for room assignment: ${unitsResp.statusCode}');
        return false;
      }

      final unitsData = jsonDecode(unitsResp.body);
      final units = (unitsData['units'] as List?) ?? [];
      String? targetUnitId;

      final cleanTarget = roomNumber.trim().toLowerCase();
      for (final u in units) {
        final uName = (u['name'] ?? '').toString().trim().toLowerCase();
        final uId = (u['id'] ?? '').toString().trim().toLowerCase();
        if (uName == cleanTarget || uId == cleanTarget || uId.endsWith('-$cleanTarget')) {
          targetUnitId = u['id'];
          break;
        }
      }

      if (targetUnitId == null) {
        debugPrint('[ApaleoService] Could not resolve unit ID for room "$roomNumber"');
        return false;
      }

      final assignUri = Uri.parse('$_baseUrl/booking/v1/reservation-actions/$reservationId/assign-unit/$targetUnitId');
      final resp = await http.put(
        assignUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      debugPrint('[ApaleoService] assignUnit $reservationId -> $targetUnitId ($roomNumber): ${resp.statusCode}');
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      debugPrint('[ApaleoService] assignUnit error: $e');
      return false;
    }
  }

  /// 3. Digital Check-In Reservation in Apaleo
  Future<bool> checkInReservation(String reservationId) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    final uri = Uri.parse('$_baseUrl/booking/v1/reservation-actions/$reservationId/checkin');
    final resp = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    debugPrint('[ApaleoService] checkInReservation $reservationId: ${resp.statusCode} ${resp.body}');

    return resp.statusCode == 200 || resp.statusCode == 204;
  }


  /// 4. Autonomous Digital Check-Out Reservation in Apaleo
  /// Fully handles all PMS edge cases:
  /// - Case 1: Already CheckedOut -> returns true immediately (no-op)
  /// - Case 2: Canceled -> returns true immediately (reservation already closed)
  /// - Case 3: Confirmed / Not InHouse -> ensures room unit is assigned, checks in, then checks out
  /// - Case 4: Early departure (departure > 24 hours in the future) -> automatically amends dates & time slices to today/tomorrow, then checks out
  /// - Case 5: Token expired -> auto-refreshes token
  Future<bool> checkOutReservation(String reservationId, {int retryCount = 0}) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    try {
      // Step A: Pre-flight check reservation status and structure in Apaleo
      final resUri = Uri.parse('$_baseUrl/booking/v1/reservations/$reservationId?expand=timeSlices');
      final resResp = await http.get(resUri, headers: {'Authorization': 'Bearer $token'});

      Map<String, dynamic>? resData;
      if (resResp.statusCode == 200) {
        resData = jsonDecode(resResp.body);
        final status = (resData?['status'] ?? '').toString();

        // 1. If already CheckedOut, success!
        if (status.toLowerCase() == 'checkedout') {
          debugPrint('[ApaleoService] Reservation $reservationId is already CheckedOut in Apaleo.');
          return true;
        }

        // 2. If Canceled, treat as closed
        if (status.toLowerCase() == 'canceled') {
          debugPrint('[ApaleoService] Reservation $reservationId was Canceled in Apaleo.');
          return true;
        }

        // 3. If Confirmed, check it in first
        if (status.toLowerCase() == 'confirmed') {
          debugPrint('[ApaleoService] Reservation $reservationId is Confirmed. Ensuring unit is assigned & checking in...');
          if (resData?['unit'] == null) {
            final pId = resData?['property']?['id']?.toString() ?? 'BER';
            await _autoAssignAvailableUnit(reservationId, pId, token);
          }
          await checkInReservation(reservationId);
        }

        // 4. Check for early departure (departure is more than 24 hours in the future)
        final departureStr = resData?['departure']?.toString() ?? '';
        final departureDate = DateTime.tryParse(departureStr);
        final now = DateTime.now();
        if (departureDate != null && departureDate.difference(now).inHours > 24) {
          debugPrint('[ApaleoService] Early departure detected for $reservationId. Amending stay before checkout...');
          await _amendEarlyDeparture(reservationId, resData!, token);
        }
      }

      // Step B: Call checkout action
      final uri = Uri.parse('$_baseUrl/booking/v1/reservation-actions/$reservationId/checkout');
      final resp = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      debugPrint('[ApaleoService] checkOutReservation $reservationId: ${resp.statusCode} ${resp.body}');

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        return true;
      }

      // Step C: Fallback error handlers
      // If error message indicates it's already checked out:
      if (resp.body.toLowerCase().contains('checkedout') || resp.body.toLowerCase().contains('already checked out')) {
        return true;
      }

      // If still complains about departure date more than one day in the future (e.g. pre-flight was skipped or failed)
      if (resp.statusCode == 422 && resp.body.contains('more than one day in the future') && retryCount < 2) {
        debugPrint('[ApaleoService] Retrying early departure amend for $reservationId...');
        if (resData == null) {
          final resResp2 = await http.get(resUri, headers: {'Authorization': 'Bearer $token'});
          if (resResp2.statusCode == 200) {
            resData = jsonDecode(resResp2.body);
          }
        }
        if (resData != null) {
          final amendOk = await _amendEarlyDeparture(reservationId, resData, token);
          if (amendOk) {
            final retryCo = await http.put(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
            debugPrint('[ApaleoService] Retry checkout after amend for $reservationId: ${retryCo.statusCode} ${retryCo.body}');
            return retryCo.statusCode == 200 || retryCo.statusCode == 204;
          }
        }
      }

      // If failed because not InHouse and retryCount < 1
      if ((resp.statusCode == 400 || resp.statusCode == 422) && retryCount < 1) {
        debugPrint('[ApaleoService] Attempting recovery check-in for $reservationId...');
        final checkInOk = await checkInReservation(reservationId);
        if (checkInOk) {
          return await checkOutReservation(reservationId, retryCount: retryCount + 1);
        }
      }
    } catch (e) {
      debugPrint('[ApaleoService] checkOutReservation exception for $reservationId: $e');
    }

    return false;
  }

  /// Helper: Amend early departure in Apaleo
  Future<bool> _amendEarlyDeparture(
    String reservationId,
    Map<String, dynamic> resData,
    String token,
  ) async {
    try {
      final timeSlices = (resData['timeSlices'] as List?) ?? [];
      if (timeSlices.isEmpty) return false;

      final existingDep = resData['departure']?.toString() ?? '';
      final timePart = existingDep.contains('T')
          ? existingDep.substring(existingDep.indexOf('T'))
          : 'T10:00:00+02:00';

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final tomorrowStr = '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      final newDeparture = '$tomorrowStr$timePart';

      final slicesToKeep = <Map<String, dynamic>>[];
      for (var slice in timeSlices) {
        final fromStr = slice['from']?.toString() ?? '';
        final fromDate = DateTime.tryParse(fromStr);
        if (fromDate == null || fromDate.isBefore(tomorrow)) {
          slicesToKeep.add({
            'ratePlanId': slice['ratePlan']?['id'] ?? timeSlices.first['ratePlan']?['id'],
            'totalAmount': slice['totalGrossAmount'] ?? timeSlices.first['totalGrossAmount'],
          });
        }
      }
      if (slicesToKeep.isEmpty) {
        slicesToKeep.add({
          'ratePlanId': timeSlices.first['ratePlan']?['id'],
          'totalAmount': timeSlices.first['totalGrossAmount'],
        });
      }

      final amendBody = {
        'arrival': resData['arrival'],
        'departure': newDeparture,
        'adults': resData['adults'] ?? 1,
        'timeSlices': slicesToKeep,
      };

      final amendResp = await http.put(
        Uri.parse('$_baseUrl/booking/v1/reservation-actions/$reservationId/amend'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(amendBody),
      );
      debugPrint('[ApaleoService] amendEarlyDeparture $reservationId: ${amendResp.statusCode} ${amendResp.body}');
      return amendResp.statusCode == 200 || amendResp.statusCode == 204;
    } catch (e) {
      debugPrint('[ApaleoService] amendEarlyDeparture exception: $e');
      return false;
    }
  }

  /// Helper: Auto-assign an unoccupied unit if none is assigned
  Future<bool> _autoAssignAvailableUnit(
    String reservationId,
    String propertyId,
    String token,
  ) async {
    try {
      final unitsUri = Uri.parse('$_baseUrl/inventory/v1/units?propertyId=$propertyId&pageSize=100');
      final unitsResp = await http.get(unitsUri, headers: {'Authorization': 'Bearer $token'});
      if (unitsResp.statusCode != 200) return false;

      final unitsData = jsonDecode(unitsResp.body);
      final units = (unitsData['units'] as List?) ?? [];

      String? targetUnitId;
      for (final u in units) {
        final status = u['status'] as Map<String, dynamic>?;
        final isOccupied = status?['isOccupied'] == true;
        if (!isOccupied && u['id'] != null) {
          targetUnitId = u['id'];
          break;
        }
      }

      if (targetUnitId == null) return false;

      final assignUri = Uri.parse('$_baseUrl/booking/v1/reservation-actions/$reservationId/assign-unit/$targetUnitId');
      final resp = await http.put(
        assignUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      debugPrint('[ApaleoService] autoAssignUnit $reservationId -> $targetUnitId: ${resp.statusCode}');
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (e) {
      debugPrint('[ApaleoService] autoAssignUnit exception: $e');
      return false;
    }
  }

  /// 4b. Digital Cancel Reservation in Apaleo
  Future<bool> cancelReservation(String reservationId) async {
    final token = await getValidAccessToken();
    if (token == null) return false;

    final uri = Uri.parse('$_baseUrl/booking/v1/reservation-actions/$reservationId/cancel');
    final resp = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    debugPrint('[ApaleoService] cancelReservation $reservationId: ${resp.statusCode} ${resp.body}');
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
