import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../services/supabase_service.dart';
import './dashboard_app_bar_widget.dart';

class SpaEmployeeDashboardWidget extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String employeeName;
  final String propertyName;
  final String propertyId;
  final String empId;
  final int selectedSection;
  final bool isTablet;
  final Function(int) onSectionChanged;

  const SpaEmployeeDashboardWidget({
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
  State<SpaEmployeeDashboardWidget> createState() =>
      _SpaEmployeeDashboardWidgetState();
}

class _SpaEmployeeDashboardWidgetState extends State<SpaEmployeeDashboardWidget>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _entranceController;
  late List<Animation<double>> _cardAnimations;

  List<Map<String, dynamic>> _assignedOrders = [];

  static const Color _spaColor = Color(0xFF7C3AED);
  static const Color _spaContainer = Color(0xFFF5F3FF);

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
      final orders = await SupabaseService.instance.fetchAssignedSpaOrders(
        widget.empId,
      );
      if (mounted) {
        setState(() {
          _assignedOrders = orders;
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

  int get _pendingCount => _assignedOrders
      .where((o) => o['status'] == 'enquired' || o['status'] == 'called_back')
      .length;
  int get _servicedCount =>
      _assignedOrders.where((o) => o['status'] == 'serviced').length;

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
          roleColor: _spaColor,
          roleLabel: 'Spa Employee',
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
                colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _spaColor.withAlpha(60),
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
                    Icons.spa_rounded,
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
                  '${_assignedOrders.length}',
                  Icons.assignment_rounded,
                  _spaColor,
                  _spaContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  '$_pendingCount',
                  Icons.pending_actions_rounded,
                  AppTheme.warning,
                  AppTheme.warningContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Serviced',
                  '$_servicedCount',
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
              'My Spa Assignments',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            if (_pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_pendingCount active',
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
        if (_assignedOrders.isEmpty)
          EmptyStateWidget(
            icon: Icons.spa_rounded,
            title: 'No assignments',
            description: 'You have no spa assignments. Check back soon.',
          )
        else
          ..._assignedOrders.asMap().entries.map(
            (entry) => _buildAnimatedCard(
              index: entry.key + 2,
              child: _buildOrderCard(entry.value),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final reqId = order['spa_order_id'] as String? ?? '';
    final guestName = order['guest_name'] as String? ?? 'Guest';
    final roomNumber = order['room_number'] as String? ?? '-';
    final serviceName = order['service_name'] as String? ?? 'Spa Service';
    final slotTime = order['slot_time'] as String? ?? '-';
    final mobileNo = order['mobile_no'] as String? ?? '';
    final status = order['status'] as String? ?? 'enquired';
    final isServiced = status == 'serviced';
    final createdAt = order['created_at'] as String? ?? '';
    final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isServiced
              ? AppTheme.successContainer
              : _spaColor.withAlpha(60),
          width: isServiced ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isServiced
                ? Colors.black.withAlpha(6)
                : _spaColor.withAlpha(20),
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
              color: isServiced ? AppTheme.successContainer : _spaContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isServiced ? Icons.check_circle_rounded : Icons.spa_rounded,
                  size: 16,
                  color: isServiced ? AppTheme.success : _spaColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '#${reqId.isNotEmpty ? reqId.substring(0, reqId.length.clamp(0, 8)).toUpperCase() : '-'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isServiced ? AppTheme.success : _spaColor,
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: isServiced
                        ? AppTheme.success.withAlpha(180)
                        : _spaColor.withAlpha(180),
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
                      _spaColor,
                      _spaContainer,
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
                Text(
                  serviceName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppTheme.onSurfaceMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Slot: $slotTime',
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
                    if (!isServiced && status != 'cancelled')
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
      case 'enquired':
        color = AppTheme.warning;
        bg = AppTheme.warningContainer;
        label = 'Enquired';
        break;
      case 'called_back':
        color = _spaColor;
        bg = _spaContainer;
        label = 'Called Back';
        break;
      case 'serviced':
        color = AppTheme.success;
        bg = AppTheme.successContainer;
        label = 'Serviced';
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
    if (status == 'enquired') {
      nextStatus = 'called_back';
      label = 'Mark Called Back';
    } else if (status == 'called_back') {
      nextStatus = 'serviced';
      label = 'Mark Serviced';
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
        backgroundColor: nextStatus == 'serviced'
            ? AppTheme.success
            : _spaColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  Future<void> _updateStatus(String reqId, String status) async {
    try {
      await SupabaseService.instance.updateSpaOrderStatus(reqId, status);
      setState(() {
        final idx = _assignedOrders.indexWhere(
          (o) => o['spa_order_id'] == reqId,
        );
        if (idx != -1) {
          _assignedOrders[idx] = {..._assignedOrders[idx], 'status': status};
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
