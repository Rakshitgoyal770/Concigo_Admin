import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../services/supabase_service.dart';
import './dashboard_app_bar_widget.dart';

class LaundryEmployeeDashboardWidget extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String employeeName;
  final String propertyName;
  final String propertyId;
  final String empId;
  final int selectedSection;
  final bool isTablet;
  final Function(int) onSectionChanged;

  const LaundryEmployeeDashboardWidget({
    super.key,
    required this.scaffoldKey,
    required this.employeeName,
    required this.propertyName,
    required this.propertyId,
    required this.empId,
    required this.selectedSection,
    required this.isTablet,
    required this.onSectionChanged,
  });

  @override
  State<LaundryEmployeeDashboardWidget> createState() =>
      _LaundryEmployeeDashboardWidgetState();
}

class _LaundryEmployeeDashboardWidgetState
    extends State<LaundryEmployeeDashboardWidget>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _entranceController;
  late List<Animation<double>> _cardAnimations;

  List<Map<String, dynamic>> _assignedRequests = [];

  static const Color _laundryColor = Color(0xFF0891B2);
  static const Color _laundryContainer = Color(0xFFECFEFF);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardAnimations = List.generate(
      5,
      (i) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(
            i * 0.1,
            (i * 0.1 + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      ),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final requests = await SupabaseService.instance
          .fetchAssignedLaundryRequests(widget.empId);
      if (mounted) {
        setState(() {
          _assignedRequests = requests;
          _isLoading = false;
        });
        _entranceController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _entranceController.forward();
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  int get _activeCount => _assignedRequests
      .where((r) => r['status'] == 'requested' || r['status'] == 'in_progress')
      .length;
  int get _completedCount =>
      _assignedRequests.where((r) => r['status'] == 'completed').length;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        DashboardAppBarWidget(
          scaffoldKey: widget.scaffoldKey,
          title: widget.selectedSection == 0
              ? 'My Dashboard'
              : 'My Assignments',
          subtitle: widget.propertyName,
          roleColor: _laundryColor,
          roleLabel: 'Laundry Employee',
          employeeName: widget.employeeName,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isTablet ? 32 : 20,
              vertical: 8,
            ),
            child: _isLoading
                ? const ListSkeletonWidget(itemCount: 4)
                : _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildAnimatedCard(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0891B2), Color(0xFF22D3EE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _laundryColor.withAlpha(60),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello,',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.employeeName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'On Duty',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.local_laundry_service_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildAnimatedCard(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Assigned',
                  '${_assignedRequests.length}',
                  Icons.assignment_rounded,
                  _laundryColor,
                  _laundryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  '$_activeCount',
                  Icons.pending_actions_rounded,
                  AppTheme.warning,
                  AppTheme.warningContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Completed',
                  '$_completedCount',
                  Icons.check_circle_rounded,
                  AppTheme.success,
                  AppTheme.successContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Laundry Assignments',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            if (_activeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_activeCount active',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_assignedRequests.isEmpty)
          EmptyStateWidget(
            icon: Icons.local_laundry_service_rounded,
            title: 'No assignments',
            description: 'You have no laundry assignments. Check back soon.',
          )
        else
          ..._assignedRequests.asMap().entries.map(
            (entry) => _buildAnimatedCard(
              index: entry.key + 2,
              child: _buildRequestCard(entry.value),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final reqId = req['request_id'] as String? ?? '';
    final guestName = req['guest_name'] as String? ?? 'Guest';
    final roomNumber = req['room_number'] as String? ?? '-';
    final mobileNo = req['mobile_no'] as String? ?? '';
    final status = req['status'] as String? ?? 'requested';
    final isCompleted = status == 'completed';
    final createdAt = req['created_at'] as String? ?? '';
    final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';
    final pickupTime = req['preferred_pickup_time'] as String? ?? '-';
    final serviceRequested = req['service_requested'];

    List<String> items = [];
    if (serviceRequested is List) {
      for (final item in serviceRequested) {
        if (item is Map) {
          final name = item['name'] ?? item['item'] ?? '';
          final qty = item['qty'] ?? item['quantity'] ?? '';
          if (name.toString().isNotEmpty) {
            items.add('$name${qty.toString().isNotEmpty ? ' x$qty' : ''}');
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? AppTheme.successContainer
              : _laundryColor.withAlpha(60),
          width: isCompleted ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? Colors.black.withAlpha(6)
                : _laundryColor.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppTheme.successContainer
                  : _laundryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.local_laundry_service_rounded,
                  size: 16,
                  color: isCompleted ? AppTheme.success : _laundryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '#${reqId.isNotEmpty ? reqId.substring(0, reqId.length.clamp(0, 8)).toUpperCase() : '-'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? AppTheme.success : _laundryColor,
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isCompleted
                        ? AppTheme.success.withAlpha(180)
                        : _laundryColor.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _infoPill(
                      Icons.person_rounded,
                      guestName,
                      _laundryColor,
                      _laundryContainer,
                    ),
                    const SizedBox(width: 8),
                    _infoPill(
                      Icons.bed_rounded,
                      'Room $roomNumber',
                      AppTheme.receptionColor,
                      AppTheme.receptionContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: items
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _laundryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _laundryColor,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppTheme.onSurfaceMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pickup: $pickupTime',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                    if (mobileNo.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        mobileNo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppTheme.outlineVariant),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatusBadge(status),
                    if (!isCompleted && status != 'cancelled')
                      _buildNextStatusButton(reqId, status),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bg;
    String label;
    switch (status) {
      case 'requested':
        color = AppTheme.warning;
        bg = AppTheme.warningContainer;
        label = 'Requested';
        break;
      case 'in_progress':
        color = _laundryColor;
        bg = _laundryContainer;
        label = 'In Progress';
        break;
      case 'completed':
        color = AppTheme.success;
        bg = AppTheme.successContainer;
        label = 'Completed';
        break;
      case 'cancelled':
        color = AppTheme.error;
        bg = AppTheme.errorContainer;
        label = 'Cancelled';
        break;
      default:
        color = AppTheme.onSurfaceMuted;
        bg = AppTheme.surfaceVariant;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNextStatusButton(String reqId, String status) {
    String nextStatus;
    String label;
    if (status == 'requested') {
      nextStatus = 'in_progress';
      label = 'Start';
    } else if (status == 'in_progress') {
      nextStatus = 'completed';
      label = 'Mark Completed';
    } else
      return const SizedBox.shrink();

    return ElevatedButton.icon(
      onPressed: () => _updateStatus(reqId, nextStatus),
      icon: const Icon(Icons.arrow_forward_rounded, size: 14),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: nextStatus == 'completed'
            ? AppTheme.success
            : _laundryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  Future<void> _updateStatus(String reqId, String status) async {
    try {
      await SupabaseService.instance.updateLaundryRequestStatus(reqId, status);
      setState(() {
        final idx = _assignedRequests.indexWhere(
          (r) => r['request_id'] == reqId,
        );
        if (idx != -1) {
          _assignedRequests[idx] = {
            ..._assignedRequests[idx],
            'status': status,
          };
        }
      });
      Fluttertoast.showToast(
        msg: 'Status updated!',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed: $e',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }

  Widget _infoPill(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard({required int index, required Widget child}) {
    if (index >= _cardAnimations.length) return child;
    return FadeTransition(
      opacity: _cardAnimations[index],
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _entranceController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: child,
      ),
    );
  }
}
