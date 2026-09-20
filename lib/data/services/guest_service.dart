import '../../services/supabase_service.dart';

/// Domain Service for Guest Lookup, Profile, KYC Verification & Pre-check-in
class GuestService {
  final SupabaseService _supabaseService;

  GuestService({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  String? get currentPropertyId => _supabaseService.currentSession?.propertyId;

  /// Get or atomically create a user profile by phone number, returns user_id
  Future<String> getOrCreateUser(String mobileNo) async {
    return await _supabaseService.getOrCreateUser(mobileNo);
  }

  /// Search user profile by phone number
  Future<Map<String, dynamic>?> searchUserByPhone(String phone) async {
    return await _supabaseService.lookupUserByMobile(phone);
  }

  /// Fetch all check-in / KYC requests with guest documents and stay details
  Future<List<Map<String, dynamic>>> fetchCheckinRequests({String? propertyId}) async {
    final propId = propertyId ?? currentPropertyId;
    if (propId == null) return [];

    try {
      // 1. Fetch stays for this property
      final stays = await _supabaseService.client
          .from('stay')
          .select(
            'stay_id, check_in_date, check_out_date, status, main_user_id, stay_rooms(room_id, rooms(room_number))',
          )
          .eq('hotel_id', propId);

      final stayList = List<Map<String, dynamic>>.from(stays);
      if (stayList.isEmpty) return [];

      final stayMap = {for (var s in stayList) s['stay_id'].toString(): s};
      final stayIds = stayMap.keys.toList();

      // 2. Fetch checkin_requests for these stays
      final requests = await _supabaseService.client
          .from('checkin_requests')
          .select(
            'id, stay_id, main_user_id, submitted_req, status, remark, created_at, updated_at, checkin_code, accept_type, special_req',
          )
          .inFilter('stay_id', stayIds)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final reqList = List<Map<String, dynamic>>.from(requests);
      if (reqList.isEmpty) return [];

      // Deduplicate by stay_id (keeping the newest submission per stay) and filter for pending status case-insensitively
      final Set<String> seenStays = {};
      final List<Map<String, dynamic>> uniqueReqList = [];
      for (final req in reqList) {
        final sId = req['stay_id']?.toString();
        if (sId == null || !stayMap.containsKey(sId)) {
          // Skip orphan checkin requests with no valid stay
          continue;
        }
        final stayStatus = (stayMap[sId]?['status'] ?? '').toString().trim().toLowerCase();
        // If stay is cancelled or checked out, skip from pre-check-in queue
        if (stayStatus == 'cancelled' || stayStatus == 'checked_out') {
          continue;
        }

        final reqStatus = (req['status'] ?? '').toString().trim().toLowerCase();
        // Only include requests awaiting receptionist action (pending / submitted / requested / not yet approved or rejected)
        final isPending = reqStatus == 'pending' ||
            reqStatus == 'submitted' ||
            reqStatus == 'requested' ||
            (reqStatus != 'approved' && reqStatus != 'rejected' && reqStatus != 'denied');

        if (isPending) {
          if (seenStays.add(sId)) {
            uniqueReqList.add(req);
          }
        }
      }

      if (uniqueReqList.isEmpty) return [];

      // 3. Fetch user details for the main_user_ids
      final userIds = uniqueReqList
          .map((r) => r['main_user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> userMap = {};
      if (userIds.isNotEmpty) {
        try {
          final users = await _supabaseService.client
              .from('users')
              .select('user_id, name, mobile_no')
              .inFilter('user_id', userIds);
          for (final u in List<Map<String, dynamic>>.from(users)) {
            final uid = u['user_id']?.toString();
            if (uid != null) userMap[uid] = u;
          }
        } catch (_) {}
      }

      // 4. Merge details into rich checkin request objects
      return uniqueReqList.map((req) {
        final sId = req['stay_id']?.toString();
        final stay = sId != null ? stayMap[sId] : null;
        final uId = req['main_user_id']?.toString();
        final user = uId != null ? userMap[uId] : null;

        String? roomNum;
        String? roomId;
        List<String> roomNumbers = [];
        final stayRooms = stay?['stay_rooms'] as List?;
        if (stayRooms != null && stayRooms.isNotEmpty) {
          roomNumbers = stayRooms
              .map((sr) {
                final rMap = (sr as Map<String, dynamic>)['rooms'] as Map<String, dynamic>?;
                return rMap?['room_number']?.toString();
              })
              .where((n) => n != null && n.isNotEmpty)
              .cast<String>()
              .toList();

          final sr = stayRooms.first as Map<String, dynamic>;
          roomId = sr['room_id']?.toString();
          roomNum = roomNumbers.isNotEmpty ? roomNumbers.join(', ') : null;
        }

        // Parse submitted guests and documents
        final subList = req['submitted_req'] as List?;
        String guestName = user?['name'] ?? 'Guest';
        List<Map<String, dynamic>> documents = [];
        bool hasRealDocs = false;

        if (subList != null && subList.isNotEmpty) {
          final names = subList
              .map((g) => (g['name'] ?? '').toString().trim())
              .where((n) => n.isNotEmpty)
              .toList();
          if (names.isNotEmpty) {
            guestName = names.join(', ');
          }
          documents = List<Map<String, dynamic>>.from(subList);

          for (final doc in documents) {
            final docUrl = (doc['doc_url'] ?? doc['doc_front_url'] ?? doc['document_url'] ?? doc['id_url'] ?? doc['doc_link'] ?? doc['url'] ?? '').toString().trim();
            final selfieUrl = (doc['selfie_url'] ?? doc['photo_url'] ?? '').toString().trim();
            if (docUrl.isNotEmpty || selfieUrl.isNotEmpty) {
              hasRealDocs = true;
              break;
            }
          }
        }

        return {
          ...req,
          'request_id': req['id'],
          'guest_name': guestName,
          'account_user_name': user?['name'] ?? 'Guest',
          'phone_number': user?['mobile_no'] ?? '',
          'room_number': roomNum ?? 'Unassigned',
          'room_id': roomId,
          'is_precheckin': false,
          'has_documents': hasRealDocs,
          'doc_type': hasRealDocs ? 'Government ID Proof' : null,
          'submitted_documents': documents,
          'check_in_date': stay?['check_in_date'],
          'check_out_date': stay?['check_out_date'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Update check-in request status (Approved / Rejected)
  Future<void> updateCheckinRequestStatus({
    required String requestId,
    required String status,
    String? rejectionReason,
  }) async {
    if (requestId.isNotEmpty) {
      final normStatus = status.toLowerCase();
      try {
        await _supabaseService.client.from('checkin_requests').update({
          'status': normStatus,
          'remark': rejectionReason,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);
      } catch (_) {}
    }
  }
}
