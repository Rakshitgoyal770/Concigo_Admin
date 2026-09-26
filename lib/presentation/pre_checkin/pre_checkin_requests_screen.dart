import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/live_heartbeat_badge.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_skeleton_widget.dart';
import './pre_checkin_detail_screen.dart';

class PreCheckinRequestsScreen extends StatefulWidget {
  final String propertyId;
  final String propertyName;

  const PreCheckinRequestsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<PreCheckinRequestsScreen> createState() =>
      _PreCheckinRequestsScreenState();
}

class _PreCheckinRequestsScreenState extends State<PreCheckinRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // 'pending' tab (was 'requested')
  List<Map<String, dynamic>> _requestedList = [];
  // 'approved' tab (was 'accepted')
  List<Map<String, dynamic>> _acceptedList = [];

  Timer? _heartbeatTimer;
  DateTime _lastPulseTime = DateTime.now();
  bool _isSyncing = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();

    // 1. Periodic Heartbeat every 60 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadRequests(silent: true);
    });

    // 2. Realtime WebSocket listener
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    try {
      _realtimeChannel = SupabaseService.instance.client
          .channel('precheckin_screen_heartbeat_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'checkin_requests',
            callback: (payload) {
              debugPrint('⚡ [PreCheckin Screen Heartbeat] Realtime change: ${payload.eventType}');
              _loadRequests(silent: true);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ [PreCheckin Screen Heartbeat] Realtime error: $e');
    }
  }

  void _unsubscribeRealtime() {
    try {
      if (_realtimeChannel != null) {
        SupabaseService.instance.client.removeChannel(_realtimeChannel!);
        _realtimeChannel = null;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _unsubscribeRealtime();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests({bool silent = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    _lastPulseTime = DateTime.now();

    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final supabase = SupabaseService.instance.client;

      // ── Step 1: Resolve stay_ids for this property ──────────────────────
      // checkin_requests has no property_id column directly.
      // We fetch stay_ids from the stay table where hotel_id = propertyId.
      final stayRows = await supabase
          .from('stay')
          .select('stay_id')
          .eq('hotel_id', widget.propertyId);

      final stayIds = List<Map<String, dynamic>>.from(
        stayRows,
      ).map((r) => r['stay_id'] as String).toList();

      if (stayIds.isEmpty) {
        if (mounted) {
          setState(() {
            _requestedList = [];
            _acceptedList = [];
            _isLoading = false;
          });
        }
        return;
      }

      // ── Step 2: Fetch checkin_requests for those stay_ids ────────────────
      // PK is 'id'. JSONB column is 'submitted_req'.
      // Status enum: 'pending' | 'approved' | 'denied'.
      // Join users via the explicit FK hint to avoid ambiguity.
      // NOTE: deleted_at on checkin_requests is NOT NULL (timestamptz without
      // nullable constraint), so .isFilter('deleted_at', null) returns 0 rows.
      // We do NOT filter by deleted_at here.
      final response = await supabase
          .from('checkin_requests')
          .select(
            'id, stay_id, main_user_id, submitted_req, status, remark, '
            'created_at, updated_at, '
            'users!checkin_requests_main_user_id_fkey(name, mobile_no)',
          )
          .inFilter('stay_id', stayIds)
          .inFilter('status', const ['pending', 'approved'])
          .order('created_at', ascending: false);

      final all = List<Map<String, dynamic>>.from(response);
      if (mounted) {
        setState(() {
          // Filter out empty PMS sync placeholders (no submitted guest data)
          bool hasValidSubmission(Map<String, dynamic> r) {
            final sub = r['submitted_req'];
            if (sub is List && sub.isNotEmpty) {
              return true;
            }
            return false;
          }

          _requestedList = all.where((r) => r['status'] == 'pending' && hasValidSubmission(r)).toList();
          _acceptedList = all.where((r) => r['status'] == 'approved' && hasValidSubmission(r)).toList();
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
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
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
              'Checkin Requests',
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
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: LiveHeartbeatBadge(
                lastPulseTime: _lastPulseTime,
                isSyncing: _isSyncing,
                intervalSeconds: 10,
                label: 'LIVE QUEUE',
                onTap: () => _loadRequests(silent: false),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.receptionColor,
          unselectedLabelColor: AppTheme.onSurfaceMuted,
          indicatorColor: AppTheme.receptionColor,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requested'),
                  if (_requestedList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildBadge(_requestedList.length, AppTheme.receptionColor),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Accepted'),
                  if (_acceptedList.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildBadge(_acceptedList.length, AppTheme.success),
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
                _buildList(_requestedList, isRequested: true),
                _buildList(_acceptedList, isRequested: false),
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

  Widget _buildList(
    List<Map<String, dynamic>> items, {
    required bool isRequested,
  }) {
    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: isRequested
            ? Icons.hourglass_empty_rounded
            : Icons.check_circle_outline_rounded,
        title: isRequested ? 'No pending requests' : 'No accepted requests',
        description: isRequested
            ? 'All pre-checkin requests will appear here.'
            : 'Approved requests will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: AppTheme.receptionColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(items[index], isRequested: isRequested);
        },
      ),
    );
  }

  Widget _buildRequestCard(
    Map<String, dynamic> request, {
    required bool isRequested,
  }) {
    // ── Column mapping: checkin_requests ──────────────────────────────────
    // PK:          id            (was request_id)
    // Guest join:  users!checkin_requests_main_user_id_fkey
    // Timestamps:  created_at    (was req_createdat)
    // JSONB:       submitted_req (array of {name, doc_link})
    final requestId = request['id'] as String? ?? '';
    final userMap = request['users'] as Map<String, dynamic>?;
    final mobileNo = userMap?['mobile_no'] as String? ?? 'Unknown';
    final userName = userMap?['name'] as String? ?? 'Guest';
    final stayId = request['stay_id'] as String?;
    final status = request['status'] as String? ?? 'pending';
    final createdAt = request['created_at'] as String? ?? '';

    // submitted_req: JSONB array of {name, doc_link}
    final submittedReq = request['submitted_req'];
    final guestCount = submittedReq is List ? submittedReq.length : 0;

    final shortId = requestId.length >= 8
        ? requestId.substring(0, 8).toUpperCase()
        : requestId.toUpperCase();

    final statusColor = isRequested ? AppTheme.warning : AppTheme.success;
    final statusBg = isRequested
        ? AppTheme.warningContainer
        : AppTheme.successContainer;

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(createdAt).toLocal();
    } catch (_) {}

    final timeLabel = parsedDate != null
        ? '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}'
        : createdAt;

    return GestureDetector(
      onTap: isRequested
          ? () async {
              final approved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => PreCheckinDetailScreen(
                    request: request,
                    propertyId: widget.propertyId,
                    propertyName: widget.propertyName,
                  ),
                ),
              );
              if (approved == true) {
                _loadRequests();
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRequested
                ? AppTheme.warning.withAlpha(80)
                : AppTheme.success.withAlpha(60),
            width: 1.2,
          ),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      isRequested
                          ? Icons.pending_actions_rounded
                          : Icons.check_circle_rounded,
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request #$shortId',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        mobileNo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.outline),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildInfoChip(
                  Icons.person_rounded,
                  userName.length > 16
                      ? '${userName.substring(0, 16)}…'
                      : userName,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  Icons.hotel_rounded,
                  stayId != null
                      ? 'Stay: ${stayId.substring(0, 8).toUpperCase()}'
                      : 'Not Created',
                ),
                const SizedBox(width: 8),
                // ── NEW: co-guest count chip from submitted_req ──────────
                _buildInfoChip(
                  Icons.group_rounded,
                  '$guestCount guest${guestCount == 1 ? '' : 's'}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: AppTheme.onSurfaceMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  timeLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                const Spacer(),
                if (isRequested)
                  Row(
                    children: [
                      Text(
                        'Tap to review',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.receptionColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AppTheme.receptionColor,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.onSurfaceMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
