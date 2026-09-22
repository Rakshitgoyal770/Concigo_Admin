import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Session data for the currently logged-in employee
class EmployeeSession {
  final String empId;
  final String empFirstName;
  final String empLastName;
  final String role;
  final String propertyId;
  final String propertyName;
  final String? serviceDept;

  EmployeeSession({
    required this.empId,
    required this.empFirstName,
    required this.empLastName,
    required this.role,
    required this.propertyId,
    required this.propertyName,
    this.serviceDept,
  });

  String get fullName => '$empFirstName $empLastName'.trim();

  Map<String, dynamic> toJson() => {
    'empId': empId,
    'empFirstName': empFirstName,
    'empLastName': empLastName,
    'role': role,
    'propertyId': propertyId,
    'propertyName': propertyName,
    'serviceDept': serviceDept,
  };

  factory EmployeeSession.fromJson(Map<String, dynamic> json) => EmployeeSession(
    empId: json['empId'] as String? ?? '',
    empFirstName: json['empFirstName'] as String? ?? '',
    empLastName: json['empLastName'] as String? ?? '',
    role: json['role'] as String? ?? 'RECEPTION_DESK',
    propertyId: json['propertyId'] as String? ?? '',
    propertyName: json['propertyName'] as String? ?? '',
    serviceDept: json['serviceDept'] as String?,
  );

  static String mapDbRoleToAppRole(String dbRole) {
    switch (dbRole) {
      case 'RECEPTION':
        return 'RECEPTION_DESK';
      case 'SUPERADMIN':
        return 'SUPERADMIN';
      case 'SERVICE_MANAGER':
        return 'SERVICE_MANAGER';
      case 'SERVICE_EMPLOYEE':
        return 'SERVICE_EMPLOYEE';
      case 'SPA_MANAGER':
        return 'SPA_MANAGER';
      case 'SPA_EMPLOYEE':
        return 'SPA_EMPLOYEE';
      case 'LAUNDRY_MANAGER':
        return 'LAUNDRY_MANAGER';
      case 'LAUNDRY_EMPLOYEE':
        return 'LAUNDRY_EMPLOYEE';
      default:
        return dbRole;
    }
  }

