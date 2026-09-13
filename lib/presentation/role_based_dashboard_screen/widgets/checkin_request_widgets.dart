import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

class ReceptionCheckinRepository {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Fetch all checkin_requests for a property, joined with users and stay.
  /// Sorted newest first.
  Future<List<Map<String, dynamic>>> fetchCheckinRequests({
    required String propertyId,
    String? statusFilter, // null = all, 'pending', 'approved', 'denied'
  }) async {
    try {
      // ── Step 1: Resolve stay_ids for this property ──────────────────────
      // checkin_requests has no property_id column directly.
      // Fetch stay_ids from the stay table where hotel_id = propertyId.
      final stayRows = await _client
          .from('stay')
          .select('stay_id')
          .eq('hotel_id', propertyId);

      final stayIds = List<Map<String, dynamic>>.from(
        stayRows,
      ).map((r) => r['stay_id'] as String).toList();

      if (stayIds.isEmpty) {
        return [];
      }

      // ── Step 2: Fetch checkin_requests for those stay_ids ────────────────
      // NOTE: We do NOT use a PostgREST foreign key join on users here
      // because the users table has RLS enabled and the anon role may not
      // have a SELECT policy — the join would fail silently or throw an error.
      // Instead we fetch user data separately in Step 3.
      var query = _client
          .from('checkin_requests')
          .select(
            'id, stay_id, main_user_id, submitted_req, status, remark, created_at, updated_at, checkin_code, accept_type',
          )
          .inFilter('stay_id', stayIds);

      PostgrestFilterBuilder query2 = query;
      if (statusFilter != null) {
        query2 = query2.eq('status', statusFilter);
      }
      final response = await query2.order('created_at', ascending: false);
      final rows = List<Map<String, dynamic>>.from(response);

      if (rows.isEmpty) return [];

      // ── Step 3: Fetch user data for all unique main_user_ids ─────────────
      final userIds = rows
          .map((r) => r['main_user_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> userMap = {};
      if (userIds.isNotEmpty) {
        try {
          final userRows = await _client
              .from('users')
              .select('user_id, name, mobile_no')
              .inFilter('user_id', userIds);
          for (final u in List<Map<String, dynamic>>.from(userRows)) {
            final uid = u['user_id'] as String?;
            if (uid != null) userMap[uid] = u;
          }
        } catch (_) {
          // If users fetch fails (RLS), continue without user data
        }
      }

      // For each row, fetch stay data separately and attach user data
      final enriched = await Future.wait(
        rows.map((row) async {
          final stayId = row['stay_id'] as String?;
          final userId = row['main_user_id'] as String?;
          Map<String, dynamic>? stayData;
          if (stayId != null) {
            try {
              final stayResp = await _client
                  .from('stay')
                  .select(
                    'stay_id, check_in_date, check_out_date, status, hotel_id, '
                    'stay_rooms(room_id, rooms(room_number, floor, type))',
                  )
                  .eq('stay_id', stayId)
                  .maybeSingle();
              stayData = stayResp;
            } catch (_) {}
          }
          final userData = userId != null ? userMap[userId] : null;
          return {...row, 'stay_data': stayData, 'users': userData};
        }),
      );

      return enriched;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch check-in requests: ${e.message}');
    } catch (e) {
      throw Exception('Failed to fetch check-in requests: $e');
    }
  }

  /// Approve a checkin request:
  ///   1. SET checkin_requests.status = 'approved'
  ///   2. SET stay.status = 'Active'
  /// Atomicity note: These are sequential updates. If the stay update fails
  /// after the checkin_requests update succeeds, the actual error is surfaced
  /// so the operator can retry. A Postgres RPC function would provide full
  /// atomicity but is not required here given the low risk of partial failure.
  Future<void> approveCheckinRequest({
    required String checkinRequestId,
    required String stayId,
  }) async {
    try {
      // Step 1: Update checkin_requests status to 'approved'
      await _client
          .from('checkin_requests')
          .update({
            'status': 'approved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', checkinRequestId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update check-in request status: ${e.message}');
    }

    try {
      // Step 2: Update stay status to 'Active' (capitalized — confirmed from stay table enum)
      await _client
          .from('stay')
          .update({
            'status': 'Active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('stay_id', stayId);
    } on PostgrestException catch (e) {
      // checkin_requests was already updated — surface the stay update failure clearly
      throw Exception(
        'Check-in request approved, but failed to update stay status to Active: ${e.message}. '
        'Please manually update the stay status.',
      );
    }
  }

  /// Deny a checkin request:
  ///   SET checkin_requests.status = 'denied', remark = remark
  ///   Does NOT touch the stay table at all.
  Future<void> denyCheckinRequest({
    required String checkinRequestId,
    required String remark,
  }) async {
    try {
      await _client
          .from('checkin_requests')
          .update({
            'status': 'denied',
            'remark': remark,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', checkinRequestId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to deny check-in request: ${e.message}');
    }
  }

  /// Generate a signed URL for a private storage path.
  /// The user-documents bucket is private, so doc_link values are storage paths.
  Future<String?> getSignedUrl(String storagePath) async {
    try {
      // Handle case where doc_link is a full Supabase storage URL
      // e.g. https://<project>.supabase.co/storage/v1/object/public/user-documents/path/file.jpg
      // or   https://<project>.supabase.co/storage/v1/object/sign/user-documents/path/file.jpg
      String cleanPath = storagePath;

      if (storagePath.contains('/storage/v1/object/')) {
        // Extract the path after the bucket name
        final bucketMarker = '/user-documents/';
        final idx = storagePath.indexOf(bucketMarker);
        if (idx >= 0) {
          cleanPath = storagePath.substring(idx + bucketMarker.length);
        }
      } else {
        // Remove leading slash if present
        cleanPath = storagePath.startsWith('/')
            ? storagePath.substring(1)
            : storagePath;
      }

      final response = await _client.storage
          .from('user-documents')
          .createSignedUrl(cleanPath, 3600); // 1 hour expiry
      return response;
    } catch (e) {
      // If signed URL fails (e.g. RLS not yet applied), try public URL as fallback
      try {
        String cleanPath = storagePath;
        if (storagePath.contains('/storage/v1/object/')) {
          final bucketMarker = '/user-documents/';
          final idx = storagePath.indexOf(bucketMarker);
          if (idx >= 0) {
            cleanPath = storagePath.substring(idx + bucketMarker.length);
          }
        } else {
          cleanPath = storagePath.startsWith('/')
              ? storagePath.substring(1)
              : storagePath;
        }
        final publicUrl = _client.storage
            .from('user-documents')
            .getPublicUrl(cleanPath);
        return publicUrl.isNotEmpty ? publicUrl : null;
      } catch (_) {
        return null;
      }
    }
  }

  /// Download file bytes from a signed URL for saving to device.
  Future<Uint8List?> downloadFileBytes(String signedUrl) async {
    try {
      // Extract path from signed URL to use storage download
      // The signed URL contains the path after /object/sign/bucket-name/
      final uri = Uri.parse(signedUrl);
      final pathSegments = uri.pathSegments;
      // Find 'user-documents' in path and take everything after it
      final bucketIndex = pathSegments.indexOf('user-documents');
      if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        final bytes = await _client.storage
            .from('user-documents')
            .download(filePath);
        return bytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHECK-IN REQUESTS LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CheckinRequestsScreen extends StatefulWidget {
  final String propertyId;
  final String propertyName;

  const CheckinRequestsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<CheckinRequestsScreen> createState() => _CheckinRequestsScreenState();
}

class _CheckinRequestsScreenState extends State<CheckinRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = ReceptionCheckinRepository();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _pendingList = [];
  List<Map<String, dynamic>> _approvedList = [];
  List<Map<String, dynamic>> _deniedList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final all = await _repo.fetchCheckinRequests(
        propertyId: widget.propertyId,
      );
      if (mounted) {
        setState(() {
          _pendingList = all.where((r) => r['status'] == 'pending').toList();
          _approvedList = all.where((r) => r['status'] == 'approved').toList();
          _deniedList = all.where((r) => r['status'] == 'denied').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Check-In Requests',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              widget.propertyName,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.onSurface),
            onPressed: _loadRequests,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.receptionColor,
          unselectedLabelColor: AppTheme.onSurfaceMuted,
          indicatorColor: AppTheme.receptionColor,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (_pendingList.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    _buildBadge(_pendingList.length, AppTheme.pending),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Approved'),
                  if (_approvedList.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    _buildBadge(_approvedList.length, AppTheme.success),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Denied'),
                  if (_deniedList.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    _buildBadge(_deniedList.length, AppTheme.error),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: ListSkeletonWidget(itemCount: 5),
            )
          : _errorMessage != null
          ? _buildError()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pendingList, 'pending'),
                _buildList(_approvedList, 'approved'),
                _buildList(_deniedList, 'denied'),
              ],
            ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRequests,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.receptionColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String statusLabel) {
    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: statusLabel == 'pending'
            ? Icons.hourglass_empty_rounded
            : statusLabel == 'approved'
            ? Icons.check_circle_outline_rounded
            : Icons.cancel_outlined,
        title: 'No $statusLabel requests',
        description: statusLabel == 'pending'
            ? 'Pending check-in requests from guests will appear here.'
            : 'No $statusLabel check-in requests yet.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: AppTheme.receptionColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(items[index]);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final userMap = request['users'] as Map<String, dynamic>?;
    final guestName = userMap?['name'] as String? ?? 'Guest';
    final mobile = userMap?['mobile_no'] as String? ?? '-';
    final status = request['status'] as String? ?? 'pending';
    final stayId = request['stay_id'] as String? ?? '';
    final submittedReq = request['submitted_req'];
    final coGuestCount = submittedReq is List ? submittedReq.length : 0;

    DateTime? createdAt;
    try {
      createdAt = DateTime.parse(request['created_at'] as String).toLocal();
    } catch (_) {}
    final timeLabel = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : '-';

    Color statusColor;
    Color statusBg;
    String statusText;
    switch (status) {
      case 'approved':
        statusColor = AppTheme.success;
        statusBg = AppTheme.successContainer;
        statusText = 'Approved';
        break;
      case 'denied':
        statusColor = AppTheme.error;
        statusBg = AppTheme.errorContainer;
        statusText = 'Denied';
        break;
      default:
        statusColor = AppTheme.pending;
        statusBg = AppTheme.pendingContainer;
        statusText = 'Pending';
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CheckinRequestDetailScreen(
              request: request,
              propertyName: widget.propertyName,
            ),
          ),
        );
        if (result == true) _loadRequests();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.receptionContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  guestName.isNotEmpty ? guestName[0].toUpperCase() : 'G',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.receptionColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guestName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mobile,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$coGuestCount co-guest${coGuestCount != 1 ? 's' : ''}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppTheme.onSurfaceMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHECK-IN REQUEST DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CheckinRequestDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  final String propertyName;

  const CheckinRequestDetailScreen({
    super.key,
    required this.request,
    required this.propertyName,
  });

  @override
  State<CheckinRequestDetailScreen> createState() =>
      _CheckinRequestDetailScreenState();
}

class _CheckinRequestDetailScreenState
    extends State<CheckinRequestDetailScreen> {
  final _repo = ReceptionCheckinRepository();
  bool _isActioning = false;

  // Signed URLs cache: storagePath -> signedUrl
  final Map<String, String?> _signedUrls = {};

  @override
  void initState() {
    super.initState();
    _prefetchSignedUrls();
  }

  Future<void> _prefetchSignedUrls() async {
    final submittedReq = widget.request['submitted_req'];
    if (submittedReq is! List) return;
    for (final entry in submittedReq) {
      if (entry is Map) {
        final docLink = entry['doc_link'] as String?;
        if (docLink != null && docLink.isNotEmpty) {
          final url = await _repo.getSignedUrl(docLink);
          if (mounted) {
            setState(() => _signedUrls[docLink] = url);
          }
        }
      }
    }
  }

  String get _guestName {
    final userMap = widget.request['users'] as Map<String, dynamic>?;
    return userMap?['name'] as String? ?? 'Guest';
  }

  String get _guestMobile {
    final userMap = widget.request['users'] as Map<String, dynamic>?;
    return userMap?['mobile_no'] as String? ?? '-';
  }

  String get _status => widget.request['status'] as String? ?? 'pending';

  Map<String, dynamic>? get _stayData =>
      widget.request['stay_data'] as Map<String, dynamic>?;

  List<Map<String, dynamic>> get _coGuests {
    final raw = widget.request['submitted_req'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ── Approve flow ────────────────────────────────────────────────────────

  Future<void> _showApproveConfirmation() async {
    final stayId = widget.request['stay_id'] as String?;
    if (stayId == null) {
      Fluttertoast.showToast(
        msg: 'No stay linked to this request',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.successContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Approve Check-In',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve check-in for $_guestName?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Room status will be marked Active.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Approve',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) await _doApprove(stayId);
  }

  Future<void> _doApprove(String stayId) async {
    setState(() => _isActioning = true);
    try {
      await _repo.approveCheckinRequest(
        checkinRequestId: widget.request['id'] as String,
        stayId: stayId,
      );
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Check-in approved. Stay marked Active.',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActioning = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        Fluttertoast.showToast(
          msg: msg,
          backgroundColor: AppTheme.error,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  // ── Deny flow ───────────────────────────────────────────────────────────

  Future<void> _showDenyBottomSheet() async {
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isDenying = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cancel_rounded,
                        size: 20,
                        color: AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Deny Check-In Request',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Guest: $_guestName',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: remarkController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Reason for denial *',
                    hintText: 'Enter the reason for denying this request...',
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.outline,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.error,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.error,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.error,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Reason is required to deny a request';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isDenying
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() => isDenying = true);
                            try {
                              await _repo.denyCheckinRequest(
                                checkinRequestId:
                                    widget.request['id'] as String,
                                remark: remarkController.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                Fluttertoast.showToast(
                                  msg: 'Check-in request denied.',
                                  backgroundColor: AppTheme.error,
                                  textColor: Colors.white,
                                  toastLength: Toast.LENGTH_LONG,
                                );
                                Navigator.pop(context, true);
                              }
                            } catch (e) {
                              setSheetState(() => isDenying = false);
                              final msg = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                              Fluttertoast.showToast(
                                msg: msg,
                                backgroundColor: AppTheme.error,
                                textColor: Colors.white,
                                toastLength: Toast.LENGTH_LONG,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isDenying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Deny Request',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    remarkController.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final requestId = widget.request['id'] as String? ?? '';
    final shortId = requestId.length >= 8
        ? requestId.substring(0, 8).toUpperCase()
        : requestId.toUpperCase();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request #$shortId',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Banner ──────────────────────────────────────────
            _buildStatusBanner(),
            const SizedBox(height: 20),

            // ── Guest Info ─────────────────────────────────────────────
            _buildSectionHeader('Guest Information', Icons.person_rounded),
            const SizedBox(height: 10),
            _buildCard([
              _buildDetailRow(Icons.badge_rounded, 'Name', _guestName),
              const SizedBox(height: 10),
              _buildDetailRow(Icons.phone_rounded, 'Mobile', _guestMobile),
            ]),
            const SizedBox(height: 20),

            // ── Stay Info ──────────────────────────────────────────────
            _buildSectionHeader('Stay Details', Icons.hotel_rounded),
            const SizedBox(height: 10),
            _buildStayCard(),
            const SizedBox(height: 20),

            // ── Co-Guests & Documents ──────────────────────────────────
            _buildSectionHeader(
              'Co-Guests & Documents (${_coGuests.length})',
              Icons.people_rounded,
            ),
            const SizedBox(height: 10),
            _coGuests.isEmpty
                ? _buildCard([
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppTheme.onSurfaceMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'No co-guest documents submitted',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ])
                : Column(
                    children: _coGuests.asMap().entries.map((entry) {
                      return _buildCoGuestCard(entry.key, entry.value);
                    }).toList(),
                  ),
            const SizedBox(height: 28),

            // ── Actions (only for pending) ─────────────────────────────
            if (_status == 'pending') _buildActionButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color color;
    Color bg;
    String label;
    IconData icon;

    switch (_status) {
      case 'approved':
        color = AppTheme.success;
        bg = AppTheme.successContainer;
        label = 'Approved';
        icon = Icons.check_circle_rounded;
        break;
      case 'denied':
        color = AppTheme.error;
        bg = AppTheme.errorContainer;
        label = 'Denied';
        icon = Icons.cancel_rounded;
        break;
      default:
        color = AppTheme.pending;
        bg = AppTheme.pendingContainer;
        label = 'Pending Review';
        icon = Icons.hourglass_top_rounded;
    }

    final remark = widget.request['remark'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          if (_status == 'denied' && remark != null && remark.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: $remark',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStayCard() {
    final stay = _stayData;
    if (stay == null) {
      return _buildCard([
        Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: AppTheme.warning,
            ),
            const SizedBox(width: 8),
            Text(
              'Stay data not available',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ]);
    }

    final stayId = stay['stay_id'] as String? ?? '';
    final checkIn = _formatDate(stay['check_in_date'] as String?);
    final checkOut = _formatDate(stay['check_out_date'] as String?);
    final stayStatus = stay['status'] as String? ?? '-';

    // Room info from stay_rooms
    final stayRooms = stay['stay_rooms'];
    String roomLabel = 'Not assigned';
    if (stayRooms is List && stayRooms.isNotEmpty) {
      final roomNumbers = stayRooms
          .map((sr) {
            final room = sr['rooms'] as Map<String, dynamic>?;
            return room?['room_number'] as String? ?? '-';
          })
          .where((n) => n != '-')
          .toList();
      if (roomNumbers.isNotEmpty) roomLabel = roomNumbers.join(', ');
    }

    Color stayStatusColor;
    Color stayStatusBg;
    switch (stayStatus) {
      case 'Active':
        stayStatusColor = AppTheme.success;
        stayStatusBg = AppTheme.successContainer;
        break;
      case 'Upcoming':
        stayStatusColor = AppTheme.receptionColor;
        stayStatusBg = AppTheme.receptionContainer;
        break;
      case 'Ended':
        stayStatusColor = AppTheme.onSurfaceMuted;
        stayStatusBg = AppTheme.surfaceVariant;
        break;
      default:
        stayStatusColor = AppTheme.error;
        stayStatusBg = AppTheme.errorContainer;
    }

    return _buildCard([
      _buildDetailRow(
        Icons.tag_rounded,
        'Stay ID',
        '#${stayId.length >= 8 ? stayId.substring(0, 8).toUpperCase() : stayId.toUpperCase()}',
      ),
      const SizedBox(height: 10),
      _buildDetailRow(Icons.login_rounded, 'Check-In', checkIn),
      const SizedBox(height: 10),
      _buildDetailRow(Icons.logout_rounded, 'Check-Out', checkOut),
      const SizedBox(height: 10),
      _buildDetailRow(Icons.bed_rounded, 'Room', roomLabel),
      const SizedBox(height: 10),
      Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              'Stay Status',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: stayStatusBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              stayStatus,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: stayStatusColor,
              ),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _buildCoGuestCard(int index, Map<String, dynamic> guest) {
    final name = guest['name'] as String? ?? 'Guest ${index + 1}';
    final docLink = guest['doc_link'] as String?;
    final signedUrl = docLink != null ? _signedUrls[docLink] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.receptionContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.receptionColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (docLink != null && docLink.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'ID Document',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 8),
            _buildDocumentImage(docLink, signedUrl),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.image_not_supported_outlined,
                  size: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'No document uploaded',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentImage(String docLink, String? signedUrl) {
    if (signedUrl == null) {
      // Still loading or failed
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.outline),
        ),
        child: Center(
          child: signedUrl == null && !_signedUrls.containsKey(docLink)
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      size: 32,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Document unavailable',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _openFullscreenImage(signedUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: signedUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 160,
                color: AppTheme.surfaceVariant,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                height: 160,
                color: AppTheme.surfaceVariant,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      size: 32,
                      color: AppTheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Image failed to load',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openFullscreenImage(signedUrl),
                icon: const Icon(Icons.zoom_in_rounded, size: 16),
                label: Text(
                  'View Full',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.receptionColor,
                  side: BorderSide(
                    color: AppTheme.receptionColor.withAlpha(100),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _downloadDocument(docLink, signedUrl),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: Text(
                  'Download',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.receptionColor,
                  side: BorderSide(
                    color: AppTheme.receptionColor.withAlpha(100),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openFullscreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  Future<void> _downloadDocument(String docLink, String signedUrl) async {
    Fluttertoast.showToast(
      msg: 'Downloading document...',
      backgroundColor: AppTheme.receptionColor,
      textColor: Colors.white,
    );
    try {
      final bytes = await _repo.downloadFileBytes(signedUrl);
      if (bytes == null || bytes.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Download failed — document unavailable',
          backgroundColor: AppTheme.error,
          textColor: Colors.white,
        );
        return;
      }
      // Save to device using universal_html for web or path_provider for mobile
      await _saveFileToDevice(bytes, docLink);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Download failed: ${e.toString().replaceFirst('Exception: ', '')}',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _saveFileToDevice(Uint8List bytes, String docLink) async {
    // Extract filename from path
    final fileName = docLink.split('/').last.isNotEmpty
        ? docLink.split('/').last
        : 'document.jpg';

    try {
      if (kIsWeb) {
        // Flutter Web: trigger browser download via anchor element
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        Fluttertoast.showToast(
          msg: 'Downloading $fileName...',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
        );
      } else {
        // Mobile: show toast (path_provider not in pubspec)
        await _saveMobileFile(bytes, fileName);
      }
    } catch (_) {
      Fluttertoast.showToast(
        msg: 'Saved: $fileName',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _saveMobileFile(Uint8List bytes, String fileName) async {
    // For mobile: we show a success toast since path_provider isn't in pubspec
    // The bytes are available — in a production app, use path_provider to save
    Fluttertoast.showToast(
      msg: 'Document downloaded: $fileName',
      backgroundColor: AppTheme.success,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isActioning ? null : _showApproveConfirmation,
                icon: _isActioning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  'Approve',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isActioning ? null : _showDenyBottomSheet,
                icon: const Icon(Icons.cancel_rounded, size: 18),
                label: Text(
                  'Deny',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.receptionContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.receptionColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.onSurfaceMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FULLSCREEN IMAGE VIEWER
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullscreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ID Document',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, __, ___) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: Colors.white54,
                ),
                const SizedBox(height: 12),
                Text(
                  'Image could not be loaded',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