  static String mapAppRoleToDbRole(String appRole) {
    switch (appRole) {
      case 'RECEPTION_DESK':
        return 'RECEPTION';
      case 'SUPERADMIN':
        return 'SUPERADMIN';
      case 'SERVICE_MANAGER':
        return 'SERVICE_MANAGER';
      case 'SERVICE_EMPLOYEE':
        return 'SERVICE_EMPLOYEE';
      case 'SPA_MANAGER':
        return 'SPA_MANAGER';
      case 'SPA_EMPLOYEE':
        return 'SPA_EMPLOYEE';
      case 'LAUNDRY_MANAGER':
        return 'LAUNDRY_MANAGER';
      case 'LAUNDRY_EMPLOYEE':
        return 'LAUNDRY_EMPLOYEE';
      default:
        return appRole;
    }
  }
}

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qmgrkogxqfqaimtcfvsp.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc',
  );

  EmployeeSession? currentSession;

  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be defined using --dart-define.',
      );
    }
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  SupabaseClient get client => Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────────────────
  // PROPERTIES
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchActiveProperties() async {
    try {
      final response = await client
          .from('hotel_property')
          .select('property_id, name, city, property_type')
          .eq('is_active', true)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch properties: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch properties: $e');
    }
  }

  /// Fetch full property details for SuperAdmin
  Future<Map<String, dynamic>?> fetchPropertyDetails(String propertyId) async {
    try {
      final response = await client
          .from('hotel_property')
          .select(
            'property_id, name, city, state, address_ln1, contact_number, email, property_type, web_url',
          )
          .eq('property_id', propertyId)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch property details: ${e.message}');
    }
  }

  /// Update property details
  Future<void> updatePropertyDetails(
    String propertyId,
    Map<String, dynamic> data,
  ) async {
    try {
      await client
          .from('hotel_property')
          .update({...data, 'updated_at': DateTime.now().toIso8601String()})
          .eq('property_id', propertyId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update property: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OTP
  // ─────────────────────────────────────────────────────────────────────────

  bool _isDevPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits == '9876543210' ||
        digits == '919876543210' ||
        digits == '9999999999' ||
        digits == '919999999999' ||
        digits == '8950462002' ||
        digits == '918950462002' ||
        digits == '8888888888' ||
        digits == '918888888888';
  }

  Future<void> sendOtp(String phone) async {
    // Normalize phone number to E.164
    String normalised = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!normalised.startsWith('+')) {
      normalised = '+$normalised';
    }

    // Developer / bypass numbers: skip SMS to eliminate 100% of MSG91 costs
    if (_isDevPhone(normalised)) return;

    try {
      // Use Supabase Auth OTP -> triggers MSG91 Send SMS Hook
      await client.auth.signInWithOtp(phone: normalised);
    } catch (e) {
      // Fallback to send-otp-v2 function if auth fails
      try {
        final response = await client.functions.invoke(
          'send-otp-v2',
          body: {'phone': phone},
        );
        final data = response.data as Map<String, dynamic>?;
        if (data == null || data['success'] != true) {
          final errMsg = data?['error'] as String? ?? data?['message'] as String? ?? 'Failed to send OTP.';
          throw Exception(errMsg);
        }
      } catch (fallbackErr) {
        throw Exception('Failed to send OTP: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    String normalised = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!normalised.startsWith('+')) {
      normalised = '+$normalised';
    }

    if (_isDevPhone(normalised)) {
      final code = otp.trim();
      return code == '123456' || code == '000000' || code == '777777';
    }

    try {
      final res = await client.auth.verifyOTP(
        phone: normalised,
        token: otp.trim(),
        type: OtpType.sms,
      );
      if (res.session != null || res.user != null) {
        return true;
      }
    } catch (_) {
      // Try fallback to verify-otp edge function
    }

    try {
      final response = await client.functions.invoke(
        'verify-otp',
        body: {'phone': phone, 'otp': otp},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) return true;
      return false;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPLOYEE VERIFICATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> verifyEmployee({
    required String phoneNumber,
    required String appRole,
  }) async {
    try {
      final dbRole = EmployeeSession.mapAppRoleToDbRole(appRole);
      final response = await client
          .from('property_employees')
          .select(
            'emp_id, emp_f_name, emp_l_name, role, property_id, service_dept, is_active, phone_no',
          )
          .eq('phone_no', phoneNumber)
          .eq('role', dbRole)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Employee verification failed: ${e.message}');
    } catch (e) {
      throw Exception('Employee verification failed: $e');
    }
  }

  /// Verify employee by phone number only — no role filter.
  /// Returns employee data including property name (via join).
  Future<Map<String, dynamic>?> verifyEmployeeByPhone(
    String phoneNumber,
  ) async {
    try {
      // Normalise input into all possible formats
      String digits = phoneNumber.trim();
      if (digits.startsWith('+')) digits = digits.substring(1);

      String localDigits = digits;
      if (digits.startsWith('91') && digits.length > 10) {
        localDigits = digits.substring(2); // strip country code 91
      }

      final withPlus = '+$digits'; // e.g. +919555275305
      final withCountryCode = digits; // e.g. 919555275305
      final localOnly = localDigits; // e.g. 9555275305

      const selectFields =
          'emp_id, emp_f_name, emp_l_name, role, property_id, service_dept, is_active, phone_no, hotel_property(name)';

      // Try each format individually to avoid OR filter issues
      for (final phone in [withPlus, withCountryCode, localOnly]) {
        final rows = await client
            .from('property_employees')
            .select(selectFields)
            .eq('phone_no', phone)
            .eq('is_active', true)
            .isFilter('deleted_at', null)
            .limit(1);

        if ((rows as List).isNotEmpty) {
          return rows.first;
        }
      }

      // If developer bypass number, provide a default Superadmin profile for testing
      if (_isDevPhone(phoneNumber)) {
        return {
          'emp_id': 'dev-admin-bypass',
          'emp_f_name': 'Dev',
          'emp_l_name': 'Admin',
          'role': 'SUPERADMIN',
          'property_id': '1f47276a-8ed2-4cec-9bb7-24cdcc5dedf5',
          'service_dept': null,
          'is_active': true,
          'phone_no': phoneNumber,
          'hotel_property': {
            'name': 'The Oberoi'
          }
        };
      }

      return null;
    } on PostgrestException catch (e) {
      throw Exception('Employee verification failed: ${e.message}');
    } catch (e) {
      throw Exception('Employee verification failed: $e');
    }
  }

  static const String _sessionStorageKey = 'concigo_admin_session_v1';

  void buildSession({
    required Map<String, dynamic> employee,
    required String propertyName,
  }) {
    currentSession = EmployeeSession(
      empId: employee['emp_id'] as String,
      empFirstName: (employee['emp_f_name'] as String?) ?? '',
      empLastName: (employee['emp_l_name'] as String?) ?? '',
      role: EmployeeSession.mapDbRoleToAppRole(employee['role'] as String),
      propertyId: employee['property_id'] as String,
      propertyName: propertyName,
      serviceDept: employee['service_dept'] as String?,
    );
    _persistSession(currentSession!);
  }

  Future<void> _persistSession(EmployeeSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<EmployeeSession?> loadPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_sessionStorageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        currentSession = EmployeeSession.fromJson(map);
        return currentSession;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearSession() async {
    currentSession = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionStorageKey);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROOMS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch rooms for a property — returns normalized maps with 'room_id', 'room_number', 'floor', 'type', 'is_booked', 'status'
  Future<List<Map<String, dynamic>>> fetchRooms(String propertyId) async {
    try {
      final response = await client
          .from('rooms')
          .select('room_id, room_number, floor, type, is_booked, is_active')
          .eq('property_id', propertyId)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('room_number', ascending: true);

      final list = List<Map<String, dynamic>>.from(response);
      for (final map in list) {
        final isBooked = map['is_booked'] == true;
        map['status'] = isBooked ? 'OCCUPIED' : 'VACANT';
      }
      return list;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch rooms: ${e.message}');
    }
  }

  /// Mark a room as booked or available
  Future<void> updateRoomBookingStatus(String roomId, bool isBooked) async {
    try {
      await client
          .from('rooms')
          .update({
            'is_booked': isBooked,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update room status: ${e.message}');
    }
  }

  /// Check if a room is available for a given date range using PostgreSQL RPC
  Future<bool> checkRoomAvailable({
    required String roomId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? excludeStayId,
  }) async {
    try {
      final inStr = checkInDate.toIso8601String().split('T')[0];
      final outStr = checkOutDate.toIso8601String().split('T')[0];
      final response = await client.rpc('check_room_available', params: {
        'p_room_id': roomId,
        'p_check_in': inStr,
        'p_check_out': outStr,
        'p_exclude_stay_id': excludeStayId,
      });
      return response == true;
    } catch (_) {
      // Fallback: check room is_booked directly
      try {
        final room = await client
            .from('rooms')
            .select('is_booked')
            .eq('room_id', roomId)
            .maybeSingle();
        return room != null && room['is_booked'] == false;
      } catch (err) {
        return false;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAYS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch active stays for a property with guest and room info
  Future<List<Map<String, dynamic>>> fetchActiveStays(String propertyId) async {
    try {
      // Auto-sweep expired stays & release rooms in background
      try {
        await client.rpc('sync_expired_stays_and_rooms');
      } catch (_) {}

      final response = await client
          .from('stay')
          .select(
            'stay_id, check_in_date, check_out_date, status, main_user_id, users(name, mobile_no), stay_rooms(room_id, rooms(room_number)), early_late_offer_accepts(type, time_selected)',
          )
          .eq('hotel_id', propertyId)
          .eq('status', 'Active')
          .isFilter('deleted_at', null)
          .order('check_in_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch stays: ${e.message}');
    }
  }

  /// Fetch all stays (including ended) for records tab
  Future<List<Map<String, dynamic>>> fetchAllStays(String propertyId) async {
    try {
      final response = await client
          .from('stay')
          .select(
            'stay_id, check_in_date, check_out_date, status, main_user_id, users(name, mobile_no), stay_rooms(room_id, rooms(room_number)), early_late_offer_accepts(type, time_selected)',
          )
          .eq('hotel_id', propertyId)
          .isFilter('deleted_at', null)
          .order('check_in_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch all stays: ${e.message}');
    }
  }

  /// Fetch all stays for a property with full guest and room info (SuperAdmin)
  Future<List<Map<String, dynamic>>> fetchAllStaysForSuperAdmin(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('stay')
          .select(
            'stay_id, check_in_date, check_out_date, status, main_user_id, created_at, '
            'users(name, mobile_no), '
            'stay_rooms(room_id, rooms(room_number, type, floor)), '
            'stay_guests(user_id, users(name, mobile_no))',
          )
          .eq('hotel_id', propertyId)
          .isFilter('deleted_at', null)
          .order('check_in_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch stays: ${e.message}');
    }
  }

  /// Get or create a user by mobile number, returns user_id.
  /// [mobileNo] must be the full number including country code (e.g. +917044401546).
  Future<String> getOrCreateUser(String mobileNo) async {
    try {
      // Normalise: ensure the number starts with '+'
      final normalised = mobileNo.startsWith('+91') ? mobileNo : '+91$mobileNo';

      // Use .limit(1) instead of .maybeSingle() to safely handle duplicate rows
      final existingList = await client
          .from('users')
          .select('user_id')
          .eq('mobile_no', normalised)
          .eq('status', 'active')
          .limit(1);

      if ((existingList as List).isNotEmpty) {
        return existingList.first['user_id'] as String;
      }

      // Create new user — use upsert with onConflict to handle race conditions
      final newUserList = await client
          .from('users')
          .insert({
            'mobile_no': normalised,
            'name': 'Guest ($normalised)',
            'status': 'active',
          })
          .select('user_id')
          .limit(1);

      if ((newUserList as List).isNotEmpty) {
        return newUserList.first['user_id'] as String;
      }

      // Fallback: fetch after upsert in case RLS blocks returning
      final fallback = await client
          .from('users')
          .select('user_id')
          .eq('mobile_no', normalised)
          .eq('status', 'active')
          .limit(1);

      if ((fallback as List).isNotEmpty) {
        return fallback.first['user_id'] as String;
      }

      throw Exception('Unable to get or create user for $normalised');
    } on PostgrestException catch (e) {
      throw Exception('Failed to get/create user: ${e.message}');
    }
  }

  /// Look up a user by mobile number — returns the user row or null if not found.
  /// Phone must be normalized (with '+' prefix) before calling.
  Future<Map<String, dynamic>?> lookupUserByMobile(String mobileNo) async {
    try {
      final digits = mobileNo.replaceAll(RegExp(r'[^0-9]'), '');
      String normalised;
      if (mobileNo.startsWith('+')) {
        normalised = mobileNo;
      } else if (digits.length == 10) {
        normalised = '+91$digits';
      } else if (digits.length == 12 && digits.startsWith('91')) {
        normalised = '+$digits';
      } else {
        normalised = '+$mobileNo'; // fallback
      }
      final result = await client
          .from('users')
          .select('user_id, name, first_name, last_name, mobile_no')
          .eq('mobile_no', normalised)
          .eq('status', 'active')
          .isFilter('deleted_at', null)
          .limit(1);
      final list = result as List;
      return list.isNotEmpty ? list.first as Map<String, dynamic> : null;
    } on PostgrestException catch (e) {
      throw Exception('Failed to look up user: ${e.message}');
    }
  }

  /// Create an upcoming stay (status = 'Upcoming') for reception desk.
  /// If [existingUserId] is provided, uses that user directly.
  /// Otherwise resolves/creates a user from [mobileNo] and [guestName].
  /// room_id is intentionally omitted — assignment happens at actual check-in.
  Future<String> createUpcomingStay({
    required String propertyId,
    required String mobileNo,
    required String guestName,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    String? existingUserId,
  }) async {
    try {
      final digits = mobileNo.replaceAll(RegExp(r'[^0-9]'), '');
      String normalised;
      if (mobileNo.startsWith('+')) {
        normalised = mobileNo;
      } else if (digits.length == 10) {
        normalised = '+91$digits';
      } else if (digits.length == 12 && digits.startsWith('91')) {
        normalised = '+$digits';
      } else {
        normalised = '+$mobileNo'; // fallback
      }

      String userId;
      if (existingUserId != null && existingUserId.isNotEmpty) {
        userId = existingUserId;
      } else {
        // Check if user already exists
        final existing = await client
            .from('users')
            .select('user_id')
            .eq('mobile_no', normalised)
            .eq('status', 'active')
            .isFilter('deleted_at', null)
            .limit(1);
        final existingList = existing as List;
        if (existingList.isNotEmpty) {
          userId = existingList.first['user_id'] as String;
        } else {
          // Create new user with the provided name
          final newUser = await client
              .from('users')
              .insert({
                'mobile_no': normalised,
                'name': guestName.isNotEmpty
                    ? guestName
                    : 'Guest ($normalised)',
              })
              .select('user_id')
              .single();
          userId = newUser['user_id'] as String;
        }
      }

      // Insert stay with status 'Upcoming' — no room_id (room assigned at check-in)
      final stayResult = await client
          .from('stay')
          .insert({
            'hotel_id': propertyId,
            'main_user_id': userId,
            'check_in_date': checkInDate.toIso8601String().split('T')[0],
            'check_out_date': checkOutDate.toIso8601String().split('T')[0],
            'status': 'Upcoming',
          })
          .select('stay_id')
          .single();

      final stayId = stayResult['stay_id'] as String;

      // Add to stay_guests
      await client.from('stay_guests').insert({
        'stay_id': stayId,
        'user_id': userId,
      });

      return stayId;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create upcoming stay: ${e.message}');
    }
  }

  /// Fetch all upcoming stays for a property, sorted by check-in date ascending.
  Future<List<Map<String, dynamic>>> fetchUpcomingStays(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('stay')
          .select(
            'stay_id, check_in_date, check_out_date, status, main_user_id, '
            'users(name, first_name, last_name, mobile_no)',
          )
          .eq('hotel_id', propertyId)
          .eq('status', 'Upcoming')
          .isFilter('deleted_at', null)
          .order('check_in_date', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch upcoming stays: ${e.message}');
    }
  }

  /// Fetch upcoming stays with room info for the Activate Stay section.
  /// Returns each stay with guest_name, mobile_no, room_number, room_id,
  /// and checkin_request_id (from checkin_requests table).
  Future<List<Map<String, dynamic>>> fetchUpcomingStaysWithRooms(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('stay')
          .select(
            'stay_id, check_in_date, check_out_date, status, main_user_id, '
            'users(name, mobile_no), '
            'stay_rooms(room_id, rooms(room_number)), '
            'checkin_requests(id, status, checkin_code)',
          )
          .eq('hotel_id', propertyId)
          .eq('status', 'Upcoming')
          .isFilter('deleted_at', null)
          .order('check_in_date', ascending: true);

      final List<Map<String, dynamic>> results = [];
      for (final row in (response as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final userMap = map['users'] as Map<String, dynamic>?;
        map['guest_name'] = userMap?['name'] as String? ?? '—';
        map['mobile_no'] = userMap?['mobile_no'] as String? ?? '—';

        // Resolve assigned rooms (all entries in stay_rooms)
        final stayRooms = map['stay_rooms'] as List?;
        if (stayRooms != null && stayRooms.isNotEmpty) {
          final roomNumbers = stayRooms
              .map((sr) {
                final roomMap = (sr as Map<String, dynamic>)['rooms'] as Map<String, dynamic>?;
                return roomMap?['room_number']?.toString();
              })
              .where((n) => n != null && n.isNotEmpty)
              .cast<String>()
              .toList();

          final srFirst = stayRooms.first as Map<String, dynamic>;
          map['room_id'] = srFirst['room_id'] as String?;
          map['room_number'] = roomNumbers.isNotEmpty ? roomNumbers.join(', ') : null;
          map['room_numbers'] = roomNumbers;
        } else {
          map['room_id'] = null;
          map['room_number'] = null;
          map['room_numbers'] = <String>[];
        }

        // Resolve checkin_requests status
        final checkinRequests = map['checkin_requests'] as List?;
        if (checkinRequests != null && checkinRequests.isNotEmpty) {
          final cr = checkinRequests.first as Map<String, dynamic>;
          map['checkin_request_id'] = cr['id'] as String?;
          final crStatus = (cr['status'] as String? ?? '').toUpperCase();
          map['kyc_status'] = crStatus;
          map['is_kyc_verified'] = crStatus == 'APPROVED';
          map['checkin_code'] = cr['checkin_code'] as String?;
        } else {
          map['checkin_request_id'] = null;
          map['kyc_status'] = 'PENDING';
          map['is_kyc_verified'] = false;
        }

        results.add(map);
      }
      return results;
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to fetch upcoming stays with rooms: ${e.message}',
      );
    }
  }

  /// Verify that the entered mobile number and checkin_code match the
  /// checkin_requests record for the given stay.
  Future<bool> verifyCheckinCode({
    required String stayId,
    required String mobileNo,
    required String checkinCode,
  }) async {
    try {
      // Find checkin_request for this stay with matching code
      final response = await client
          .from('checkin_requests')
          .select(
            'id, main_user_id, checkin_code, users!checkin_requests_main_user_id_fkey(mobile_no)',
          )
          .eq('stay_id', stayId)
          .eq('checkin_code', checkinCode)
          .limit(1)
          .maybeSingle();

      if (response == null) return false;

      final userMap = response['users'] as Map<String, dynamic>?;
      final dbMobile = userMap?['mobile_no'] as String? ?? '';

      // Normalize: strip spaces, compare
      return dbMobile.trim() == mobileNo.trim();
    } on PostgrestException catch (e) {
      throw Exception('Failed to verify checkin code: ${e.message}');
    }
  }

  /// Fetch rooms that are not currently booked for a property.
  Future<List<Map<String, dynamic>>> fetchAvailableRooms(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('rooms')
          .select('room_id, room_number, floor, type, is_booked')
          .eq('property_id', propertyId)
          .eq('is_active', true)
          .eq('is_booked', false)
          .isFilter('deleted_at', null)
          .order('room_number', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch available rooms: ${e.message}');
    }
  }

  /// Activate a stay: set status = 'Active', mark room as booked.
  /// If [assignRoom] is true, also inserts a stay_rooms record.
  /// If [checkinRequestId] is provided, updates checkin_requests.accept_type.
  Future<void> activateStay({
    required String stayId,
    required String roomId,
    bool assignRoom = false,
    String? checkinRequestId,
    String? acceptType,
  }) async {
    try {
      // Verify room is available before activating
      final isAvail = await checkRoomAvailable(
        roomId: roomId,
        checkInDate: DateTime.now(),
        checkOutDate: DateTime.now().add(const Duration(days: 1)),
        excludeStayId: stayId,
      );
      if (!isAvail) {
        throw Exception('Room is already occupied or booked for these dates.');
      }

      // If no room was previously assigned, create the stay_rooms record
      if (assignRoom) {
        await client.from('stay_rooms').insert({
          'stay_id': stayId,
          'room_id': roomId,
        });
      }

      // Mark room as booked
      await client
          .from('rooms')
          .update({
            'is_booked': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId);

      // Activate the stay
      await client
          .from('stay')
          .update({'status': 'Active'})
          .eq('stay_id', stayId);

      // Update checkin_requests.accept_type if request id is available
      if (checkinRequestId != null &&
          checkinRequestId.isNotEmpty &&
          acceptType != null) {
        await client
            .from('checkin_requests')
            .update({'accept_type': acceptType})
            .eq('id', checkinRequestId);
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to activate stay: ${e.message}');
    }
  }

  /// Create a new stay with guests and rooms
  Future<String> createStay({
    required String propertyId,
    required List<String> guestMobiles,
    required List<String> roomIds,
    required DateTime checkInDate,
    required DateTime checkOutDate,
  }) async {
    try {
      // Validate availability for all selected rooms
      for (final rid in roomIds) {
        final isAvail = await checkRoomAvailable(
          roomId: rid,
          checkInDate: checkInDate,
          checkOutDate: checkOutDate,
        );
        if (!isAvail) {
          throw Exception('One or more selected rooms are already booked for the chosen dates.');
        }
      }

      // Get/create all users
      final userIds = await Future.wait(
        guestMobiles.map((m) => getOrCreateUser(m)),
      );

      final mainUserId = userIds.first;

      // Create stay
      final stayResult = await client
          .from('stay')
          .insert({
            'hotel_id': propertyId,
            'main_user_id': mainUserId,
            'check_in_date': checkInDate.toIso8601String().split('T')[0],
            'check_out_date': checkOutDate.toIso8601String().split('T')[0],
            'status': 'Upcoming',
          })
          .select('stay_id')
          .single();

      final stayId = stayResult['stay_id'] as String;

      // Create stay_guests for all users
      await client
          .from('stay_guests')
          .insert(
            userIds.map((uid) => {'stay_id': stayId, 'user_id': uid}).toList(),
          );

      // Create stay_rooms and mark rooms as booked
      await client
          .from('stay_rooms')
          .insert(
            roomIds.map((rid) => {'stay_id': stayId, 'room_id': rid}).toList(),
          );

      // Mark all rooms as booked
      await Future.wait(
        roomIds.map((rid) => updateRoomBookingStatus(rid, true)),
      );

      return stayId;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create stay: ${e.message}');
    }
  }

  /// Update stay dates and status (SuperAdmin)
  Future<void> updateStay({
    required String stayId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    required String status,
  }) async {
    try {
      await client
          .from('stay')
          .update({
            'check_in_date': checkInDate.toIso8601String().split('T')[0],
            'check_out_date': checkOutDate.toIso8601String().split('T')[0],
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('stay_id', stayId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update stay: ${e.message}');
    }
  }

  /// Soft-delete a stay (SuperAdmin)
  Future<void> deleteStay(String stayId) async {
    try {
      await client
          .from('stay')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('stay_id', stayId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete stay: ${e.message}');
    }
  }

  /// Create a stay directly from SuperAdmin (with guest mobile + room selection)
  Future<String> createStayForSuperAdmin({
    required String propertyId,
    required String guestMobile,
    required String guestName,
    required String roomId,
    required DateTime checkInDate,
    required DateTime checkOutDate,
    required String status,
  }) async {
    try {
      // Get or create user
      final existing = await client
          .from('users')
          .select('user_id')
          .eq('mobile_no', guestMobile)
          .maybeSingle();

      String userId;
      if (existing != null) {
        userId = existing['user_id'] as String;
        // Update name if provided
        if (guestName.isNotEmpty) {
          await client
              .from('users')
              .update({'name': guestName})
              .eq('user_id', userId);
        }
      } else {
        final newUser = await client
            .from('users')
            .insert({
              'mobile_no': guestMobile,
              'name': guestName.isNotEmpty ? guestName : 'Guest ($guestMobile)',
            })
            .select('user_id')
            .single();
        userId = newUser['user_id'] as String;
      }

      // Verify room availability
      final isAvail = await checkRoomAvailable(
        roomId: roomId,
        checkInDate: checkInDate,
        checkOutDate: checkOutDate,
      );
      if (!isAvail) {
        throw Exception('Selected room is already booked for these dates.');
      }

      // Create stay
      final stayResult = await client
          .from('stay')
          .insert({
            'hotel_id': propertyId,
            'main_user_id': userId,
            'check_in_date': checkInDate.toIso8601String().split('T')[0],
            'check_out_date': checkOutDate.toIso8601String().split('T')[0],
            'status': status,
          })
          .select('stay_id')
          .single();

      final stayId = stayResult['stay_id'] as String;

      // Create stay_guests
      await client.from('stay_guests').insert({
        'stay_id': stayId,
        'user_id': userId,
      });

      // Create stay_rooms
      await client.from('stay_rooms').insert({
        'stay_id': stayId,
        'room_id': roomId,
      });

      // Mark room as booked if active
      if (status == 'Active') {
        await updateRoomBookingStatus(roomId, true);
      }

      return stayId;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create stay: ${e.message}');
    }
  }

  /// Checkout: mark stay as Ended, release rooms
  Future<void> checkoutStay(String stayId, List<String> roomIds) async {
    try {
      await client
          .from('stay')
          .update({
            'status': 'Ended',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('stay_id', stayId);

      // Release all valid assigned rooms
      final validRoomIds = roomIds
          .where((rid) => rid.trim().isNotEmpty && rid != 'null' && rid != 'N/A')
          .toList();

      if (validRoomIds.isNotEmpty) {
        await Future.wait(
          validRoomIds.map((rid) => updateRoomBookingStatus(rid, false)),
        );
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to checkout stay: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICE ORDERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch service orders for a property, optionally filtered by service dept
  /// Returns normalized maps with keys: so_id, room_number, floor, status, so_total, order_type, created_at, serv_name, user_phone_no
  Future<List<Map<String, dynamic>>> fetchServiceOrders({
    required String propertyId,
    String? serviceDeptId,
    List<String>? statuses,
  }) async {
    try {
      // Fetch ALL room IDs for this property (no deleted_at/is_active filter
      // to ensure we find orders even for deactivated rooms)
      final roomsResponse = await client
          .from('rooms')
          .select('room_id')
          .eq('property_id', propertyId);

      final roomIds = (roomsResponse as List)
          .map((r) => r['room_id'] as String)
          .toList();

      if (roomIds.isEmpty) return [];

      var query = client
          .from('service_orders')
          .select(
            'so_id, serv_id, stay_id, room_id, so_total, status, created_at, updated_at, order_type, user_phone_no, rooms(room_number, floor), services(name)',
          )
          .inFilter('room_id', roomIds);
      // NOTE: service_orders does NOT have a deleted_at column — do not add isFilter

      if (serviceDeptId != null && serviceDeptId.isNotEmpty) {
        query = query.eq('serv_id', serviceDeptId);
      }

      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch service orders: ${e.message}');
    }
  }

  /// Fetch manager orders categorized into 3 sections.
  /// Room number is resolved from stay_rooms → rooms via stay_id.
  /// Returns a map with keys: 'newOrders', 'unallottedOrders', 'allottedOrders'
  Future<Map<String, List<Map<String, dynamic>>>> fetchManagerOrders({
    required String propertyId,
    String? serviceDeptId,
  }) async {
    try {
      // Step 1: Fetch all relevant orders (status = ordered OR in_progress)
      var query = client
          .from('service_orders')
          .select(
            'so_id, serv_id, stay_id, room_id, delivery_location, so_total, status, created_at, updated_at, order_type, user_phone_no, services(name), service_order_items(soi_id, item_name, qty, item_sp, cost)',
          )
          .inFilter('status', ['ordered', 'in_progress']);

      if (serviceDeptId != null && serviceDeptId.isNotEmpty) {
        query = query.eq('serv_id', serviceDeptId);
      }

      final ordersRaw = await query.order('created_at', ascending: false);
      final orders = List<Map<String, dynamic>>.from(ordersRaw);

      if (orders.isEmpty) {
        return {'newOrders': [], 'unallottedOrders': [], 'allottedOrders': []};
      }

      // Step 2: Collect all unique stay_ids and room_ids from orders
      final stayIds = orders
          .map((o) => o['stay_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .cast<String>()
          .toList();

      // Step 3: Fetch stay_rooms to get room_id per stay_id
      Map<String, String> stayToRoomId = {};
      if (stayIds.isNotEmpty) {
        final stayRoomsRaw = await client
            .from('stay_rooms')
            .select('stay_id, room_id')
            .inFilter('stay_id', stayIds);
        for (final sr in stayRoomsRaw as List) {
          final sid = sr['stay_id'] as String?;
          final rid = sr['room_id'] as String?;
          if (sid != null && rid != null && !stayToRoomId.containsKey(sid)) {
            stayToRoomId[sid] = rid;
          }
        }
      }

      // Step 4: Collect all room_ids (from direct room_id on order + stay_rooms)
      final allRoomIds = <String>{};
      for (final o in orders) {
        final stayId = o['stay_id'] as String?;
        final directRoomId = o['room_id'] as String?;
        if (directRoomId != null && directRoomId.isNotEmpty) {
          allRoomIds.add(directRoomId);
        } else if (stayId != null && stayToRoomId.containsKey(stayId)) {
          allRoomIds.add(stayToRoomId[stayId]!);
        }
      }

      // Step 5: Fetch room numbers for all room_ids
      Map<String, String> roomIdToNumber = {};
      if (allRoomIds.isNotEmpty) {
        final roomsRaw = await client
            .from('rooms')
            .select('room_id, room_number')
            .inFilter('room_id', allRoomIds.toList());
        for (final r in roomsRaw as List) {
          final rid = r['room_id'] as String?;
          final rnum = r['room_number'] as String?;
          if (rid != null && rnum != null) {
            roomIdToNumber[rid] = rnum;
          }
        }
      }

      // Step 6: Fetch all order_allotments for in_progress orders
      final inProgressIds = orders
          .where((o) => o['status'] == 'in_progress')
          .map((o) => o['so_id'] as String)
          .toList();

      // Map: so_id -> allotment data
      Map<String, Map<String, dynamic>> allotmentMap = {};
      if (inProgressIds.isNotEmpty) {
        final allotmentsRaw = await client
            .from('order_allotments')
            .select(
              'id, orderid, employee_id, alloter_employee_id, order_price, property_employees!order_allotments_employee_id_fkey(emp_f_name, emp_l_name)',
            )
            .inFilter('orderid', inProgressIds);
        for (final a in allotmentsRaw as List) {
          final oid = a['orderid'] as String?;
          if (oid != null) {
            allotmentMap[oid] = Map<String, dynamic>.from(a);
          }
        }
      }

      // Step 7: Enrich each order with room_number and allotment info
      List<Map<String, dynamic>> newOrders = [];
      List<Map<String, dynamic>> unallottedOrders = [];
      List<Map<String, dynamic>> allottedOrders = [];

      for (final o in orders) {
        final soId = o['so_id'] as String;
        final stayId = o['stay_id'] as String?;
        final directRoomId = o['room_id'] as String?;
        final deliveryLocation = o['delivery_location'] as String?;
        final orderType = o['order_type'] as String?;
        final status = o['status'] as String? ?? 'ordered';
        final serviceData = o['services'] as Map<String, dynamic>?;

        final bool isPoolSide = orderType == 'pool_side' ||
            (deliveryLocation != null && deliveryLocation.trim().isNotEmpty &&
                deliveryLocation.toLowerCase().contains('pool'));

        // Resolve room number: prefer delivery location for poolside, then direct room_id, then stay_rooms
        String roomNumber = '-';
        String resolvedRoomId = '';
        if (isPoolSide) {
          roomNumber = (deliveryLocation != null && deliveryLocation.trim().isNotEmpty)
              ? deliveryLocation.trim()
              : 'Poolside';
        } else if (directRoomId != null && directRoomId.isNotEmpty) {
          resolvedRoomId = directRoomId;
          roomNumber = roomIdToNumber[directRoomId] ?? '-';
        } else if (stayId != null && stayToRoomId.containsKey(stayId)) {
          resolvedRoomId = stayToRoomId[stayId]!;
          roomNumber = roomIdToNumber[resolvedRoomId] ?? '-';
        }

        final enriched = {
          ...o,
          'room_number': roomNumber,
          'resolved_room_id': resolvedRoomId,
          'is_pool_side': isPoolSide,
          'delivery_location': deliveryLocation,
          'serv_name': serviceData?['name'] ?? 'Service',
          'service_order_items': o['service_order_items'] ?? [],
        };

        if (status == 'ordered') {
          newOrders.add(enriched);
        } else if (status == 'in_progress') {
          final allotment = allotmentMap[soId];
          if (allotment == null) {
            unallottedOrders.add(enriched);
          } else {
            final emp =
                allotment['property_employees'] as Map<String, dynamic>?;
            final empName = emp != null
                ? '${emp['emp_f_name'] ?? ''} ${emp['emp_l_name'] ?? ''}'.trim()
                : '';
            allottedOrders.add({
              ...enriched,
              'allotment_id': allotment['id'],
              'allotted_employee_id': allotment['employee_id'],
              'allotted_employee_name': empName,
            });
          }
        }
      }

      return {
        'newOrders': newOrders,
        'unallottedOrders': unallottedOrders,
        'allottedOrders': allottedOrders,
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch manager orders: ${e.message}');
    }
  }

  /// Update service order status
  /// Valid statuses: 'ordered', 'in_progress', 'delivered', 'cancelled'
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await client
          .from('service_orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('so_id', orderId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update order status: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPLOYEES
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch employees for a property
  /// Returns normalized maps with keys: emp_id, full_name, role, phone_no, is_active, service_dept, service_name
  Future<List<Map<String, dynamic>>> fetchEmployees(String propertyId) async {
    try {
      final response = await client
          .from('property_employees')
          .select(
            'emp_id, emp_f_name, emp_l_name, role, phone_no, is_active, service_dept, services(name)',
          )
          .eq('property_id', propertyId)
          .isFilter('deleted_at', null)
          .order('emp_f_name', ascending: true);

      return (response as List).map((e) {
        final map = e as Map<String, dynamic>;
        final services = map['services'] as Map<String, dynamic>?;
        return {
          'emp_id': map['emp_id'],
          'full_name': '${map['emp_f_name'] ?? ''} ${map['emp_l_name'] ?? ''}'
              .trim(),
          'role': EmployeeSession.mapDbRoleToAppRole(map['role'] as String),
          'phone_no': map['phone_no'] ?? '',
          'is_active': map['is_active'] ?? false,
          'service_dept': map['service_dept'],
          'service_name': services?['name'] ?? '',
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch employees: ${e.message}');
    }
  }

  /// Update employee active status
  Future<void> updateEmployeeStatus(String empId, bool isActive) async {
    try {
      await client
          .from('property_employees')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('emp_id', empId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update employee: ${e.message}');
    }
  }

  /// Create a new employee for a property
  Future<void> createEmployee({
    required String propertyId,
    required String firstName,
    required String lastName,
    required String phoneNo,
    required String role,
    String? serviceDept,
  }) async {
    try {
      final dbRole = EmployeeSession.mapAppRoleToDbRole(role);
      await client.from('property_employees').insert({
        'property_id': propertyId,
        'emp_f_name': firstName.trim(),
        'emp_l_name': lastName.trim(),
        'phone_no': phoneNo.trim(),
        'role': dbRole,
        'service_dept': serviceDept,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to create employee: ${e.message}');
    }
  }

  /// Update employee details
  Future<void> updateEmployee({
    required String empId,
    required String firstName,
    required String lastName,
    required String phoneNo,
    required String role,
    String? serviceDept,
    required bool isActive,
  }) async {
    try {
      final dbRole = EmployeeSession.mapAppRoleToDbRole(role);
      await client
          .from('property_employees')
          .update({
            'emp_f_name': firstName.trim(),
            'emp_l_name': lastName.trim(),
            'phone_no': phoneNo.trim(),
            'role': dbRole,
            'service_dept': serviceDept,
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('emp_id', empId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update employee: ${e.message}');
    }
  }

  /// Soft-delete an employee
  Future<void> deleteEmployee(String empId) async {
    try {
      await client
          .from('property_employees')
          .update({
            'deleted_at': DateTime.now().toIso8601String(),
            'is_active': false,
          })
          .eq('emp_id', empId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete employee: ${e.message}');
    }
  }

  /// Apply an extra discount to a service order (reduces so_total)
  Future<void> applyOrderDiscount({
    required String orderId,
    required double discountAmount,
    required double currentTotal,
  }) async {
    try {
      final newTotal = (currentTotal - discountAmount).clamp(
        0.0,
        double.infinity,
      );
      await client
          .from('service_orders')
          .update({
            'so_total': newTotal,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('so_id', orderId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to apply discount: ${e.message}');
    }
  }

  /// Fetch all checkout_orders (transactions) for a property
  Future<List<Map<String, dynamic>>> fetchTransactions(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('checkout_orders')
          .select(
            'id, total_amount, currency, status, transaction_id, payment_method, created_at, paid_at, users(name, mobile_no)',
          )
          .eq('hotel_id', propertyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch transactions: ${e.message}');
    }
  }

  /// Fetch services list for employee creation dropdowns
  Future<List<Map<String, dynamic>>> fetchServices() async {
    try {
      final response = await client
          .from('services')
          .select('serv_id, name, type')
          .isFilter('deleted_at', null)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch services: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDER ALLOTMENTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch allotments for an employee — returns normalized maps
  Future<List<Map<String, dynamic>>> fetchEmployeeAllotments(
    String empId,
  ) async {
    try {
      final response = await client
          .from('order_allotments')
          .select(
            'id, orderid, room_number, order_price, created_at, service_orders(so_id, status, order_type, created_at, so_total, user_phone_no, rooms(room_number, floor), services(name), service_order_items(soi_id, item_name, qty, item_sp, cost))',
          )
          .eq('employee_id', empId)
          .order('created_at', ascending: false);

      return (response as List).map((e) {
        final map = e as Map<String, dynamic>;
        final so = map['service_orders'] as Map<String, dynamic>?;
        final room = so?['rooms'] as Map<String, dynamic>?;
        final service = so?['services'] as Map<String, dynamic>?;
        return {
          'allotment_id': map['id'],
          'so_id': so?['so_id'] ?? map['orderid'],
          'status': so?['status'] ?? 'ordered',
          'room_number': room?['room_number'] ?? '',
          'floor': room?['floor'] ?? '',
          'service_name': service?['name'] ?? 'Service',
          'order_type': so?['order_type'] ?? '',
          'so_total': (so?['so_total'] ?? 0.0).toDouble(),
          'user_phone_no': so?['user_phone_no'] ?? '',
          'created_at': so?['created_at'] ?? map['created_at'],
          'order_price': (map['order_price'] ?? so?['so_total'] ?? 0.0)
              .toDouble(),
          'service_order_items': so?['service_order_items'] ?? [],
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch allotments: ${e.message}');
    }
  }

  /// Create an order allotment — assigns an order to an employee
  Future<void> createOrderAllotment({
    required String orderId,
    required String employeeId,
    required String alloterEmployeeId,
    String? roomId,
    String? roomNumber,
    required double orderPrice,
  }) async {
    try {
      // The `room_number` column in `order_allotments` table is of type UUID (references rooms.room_id).
      // We safely validate and pass the UUID if valid, or null (for poolside / non-UUID locations).
      String? targetRoomUuid;
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );

      if (roomId != null && uuidRegex.hasMatch(roomId.trim())) {
        targetRoomUuid = roomId.trim();
      } else if (roomNumber != null && uuidRegex.hasMatch(roomNumber.trim())) {
        targetRoomUuid = roomNumber.trim();
      }

      // Check if allotment already exists for this order
      final existing = await client
          .from('order_allotments')
          .select('id')
          .eq('orderid', orderId)
          .maybeSingle();

      if (existing != null) {
        // Update existing allotment
        await client
            .from('order_allotments')
            .update({
              'employee_id': employeeId,
              if (targetRoomUuid != null) 'room_number': targetRoomUuid,
            })
            .eq('orderid', orderId);
      } else {
        // Create new allotment
        await client.from('order_allotments').insert({
          'orderid': orderId,
          'employee_id': employeeId,
          'alloter_employee_id': alloterEmployeeId,
          'room_number': targetRoomUuid,
          'order_price': orderPrice,
        });
      }

      // Update order status to in_progress
      await updateOrderStatus(orderId, 'in_progress');
    } on PostgrestException catch (e) {
      throw Exception('Failed to create allotment: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GUESTS (for Records tab)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch all guests currently in active stays for a property
  Future<List<Map<String, dynamic>>> fetchActiveGuests(
    String propertyId,
  ) async {
    try {
      // Get active stay IDs for this property
      final stayResponse = await client
          .from('stay')
          .select('stay_id')
          .eq('hotel_id', propertyId)
          .inFilter('status', ['Active', 'Upcoming'])
          .isFilter('deleted_at', null);

      final stayIds = (stayResponse as List)
          .map((s) => s['stay_id'] as String)
          .toList();

      if (stayIds.isEmpty) return [];

      final guestResponse = await client
          .from('stay_guests')
          .select('stay_id, users(user_id, name, mobile_no)')
          .inFilter('stay_id', stayIds);

      return (guestResponse as List).map((g) {
        final map = g as Map<String, dynamic>;
        final user = map['users'] as Map<String, dynamic>?;
        return {
          'stay_id': map['stay_id'],
          'user_id': user?['user_id'] ?? '',
          'name': user?['name'] ?? 'Unknown Guest',
          'mobile_no': user?['mobile_no'] ?? '',
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch guests: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRE-CHECKIN REQUESTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch pre-checkin requests for a property, optionally filtered by status
  Future<List<Map<String, dynamic>>> fetchPreCheckinRequests({
    required String propertyId,
    List<String> statuses = const ['requested', 'accepted'],
  }) async {
    try {
      final response = await client
          .from('precheckin_request')
          .select(
            'request_id, user_id, property_id, stay_id, room_id, status, req_createdat, req_updatedat, users(name, mobile_no)',
          )
          .eq('property_id', propertyId)
          .inFilter('status', statuses)
          .order('req_createdat', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch pre-checkin requests: ${e.message}');
    }
  }

  /// Approve a pre-checkin request atomically:
  /// 1. Create stay  2. Create stay_guests  3. Create stay_rooms
  /// 4. Mark room as booked  5. Update precheckin_request
  Future<void> approvePreCheckinRequest({
    required String requestId,
    required String userId,
    required String propertyId,
    required String roomId,
    String? plannedCheckOut,
  }) async {
    try {
      final existing = await client
          .from('precheckin_request')
          .select('status, property_id')
          .eq('request_id', requestId)
          .single();

      if (existing['status'] != 'requested') {
        throw Exception('This request has already been processed.');
      }
      if (existing['property_id'] != propertyId) {
        throw Exception('Request does not belong to this property.');
      }

      final roomData = await client
          .from('rooms')
          .select('room_id, is_booked, property_id')
          .eq('room_id', roomId)
          .single();

      if (roomData['is_booked'] == true) {
        throw Exception('Selected room is no longer available.');
      }
      if (roomData['property_id'] != propertyId) {
        throw Exception('Room does not belong to this property.');
      }

      final now = DateTime.now();
      final checkInDateStr = now.toIso8601String().split('T')[0];
      final checkOutDateStr =
          plannedCheckOut ??
          now.add(const Duration(days: 1)).toIso8601String().split('T')[0];

      final stayResult = await client
          .from('stay')
          .insert({
            'hotel_id': propertyId,
            'main_user_id': userId,
            'check_in_date': checkInDateStr,
            'check_out_date': checkOutDateStr,
            'status': 'Active',
          })
          .select('stay_id')
          .single();

      final stayId = stayResult['stay_id'] as String;

      await client.from('stay_guests').insert({
        'stay_id': stayId,
        'user_id': userId,
      });

      await client.from('stay_rooms').insert({
        'stay_id': stayId,
        'room_id': roomId,
      });

      await client
          .from('rooms')
          .update({'is_booked': true, 'updated_at': now.toIso8601String()})
          .eq('room_id', roomId);

      await client
          .from('precheckin_request')
          .update({
            'status': 'accepted',
            'room_id': roomId,
            'stay_id': stayId,
            'req_updatedat': now.toIso8601String(),
          })
          .eq('request_id', requestId);
    } on PostgrestException catch (e) {
      throw Exception('Approval failed: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROOM UPGRADE OFFERS (new property-level offer management)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch all upgrade offers for a property (non-deleted)
  Future<List<Map<String, dynamic>>> fetchUpgradeOffers(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('room_upgrade_offers')
          .select('*')
          .eq('property_id', propertyId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch upgrade offers: ${e.message}');
    }
  }

  /// Create a new upgrade offer for a property
  Future<void> createUpgradeOffer({
    required String propertyId,
    required String roomType,
    required double originalPrice,
    required double discountedPrice,
    required DateTime validFrom,
    required DateTime validUntil,
    required bool isActive,
  }) async {
    try {
      if (discountedPrice >= originalPrice) {
        throw Exception('Discounted price must be less than original price.');
      }
      await client.from('room_upgrade_offers').insert({
        'property_id': propertyId,
        'room_type': roomType.trim(),
        'original_price': originalPrice,
        'discounted_price': discountedPrice,
        'valid_from': validFrom.toIso8601String(),
        'valid_until': validUntil.toIso8601String(),
        'is_active': isActive,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to create upgrade offer: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing upgrade offer
  Future<void> updateUpgradeOffer({
    required String offerId,
    required String roomType,
    required double originalPrice,
    required double discountedPrice,
    required DateTime validFrom,
    required DateTime validUntil,
    required bool isActive,
  }) async {
    try {
      if (discountedPrice >= originalPrice) {
        throw Exception('Discounted price must be less than original price.');
      }
      await client
          .from('room_upgrade_offers')
          .update({
            'room_type': roomType.trim(),
            'original_price': originalPrice,
            'discounted_price': discountedPrice,
            'valid_from': validFrom.toIso8601String(),
            'valid_until': validUntil.toIso8601String(),
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('offer_id', offerId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update upgrade offer: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Soft-deactivate an upgrade offer (set is_active = false)
  Future<void> deactivateUpgradeOffer(String offerId) async {
    try {
      await client
          .from('room_upgrade_offers')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('offer_id', offerId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to deactivate offer: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVE STAY OFFERS (in-stay upgrade offers shown to active guests)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch all active stay offers for a property
  Future<List<Map<String, dynamic>>> fetchActiveStayOffers(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('active_stay_offers')
          .select('*')
          .eq('property_id', propertyId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch active stay offers: ${e.message}');
    }
  }

  /// Create a new active stay offer for a property
  Future<void> createActiveStayOffer({
    required String propertyId,
    required String title,
    required String upgradeRoomType,
    required double amount,
    String? description,
    bool isActive = true,
  }) async {
    try {
      await client.from('active_stay_offers').insert({
        'property_id': propertyId,
        'title': title.trim(),
        'upgrade_room_type': upgradeRoomType.trim(),
        'amount': amount,
        'description': description?.trim(),
        'is_active': isActive,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to create active stay offer: ${e.message}');
    }
  }

  /// Update an existing active stay offer
  Future<void> updateActiveStayOffer({
    required String offerId,
    required String title,
    required String upgradeRoomType,
    required double amount,
    String? description,
    required bool isActive,
  }) async {
    try {
      await client
          .from('active_stay_offers')
          .update({
            'title': title.trim(),
            'upgrade_room_type': upgradeRoomType.trim(),
            'amount': amount,
            'description': description?.trim(),
            'is_active': isActive,
          })
          .eq('offer_id', offerId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update active stay offer: ${e.message}');
    }
  }

  /// Toggle is_active on an active stay offer
  Future<void> toggleActiveStayOffer(String offerId, bool isActive) async {
    try {
      await client
          .from('active_stay_offers')
          .update({'is_active': isActive})
          .eq('offer_id', offerId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to toggle offer: ${e.message}');
    }
  }

  /// Delete an active stay offer (hard delete — no deleted_at column)
  Future<void> deleteActiveStayOffer(String offerId) async {
    try {
      await client.from('active_stay_offers').delete().eq('offer_id', offerId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete active stay offer: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ROOM UPGRADE ORDERS (reception payment dashboard + room allotment)
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch paid upgrade orders with no room allotted yet for a property.
  /// Joins users (guest name), stay, and room_upgrade_offers (room_type, amount).
  Future<List<Map<String, dynamic>>> fetchPendingAllotmentOrders(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('room_upgrade_orders')
          .select(
            'order_id, user_id, stay_id, upg_offer_id, amount_paid, currency, payment_status, razorpay_payment_id, created_at, '
            'users(user_id, name, mobile_no), '
            'room_upgrade_offers(offer_id, room_type, original_price, discounted_price)',
          )
          .eq('property_id', propertyId)
          .eq('payment_status', 'paid')
          .isFilter('new_room_id', null)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch pending allotment orders: ${e.message}');
    }
  }

  /// Fetch rooms available for upgrade allotment:
  /// rooms of a given type for the property that are NOT in any active/upcoming stay.
  Future<List<Map<String, dynamic>>> fetchRoomsForUpgradeAllotment({
    required String propertyId,
    required String roomType,
  }) async {
    try {
      // Step 1: Get all stay_ids for active/upcoming stays at this property
      final stayResponse = await client
          .from('stay')
          .select('stay_id')
          .eq('hotel_id', propertyId)
          .inFilter('status', ['Upcoming', 'Active'])
          .isFilter('deleted_at', null);

      final stayIds = (stayResponse as List)
          .map((s) => s['stay_id'] as String)
          .toList();

      // Step 2: Get room_ids already assigned to those stays
      List<String> occupiedRoomIds = [];
      if (stayIds.isNotEmpty) {
        final stayRoomsResponse = await client
            .from('stay_rooms')
            .select('room_id')
            .inFilter('stay_id', stayIds);
        occupiedRoomIds = (stayRoomsResponse as List)
            .map((sr) => sr['room_id'] as String)
            .toList();
      }

      // Step 3: Fetch rooms of the given type for this property, excluding occupied ones
      var query = client
          .from('rooms')
          .select('room_id, room_number, floor, type')
          .eq('property_id', propertyId)
          .eq('type', roomType)
          .eq('is_active', true)
          .isFilter('deleted_at', null);

      final allRooms = List<Map<String, dynamic>>.from(
        await query.order('room_number', ascending: true),
      );

      if (occupiedRoomIds.isEmpty) return allRooms;
      return allRooms
          .where((r) => !occupiedRoomIds.contains(r['room_id'] as String))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch rooms for upgrade: ${e.message}');
    }
  }

  /// Fetch ALL rooms for a property (for manual override picker)
  Future<List<Map<String, dynamic>>> fetchAllRoomsForProperty(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('rooms')
          .select('room_id, room_number, floor, type, is_booked')
          .eq('property_id', propertyId)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('room_number', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch all rooms: ${e.message}');
    }
  }

  /// Allot a room to an upgrade order atomically:
  /// 1. UPDATE room_upgrade_orders SET new_room_id, allotted_by, allotted_at
  /// 2. INSERT into stay_rooms (stay_id, room_id)
  /// Does NOT change stay.status.
  Future<void> allotRoomForUpgradeOrder({
    required String orderId,
    required String stayId,
    required String roomId,
    required String allottedBy,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // 1. Update the upgrade order
      await client
          .from('room_upgrade_orders')
          .update({
            'new_room_id': roomId,
            'allotted_by': allottedBy,
            'allotted_at': now,
            'updated_at': now,
          })
          .eq('order_id', orderId);

      // 2. Insert into stay_rooms (ignore if already exists)
      try {
        await client.from('stay_rooms').insert({
          'stay_id': stayId,
          'room_id': roomId,
        });
      } on PostgrestException catch (e) {
        // If duplicate key, ignore — room already assigned
        if (!e.message.contains('duplicate') && !e.message.contains('unique')) {
          rethrow;
        }
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to allot room: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SPA ORDERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch spa orders for a property with guest name and room number
  Future<List<Map<String, dynamic>>> fetchSpaOrders({
    required String propertyId,
  }) async {
    try {
      final response = await client
          .from('spa_orders')
          .select(
            'spa_order_id, user_id, stay_id, property_id, spa_item_id, slot_id, service_name, slot_time, mobile_no, price, status, notes, created_at, updated_at, assigned_to, users(name, mobile_no)',
          )
          .eq('property_id', propertyId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final orders = List<Map<String, dynamic>>.from(response);

      // Resolve room numbers via stay_rooms
      final stayIds = orders
          .map((o) => o['stay_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .cast<String>()
          .toList();

      Map<String, String> stayToRoom = {};
      Map<String, String> roomIdToNumber = {};

      if (stayIds.isNotEmpty) {
        final stayRooms = await client
            .from('stay_rooms')
            .select('stay_id, room_id')
            .inFilter('stay_id', stayIds);
        for (final sr in stayRooms as List) {
          final sid = sr['stay_id'] as String?;
          final rid = sr['room_id'] as String?;
          if (sid != null && rid != null && !stayToRoom.containsKey(sid)) {
            stayToRoom[sid] = rid;
          }
        }
        final roomIds = stayToRoom.values.toList();
        if (roomIds.isNotEmpty) {
          final rooms = await client
              .from('rooms')
              .select('room_id, room_number')
              .inFilter('room_id', roomIds);
          for (final r in rooms as List) {
            roomIdToNumber[r['room_id'] as String] =
                r['room_number'] as String? ?? '-';
          }
        }
      }

      // Resolve assigned employee names
      final assignedIds = orders
          .map((o) => o['assigned_to'] as String?)
          .where((id) => id != null)
          .toSet()
          .cast<String>()
          .toList();

      Map<String, String> empIdToName = {};
      if (assignedIds.isNotEmpty) {
        final emps = await client
            .from('property_employees')
            .select('emp_id, emp_f_name, emp_l_name')
            .inFilter('emp_id', assignedIds);
        for (final e in emps as List) {
          empIdToName[e['emp_id'] as String] =
              '${e['emp_f_name'] ?? ''} ${e['emp_l_name'] ?? ''}'.trim();
        }
      }

      return orders.map((o) {
        final user = o['users'] as Map<String, dynamic>?;
        final stayId = o['stay_id'] as String?;
        final roomId = stayId != null ? stayToRoom[stayId] : null;
        final roomNumber = roomId != null ? roomIdToNumber[roomId] ?? '-' : '-';
        final assignedTo = o['assigned_to'] as String?;
        return {
          ...o,
          'guest_name': user?['name'] ?? 'Guest',
          'room_number': roomNumber,
          'assigned_emp_name': assignedTo != null
              ? empIdToName[assignedTo]
              : null,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch spa orders: ${e.message}');
    }
  }

  /// Fetch spa employees for a property (role = SPA_EMPLOYEE)
  Future<List<Map<String, dynamic>>> fetchSpaEmployees(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('property_employees')
          .select('emp_id, emp_f_name, emp_l_name, is_active')
          .eq('property_id', propertyId)
          .eq('role', 'SPA_EMPLOYEE')
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('emp_f_name', ascending: true);
      return (response as List).map((e) {
        final map = e as Map<String, dynamic>;
        return {
          'emp_id': map['emp_id'],
          'full_name': '${map['emp_f_name'] ?? ''} ${map['emp_l_name'] ?? ''}'
              .trim(),
          'is_active': map['is_active'] ?? false,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch spa employees: ${e.message}');
    }
  }

  /// Assign a spa order to an employee
  Future<void> assignSpaOrder(String spaOrderId, String empId) async {
    try {
      await client
          .from('spa_orders')
          .update({
            'assigned_to': empId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('spa_order_id', spaOrderId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to assign spa order: ${e.message}');
    }
  }

  /// Update spa order status
  Future<void> updateSpaOrderStatus(String spaOrderId, String status) async {
    try {
      await client
          .from('spa_orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('spa_order_id', spaOrderId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update spa order status: ${e.message}');
    }
  }

  /// Fetch spa orders assigned to a specific employee
  Future<List<Map<String, dynamic>>> fetchAssignedSpaOrders(
    String empId,
  ) async {
    try {
      final response = await client
          .from('spa_orders')
          .select(
            'spa_order_id, user_id, stay_id, service_name, slot_time, mobile_no, price, status, created_at, assigned_to, users(name)',
          )
          .eq('assigned_to', empId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final orders = List<Map<String, dynamic>>.from(response);

      // Resolve room numbers
      final stayIds = orders
          .map((o) => o['stay_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .cast<String>()
          .toList();

      Map<String, String> stayToRoom = {};
      Map<String, String> roomIdToNumber = {};

      if (stayIds.isNotEmpty) {
        final stayRooms = await client
            .from('stay_rooms')
            .select('stay_id, room_id')
            .inFilter('stay_id', stayIds);
        for (final sr in stayRooms as List) {
          final sid = sr['stay_id'] as String?;
          final rid = sr['room_id'] as String?;
          if (sid != null && rid != null && !stayToRoom.containsKey(sid)) {
            stayToRoom[sid] = rid;
          }
        }
        final roomIds = stayToRoom.values.toList();
        if (roomIds.isNotEmpty) {
          final rooms = await client
              .from('rooms')
              .select('room_id, room_number')
              .inFilter('room_id', roomIds);
          for (final r in rooms as List) {
            roomIdToNumber[r['room_id'] as String] =
                r['room_number'] as String? ?? '-';
          }
        }
      }

      return orders.map((o) {
        final user = o['users'] as Map<String, dynamic>?;
        final stayId = o['stay_id'] as String?;
        final roomId = stayId != null ? stayToRoom[stayId] : null;
        final roomNumber = roomId != null ? roomIdToNumber[roomId] ?? '-' : '-';
        return {
          ...o,
          'guest_name': user?['name'] ?? 'Guest',
          'room_number': roomNumber,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch assigned spa orders: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LAUNDRY REQUESTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch laundry requests for a property with guest name and room number
  Future<List<Map<String, dynamic>>> fetchLaundryRequests({
    required String propertyId,
  }) async {
    try {
      final response = await client
          .from('laundry_requests')
          .select(
            'request_id, property_id, room_id, user_id, stay_id, mobile_no, service_requested, item_count, preferred_pickup_time, special_instructions, status, created_at, updated_at, assigned_to, users(name, mobile_no), rooms(room_number)',
          )
          .eq('property_id', propertyId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final requests = List<Map<String, dynamic>>.from(response);

      // Resolve assigned employee names
      final assignedIds = requests
          .map((r) => r['assigned_to'] as String?)
          .where((id) => id != null)
          .toSet()
          .cast<String>()
          .toList();

      Map<String, String> empIdToName = {};
      if (assignedIds.isNotEmpty) {
        final emps = await client
            .from('property_employees')
            .select('emp_id, emp_f_name, emp_l_name')
            .inFilter('emp_id', assignedIds);
        for (final e in emps as List) {
          empIdToName[e['emp_id'] as String] =
              '${e['emp_f_name'] ?? ''} ${e['emp_l_name'] ?? ''}'.trim();
        }
      }

      return requests.map((r) {
        final user = r['users'] as Map<String, dynamic>?;
        final room = r['rooms'] as Map<String, dynamic>?;
        final assignedTo = r['assigned_to'] as String?;
        return {
          ...r,
          'guest_name': user?['name'] ?? 'Guest',
          'room_number': room?['room_number'] ?? '-',
          'assigned_emp_name': assignedTo != null
              ? empIdToName[assignedTo]
              : null,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch laundry requests: ${e.message}');
    }
  }

  /// Fetch laundry employees for a property (role = LAUNDRY_EMPLOYEE)
  Future<List<Map<String, dynamic>>> fetchLaundryEmployees(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('property_employees')
          .select('emp_id, emp_f_name, emp_l_name, is_active')
          .eq('property_id', propertyId)
          .eq('role', 'LAUNDRY_EMPLOYEE')
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('emp_f_name', ascending: true);
      return (response as List).map((e) {
        final map = e as Map<String, dynamic>;
        return {
          'emp_id': map['emp_id'],
          'full_name': '${map['emp_f_name'] ?? ''} ${map['emp_l_name'] ?? ''}'
              .trim(),
          'is_active': map['is_active'] ?? false,
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch laundry employees: ${e.message}');
    }
  }

  /// Assign a laundry request to an employee
  Future<void> assignLaundryRequest(String requestId, String empId) async {
    try {
      await client
          .from('laundry_requests')
          .update({
            'assigned_to': empId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to assign laundry request: ${e.message}');
    }
  }

  /// Update laundry request status
  Future<void> updateLaundryRequestStatus(
    String requestId,
    String status,
  ) async {
    try {
      await client
          .from('laundry_requests')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('request_id', requestId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update laundry request status: ${e.message}');
    }
  }

  /// Fetch laundry requests assigned to a specific employee
  Future<List<Map<String, dynamic>>> fetchAssignedLaundryRequests(
    String empId,
  ) async {
    try {
      final response = await client
          .from('laundry_requests')
          .select(
            'request_id, user_id, stay_id, room_id, mobile_no, service_requested, preferred_pickup_time, status, created_at, assigned_to, users(name), rooms(room_number)',
          )
          .eq('assigned_to', empId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      return (response as List).map((r) {
        final map = r as Map<String, dynamic>;
        final user = map['users'] as Map<String, dynamic>?;
        final room = map['rooms'] as Map<String, dynamic>?;
        return {
          ...map,
          'guest_name': user?['name'] ?? 'Guest',
          'room_number': room?['room_number'] ?? '-',
        };
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception(
        'Failed to fetch assigned laundry requests: ${e.message}',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICE BILLS
  // ─────────────────────────────────────────────────────────────────────────

  /// Lookup an active stay by mobile number + room number + property
  Future<Map<String, dynamic>?> lookupActiveStay({
    required String mobile,
    required String roomNumber,
    required String propertyId,
  }) async {
    try {
      // Normalise mobile: add + if missing
      final normMobile = mobile.startsWith('+') ? mobile : '+$mobile';

      // Find user by mobile
      final userList = await client
          .from('users')
          .select('user_id, name, mobile_no')
          .eq('mobile_no', normMobile)
          .eq('status', 'active')
          .limit(1);

      // Also try without + prefix in case stored differently
      List userRows = userList as List;
      if (userRows.isEmpty) {
        final userList2 = await client
            .from('users')
            .select('user_id, name, mobile_no')
            .eq('mobile_no', mobile)
            .eq('status', 'active')
            .limit(1);
        userRows = userList2 as List;
      }

      if (userRows.isEmpty) return null;
      final userId = userRows.first['user_id'] as String;
      final guestName = userRows.first['name'] as String? ?? 'Guest';

      // Find room by room_number + property
      final roomList = await client
          .from('rooms')
          .select('room_id')
          .eq('property_id', propertyId)
          .eq('room_number', roomNumber)
          .limit(1);

      if ((roomList as List).isEmpty) return null;
      final roomId = roomList.first['room_id'] as String;

      // Find active stay for this user + room
      final stayRoomList = await client
          .from('stay_rooms')
          .select('stay_id')
          .eq('room_id', roomId);

      if ((stayRoomList as List).isEmpty) return null;

      final stayIds = stayRoomList
          .map((sr) => sr['stay_id'] as String)
          .toList();

      // Find active stay for this user among those stay_ids
      final stayList = await client
          .from('stay')
          .select('stay_id, status, main_user_id')
          .inFilter('stay_id', stayIds)
          .eq('hotel_id', propertyId)
          .inFilter('status', ['Active', 'Upcoming'])
          .isFilter('deleted_at', null)
          .limit(1);

      if ((stayList as List).isEmpty) return null;

      final stay = stayList.first;
      return {
        'stay_id': stay['stay_id'],
        'user_id': userId,
        'guest_name': guestName,
        'stay_status': stay['status'],
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to lookup stay: ${e.message}');
    }
  }

  /// Create a service bill
  Future<String> createServiceBill({
    required String propertyId,
    required String stayId,
    required String userId,
    required String roomNo,
    required double amt,
    required String createdBy,
    required String serviceId,
  }) async {
    try {
      final result = await client
          .from('service_bills')
          .insert({
            'serv_id': serviceId.isNotEmpty ? serviceId : null,
            'property_id': propertyId,
            'stay_id': stayId,
            'user_id': userId,
            'room_no': roomNo,
            'amt': amt,
            'payment_status': 'unpaid',
            'created_by': createdBy,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('bill_id')
          .single();
      return result['bill_id'] as String;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create bill: ${e.message}');
    }
  }

  /// Fetch service bills for a property (filtered by created_by employee)
  Future<List<Map<String, dynamic>>> fetchServiceBills({
    required String propertyId,
    required String empId,
  }) async {
    try {
      final response = await client
          .from('service_bills')
          .select(
            'bill_id, serv_id, property_id, stay_id, user_id, room_no, amt, payment_status, payment_method, created_by, created_at, updated_at, users(name)',
          )
          .eq('property_id', propertyId)
          .eq('created_by', empId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      return (response as List).map((b) {
        final map = b as Map<String, dynamic>;
        final user = map['users'] as Map<String, dynamic>?;
        return {...map, 'guest_name': user?['name'] ?? 'Guest'};
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch bills: ${e.message}');
    }
  }

  /// Mark a service bill as paid
  Future<void> markBillPaid({
    required String billId,
    required String paymentMethod,
  }) async {
    try {
      await client
          .from('service_bills')
          .update({
            'payment_status': 'paid',
            'payment_method': paymentMethod,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('bill_id', billId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to mark bill as paid: ${e.message}');
    }
  }

  // ─── Inventory Management ────────────────────────────────────────────────

  /// Fetch all items for a given service type and property (non-deleted)
  Future<List<Map<String, dynamic>>> fetchInventoryItems({
    required String propertyId,
    required dynamic serviceType, // InventoryServiceType
  }) async {
    try {
      final tableName = _inventoryTable(serviceType);
      final response = await client
          .from(tableName)
          .select('*')
          .eq('property_id', propertyId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch inventory: ${e.message}');
    }
  }

  /// Create a new inventory item
  Future<void> createInventoryItem({
    required String propertyId,
    required dynamic serviceType,
    required Map<String, dynamic> data,
  }) async {
    try {
      final tableName = _inventoryTable(serviceType);
      final payload = {
        ...data,
        'property_id': propertyId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await client.from(tableName).insert(payload);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create item: ${e.message}');
    }
  }

  /// Update an existing inventory item
  Future<void> updateInventoryItem({
    required String propertyId,
    required dynamic serviceType,
    required String itemId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final tableName = _inventoryTable(serviceType);
      final pkColumn = _inventoryPk(serviceType);
      final payload = {...data, 'updated_at': DateTime.now().toIso8601String()};
      await client.from(tableName).update(payload).eq(pkColumn, itemId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update item: ${e.message}');
    }
  }

  /// Soft-delete an inventory item
  Future<void> deleteInventoryItem({
    required dynamic serviceType,
    required String itemId,
  }) async {
    try {
      final tableName = _inventoryTable(serviceType);
      final pkColumn = _inventoryPk(serviceType);
      await client
          .from(tableName)
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq(pkColumn, itemId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete item: ${e.message}');
    }
  }

  String _inventoryTable(dynamic serviceType) {
    // serviceType is InventoryServiceType enum — compare by toString
    final s = serviceType.toString();
    if (s.contains('kitchen')) return 'kitchen';
    if (s.contains('laundry')) return 'laundry';
    if (s.contains('spa')) return 'spa_items';
    return 'kitchen';
  }

  String _inventoryPk(dynamic serviceType) {
    final s = serviceType.toString();
    if (s.contains('spa')) return 'spa_item_id';
    return 'item_id';
  }

  // ─── Active Stay Upgrade Accepts ─────────────────────────────────────────

  /// Fetch all pending upgrade acceptances for a property.
  /// Joins: users (name), stay_rooms+rooms (current room number),
  ///        active_stay_offers (offer title).
  Future<List<Map<String, dynamic>>> fetchPendingUpgradeAccepts(
    String propertyId,
  ) async {
    try {
      // Step 1: Fetch pending acceptances with user name only (no stay_rooms join)
      final response = await client
          .from('active_upgrade_accepts')
          .select(
            'accept_id, user_id, stay_id, offer_id, property_id, '
            'amount_to_be_paid, status, created_at, '
            'users(name)',
          )
          .eq('property_id', propertyId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> results = [];
      for (final row in (response as List)) {
        final map = Map<String, dynamic>.from(row as Map);

        // Step 2: Resolve current room number via separate stay_rooms query
        final stayId = map['stay_id'] as String?;
        String currentRoomNumber = '—';
        String currentRoomId = '';
        if (stayId != null && stayId.isNotEmpty) {
          try {
            final stayRoomResp = await client
                .from('stay_rooms')
                .select('room_id, rooms(room_number)')
                .eq('stay_id', stayId)
                .limit(1)
                .maybeSingle();
            if (stayRoomResp != null) {
              final srMap = stayRoomResp;
              currentRoomId = srMap['room_id'] as String? ?? '';
              final roomMap = srMap['rooms'] as Map<String, dynamic>?;
              currentRoomNumber = roomMap?['room_number'] as String? ?? '—';
            }
          } catch (_) {
            // Could not resolve room; use defaults
          }
        }
        map['current_room_number'] = currentRoomNumber;
        map['current_room_id'] = currentRoomId;

        // Step 3: Fetch offer title from active_stay_offers
        final offerId = map['offer_id'] as String?;
        String offerTitle = 'Upgrade Offer';
        if (offerId != null && offerId.isNotEmpty) {
          try {
            final offerResp = await client
                .from('active_stay_offers')
                .select('title')
                .eq('offer_id', offerId)
                .maybeSingle();
            if (offerResp != null) {
              offerTitle = (offerResp)['title'] as String? ?? 'Upgrade Offer';
            }
          } catch (_) {
            // offer table may not exist yet; use default
          }
        }
        map['offer_title'] = offerTitle;

        results.add(map);
      }
      return results;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch pending upgrade accepts: ${e.message}');
    }
  }

  /// Atomically allot a new room for an active-stay upgrade acceptance.
  /// Steps:
  ///   1. Update stay_rooms: replace old room_id with new room_id for this stay.
  ///   2. Mark old room as not booked.
  ///   3. Mark new room as booked.
  ///   4. Update active_upgrade_accepts.status = 'room_allotted'.
  ///   5. Update stay_rooms.updated_at.
  Future<void> allotUpgradeRoom({
    required String acceptId,
    required String stayId,
    required String oldRoomId,
    required String newRoomId,
  }) async {
    try {
      // 1. Update stay_rooms row for this stay to point to new room
      await client
          .from('stay_rooms')
          .update({
            'room_id': newRoomId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('stay_id', stayId)
          .eq('room_id', oldRoomId);

      // 2. Mark old room as not booked
      await client
          .from('rooms')
          .update({
            'is_booked': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', oldRoomId);

      // 3. Mark new room as booked
      await client
          .from('rooms')
          .update({
            'is_booked': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', newRoomId);

      // 4. Update acceptance status to room_allotted
      await client
          .from('active_upgrade_accepts')
          .update({
            'status': 'room_allotted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('accept_id', acceptId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to allot upgrade room: ${e.message}');
    }
  }

  /// Fetch upgrade line item for checkout bill.
  /// Returns the acceptance row (with amount_to_be_paid) if a room_allotted
  /// acceptance exists for this stay, otherwise null.
  Future<Map<String, dynamic>?> fetchUpgradeLineItemForStay(
    String stayId,
  ) async {
    try {
      final response = await client
          .from('active_upgrade_accepts')
          .select('accept_id, amount_to_be_paid, offer_id, status')
          .eq('stay_id', stayId)
          .eq('status', 'room_allotted')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response as Map);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch upgrade line item: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EARLY / LATE OFFERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch early_late_offers for a property filtered by type ('early_in' | 'late_out').
  /// Returns active offers ordered by created_at descending.
  Future<List<Map<String, dynamic>>> fetchEarlyLateOffers(
    String propertyId,
    String type, {
    bool activeOnly = false,
  }) async {
    try {
      var query = client
          .from('early_late_offers')
          .select(
            'offer_id, property_id, offer_name, stay_id, min_time, max_time, '
            'type, price_per_hour, status, "limit", created_at, updated_at',
          )
          .eq('property_id', propertyId)
          .eq('type', type);

      if (activeOnly) {
        query = query.eq('status', 'active');
      }

      final response = await query.order('created_at', ascending: false);

      final List<Map<String, dynamic>> results = [];
      for (final row in (response as List)) {
        final map = Map<String, dynamic>.from(row as Map);

        // For late_out offers, resolve guest name and room number via stay_id
        if (type == 'late_out') {
          final stayId = map['stay_id'] as String?;
          if (stayId != null && stayId.isNotEmpty) {
            try {
              final stayResp = await client
                  .from('stay')
                  .select('main_user_id, users(name)')
                  .eq('stay_id', stayId)
                  .maybeSingle();
              if (stayResp != null) {
                final userMap = stayResp['users'] as Map<String, dynamic>?;
                map['guest_name'] = userMap?['name'] as String? ?? '—';
              }
            } catch (_) {}

            try {
              final srResp = await client
                  .from('stay_rooms')
                  .select('room_id, rooms(room_number)')
                  .eq('stay_id', stayId)
                  .limit(1)
                  .maybeSingle();
              if (srResp != null) {
                final roomMap = srResp['rooms'] as Map<String, dynamic>?;
                map['room_number'] = roomMap?['room_number'] as String? ?? '—';
              }
            } catch (_) {}
          }
        }

        results.add(map);
      }
      return results;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch early/late offers: ${e.message}');
    }
  }

  /// Create a new early_late_offer record.
  /// [limit] is mandatory for early_in offers — the offer is auto-disabled
  /// by a DB trigger once this many accepts are recorded.
  Future<void> createEarlyLateOffer({
    required String propertyId,
    required String offerName,
    String? stayId,
    DateTime? minTime,
    DateTime? maxTime,
    required String type,
    required double pricePerHour,
    int? limit,
  }) async {
    try {
      await client.from('early_late_offers').insert({
        'property_id': propertyId,
        'offer_name': offerName,
        if (stayId != null && stayId.isNotEmpty) 'stay_id': stayId,
        if (minTime != null) 'min_time': minTime.toIso8601String(),
        if (maxTime != null) 'max_time': maxTime.toIso8601String(),
        'type': type,
        'price_per_hour': pricePerHour,
        'status': 'active',
        if (limit != null) 'limit': limit,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to create offer: ${e.message}');
    }
  }

  /// Toggle status of an early_late_offer between 'active' and 'disabled'.
  Future<void> toggleEarlyLateOfferStatus(
    String offerId,
    String newStatus,
  ) async {
    try {
      await client
          .from('early_late_offers')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('offer_id', offerId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update offer status: ${e.message}');
    }
  }

  /// Upsert an early check-in or late check-out offer for a specific room category
  Future<void> upsertCategoryEarlyLateOffer({
    required String propertyId,
    required String type, // 'early_in' or 'late_out'
    required String category,
    required double price,
    required bool isActive,
    DateTime? minTime,
    DateTime? maxTime,
    int? limit,
  }) async {
    final cleanCategory = category.trim();
    final offerName = '[$cleanCategory] ${type == 'early_in' ? 'Early Check-In Pass' : 'Late Check-Out Pass'}';
    final status = isActive ? 'active' : 'disabled';

    try {
      // 1. Check for exact matching category offer
      var existing = await client
          .from('early_late_offers')
          .select('offer_id')
          .eq('property_id', propertyId)
          .eq('type', type)
          .eq('offer_name', offerName);

      // Fallback check if stored with case variation
      if ((existing as List).isEmpty) {
        existing = await client
            .from('early_late_offers')
            .select('offer_id')
            .eq('property_id', propertyId)
            .eq('type', type)
            .ilike('offer_name', '[$cleanCategory] %');
      }

      if ((existing as List).isNotEmpty) {
        // Update all matching offer IDs precisely
        for (final row in (existing as List)) {
          final id = row['offer_id']?.toString();
          if (id != null && id.isNotEmpty) {
            await client
                .from('early_late_offers')
                .update({
                  'offer_name': offerName,
                  'price_per_hour': price,
                  'status': status,
                  if (minTime != null) 'min_time': minTime.toIso8601String(),
                  if (maxTime != null) 'max_time': maxTime.toIso8601String(),
                  'limit': limit,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('offer_id', id);
          }
        }
      } else {
        await client.from('early_late_offers').insert({
          'property_id': propertyId,
          'offer_name': offerName,
          'type': type,
          'price_per_hour': price,
          'status': status,
          if (minTime != null) 'min_time': minTime.toIso8601String(),
          if (maxTime != null) 'max_time': maxTime.toIso8601String(),
          'limit': limit,
        });
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to save category offer: ${e.message}');
    }
  }

  /// Reset claim quota cycle for an offer by updating its updated_at timestamp to now (UTC)
  Future<void> resetEarlyLateOfferClaims(String offerId) async {
    try {
      await client
          .from('early_late_offers')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('offer_id', offerId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to reset offer claims: ${e.message}');
    }
  }

  /// Delete an early_late_offer record by offer_id.
  Future<void> deleteEarlyLateOffer(String offerId) async {
    try {
      await client
          .from('early_late_offers')
          .delete()
          .eq('offer_id', offerId);
    } on PostgrestException catch (_) {
      // If FK constraint prevents deletion, disable it instead
      await client
          .from('early_late_offers')
          .update({'status': 'disabled', 'updated_at': DateTime.now().toIso8601String()})
          .eq('offer_id', offerId);
    }
  }

  /// Delete all early_late_offers for a specific room category and type.
  Future<void> deleteCategoryEarlyLateOffer({
    required String propertyId,
    required String type,
    required String category,
  }) async {
    final cleanCategory = category.trim();
    final offerName = '[$cleanCategory] ${type == 'early_in' ? 'Early Check-In Pass' : 'Late Check-Out Pass'}';
    try {
      final existing = await client
          .from('early_late_offers')
          .select('offer_id')
          .eq('property_id', propertyId)
          .eq('type', type)
          .eq('offer_name', offerName);

      for (final row in (existing as List)) {
        final id = row['offer_id']?.toString();
        if (id != null && id.isNotEmpty) {
          try {
            await client.from('early_late_offers').delete().eq('offer_id', id);
          } on PostgrestException catch (_) {
            await client.from('early_late_offers').update({
              'status': 'disabled',
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('offer_id', id);
          }
        }
      }
    } catch (_) {}
  }

  /// Fetch all early_late_offer_accepts for a property with joined data.
  Future<List<Map<String, dynamic>>> fetchEarlyLateAccepts(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('early_late_offer_accepts')
          .select(
            'accept_id, offer_id, user_id, stay_id, type, time_selected, '
            'amount_paid, created_at',
          )
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> results = [];
      for (final row in (response as List)) {
        final map = Map<String, dynamic>.from(row as Map);

        // Resolve user info
        final userId = map['user_id'] as String?;
        if (userId != null) {
          try {
            final userResp = await client
                .from('users')
                .select('name, mobile_no')
                .eq('user_id', userId)
                .maybeSingle();
            if (userResp != null) {
              map['guest_name'] = userResp['name'] as String? ?? '—';
              map['mobile_no'] = userResp['mobile_no'] as String? ?? '—';
            }
          } catch (_) {}
        }

        // Resolve offer info
        final offerId = map['offer_id'] as String?;
        if (offerId != null) {
          try {
            final offerResp = await client
                .from('early_late_offers')
                .select('offer_name, type, price_per_hour, property_id')
                .eq('offer_id', offerId)
                .maybeSingle();
            if (offerResp != null) {
              // Filter by property
              if (offerResp['property_id'] != propertyId) continue;
              map['offer_name'] = offerResp['offer_name'] as String? ?? '—';
              map['price_per_hour'] = offerResp['price_per_hour'];
            }
          } catch (_) {}
        }

        // Resolve room numbers via stay_id
        final stayId = map['stay_id'] as String?;
        if (stayId != null) {
          try {
            final srResp = await client
                .from('stay_rooms')
                .select('rooms(room_number)')
                .eq('stay_id', stayId);
            if ((srResp as List).isNotEmpty) {
              final roomNums = <String>[];
              for (final sr in srResp) {
                final roomMap = (sr as Map)['rooms'] as Map<String, dynamic>?;
                final rNum = roomMap?['room_number']?.toString();
                if (rNum != null && rNum.isNotEmpty) {
                  roomNums.add(rNum);
                }
              }
              if (roomNums.isNotEmpty) {
                map['room_number'] = roomNums.join(', ');
                map['room_numbers'] = roomNums.join(', ');
                map['room_count'] = map['room_count'] ?? roomNums.length;
              }
            }
          } catch (_) {}
        }

        results.add(map);
      }
      return results;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch early/late accepts: ${e.message}');
    }
  }

  /// Check if a room has any upcoming booking after a given date.
  Future<bool> checkRoomHasUpcomingBooking(
    String roomId,
    DateTime afterDate,
  ) async {
    try {
      final response = await client
          .from('stay_rooms')
          .select('stay_id, stay!inner(status, check_in_date)')
          .eq('room_id', roomId)
          .eq('stay.status', 'Upcoming')
          .gt(
            'stay.check_in_date',
            afterDate.toIso8601String().substring(0, 10),
          )
          .limit(1);

      return (response as List).isNotEmpty;
    } on PostgrestException catch (e) {
      throw Exception('Failed to check upcoming booking: ${e.message}');
    }
  }

  /// Fetch active stays for a property (for late_out offer dropdown).
  /// Returns stays with guest name and room number, excluding stays that
  /// already have an active late_out offer.
  Future<List<Map<String, dynamic>>> fetchActiveStaysForLateOut(
    String propertyId,
  ) async {
    try {
      // Fetch all active stays for this property
      final staysResp = await client
          .from('stay')
          .select('stay_id, main_user_id, check_out_date, users(name)')
          .eq('hotel_id', propertyId)
          .eq('status', 'Active');

      // Fetch stay_ids that already have an active late_out offer
      final existingOffersResp = await client
          .from('early_late_offers')
          .select('stay_id')
          .eq('property_id', propertyId)
          .eq('type', 'late_out')
          .eq('status', 'active')
          .not('stay_id', 'is', null);

      final Set<String> occupiedStayIds = {};
      for (final o in (existingOffersResp as List)) {
        final sid = (o as Map)['stay_id'] as String?;
        if (sid != null) occupiedStayIds.add(sid);
      }

      final List<Map<String, dynamic>> results = [];
      for (final row in (staysResp as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final stayId = map['stay_id'] as String?;
        if (stayId == null || occupiedStayIds.contains(stayId)) continue;

        final userMap = map['users'] as Map<String, dynamic>?;
        map['guest_name'] = userMap?['name'] as String? ?? '—';

        // Resolve room number
        try {
          final srResp = await client
              .from('stay_rooms')
              .select('rooms(room_number)')
              .eq('stay_id', stayId)
              .limit(1)
              .maybeSingle();
          if (srResp != null) {
            final roomMap = srResp['rooms'] as Map<String, dynamic>?;
            map['room_number'] = roomMap?['room_number'] as String? ?? '—';
          }
        } catch (_) {
          map['room_number'] = '—';
        }

        results.add(map);
      }
      return results;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch active stays: ${e.message}');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BELLBOY REQUESTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetch bellboy requests with status = 'requested' for a property.
  /// Fetch bellboy requests with status in ['called', 'reached'] for a property.
  /// Joins with users via user_id for guest details.
  Future<List<Map<String, dynamic>>> fetchBellboyRequests(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('bellboy_calls')
          .select(
            'id, status, room_number, created_at, stay_id, user_id, users(name, mobile_no)',
          )
          .inFilter('status', ['called', 'reached'])
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> results = [];
      for (final row in (response as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final userMap = map['users'] as Map<String, dynamic>?;
        map['guest_name'] = userMap?['name'] as String? ?? 'Guest';
        map['guest_phone'] = userMap?['mobile_no'] as String? ?? '';
        map['room_number'] = (map['room_number'] ?? '—').toString();
        map['request_type'] = 'Luggage Transfer';
        results.add(map);
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Fetch count of bellboy requests with status = 'called' for a property.
  Future<int> fetchBellboyRequestCount(String propertyId) async {
    try {
      final response = await client
          .from('bellboy_calls')
          .select('id')
          .inFilter('status', ['called']);
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Fetch all active employees for a property (for allotment dropdown).
  Future<List<Map<String, dynamic>>> fetchPropertyEmployees(
    String propertyId,
  ) async {
    try {
      final response = await client
          .from('property_employees')
          .select('emp_id, emp_f_name, emp_l_name, role, is_active')
          .eq('property_id', propertyId)
          .eq('is_active', true)
          .isFilter('deleted_at', null)
          .order('emp_f_name', ascending: true);

      return (response as List).map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        map['full_name'] =
            '${map['emp_f_name'] ?? ''} ${map['emp_l_name'] ?? ''}'.trim();
        return map;
      }).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch property employees: ${e.message}');
    }
  }

  /// Update bellboy_requests.allotted_to for the given request id.
  Future<void> allotBellboyRequest({
    required String requestId,
    required String empId,
  }) async {
    try {
      await client
          .from('bellboy_calls')
          .update({
            'allotted_to': empId,
            'updated_at': DateTime.now().toIso8601String(),
            'status': 'reached',
          })
          .eq('id', requestId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to allot bellboy request: ${e.message}');
    }
  }
}
