import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../widgets/status_badge_widget.dart';
import './dashboard_app_bar_widget.dart';
import '../../../services/supabase_service.dart';

class ManagerDashboardWidget extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String employeeName;
  final String propertyName;
  final String propertyId;
  final String serviceId;
  final int selectedSection;
  final bool isTablet;
  final Function(int) onSectionChanged;

  const ManagerDashboardWidget({
    super.key,
    required this.scaffoldKey,
    required this.employeeName,
    required this.propertyName,
    required this.propertyId,
    required this.serviceId,
    required this.selectedSection,
    required this.isTablet,
    required this.onSectionChanged,
  });

  @override
  State<ManagerDashboardWidget> createState() => _ManagerDashboardWidgetState();
}

class _ManagerDashboardWidgetState extends State<ManagerDashboardWidget>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _entranceController;

  // Three categorized order lists
  List<Map<String, dynamic>> _newOrders = [];
  List<Map<String, dynamic>> _unallottedOrders = [];
  List<Map<String, dynamic>> _allottedOrders = [];

  List<Map<String, dynamic>> _serviceEmployees = [];

  // orderId -> employeeId (for local UI state before save)
  final Map<String, String> _pendingAllotments = {};

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchManagerOrders(
          propertyId: widget.propertyId,
          serviceDeptId: widget.serviceId.isNotEmpty ? widget.serviceId : null,
        ),
        SupabaseService.instance.fetchEmployees(widget.propertyId),
      ]);

      final ordersMap = results[0] as Map<String, List<Map<String, dynamic>>>;
      final allEmployees = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _newOrders = ordersMap['newOrders'] ?? [];
          _unallottedOrders = ordersMap['unallottedOrders'] ?? [];
          _allottedOrders = ordersMap['allottedOrders'] ?? [];

          // Filter to SERVICE_EMPLOYEE role only, same service dept as manager
          _serviceEmployees = allEmployees.where((e) {
            final isEmployee = e['role'] == 'SERVICE_EMPLOYEE';
            final isActive = e['is_active'] == true;
            if (widget.serviceId.isNotEmpty) {
              return isEmployee &&
                  isActive &&
                  e['service_dept']?.toString() == widget.serviceId;
            }
            return isEmployee && isActive;
          }).toList();

          _isLoading = false;
        });
        _entranceController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        _entranceController.forward();
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        DashboardAppBarWidget(
          scaffoldKey: widget.scaffoldKey,
          title: widget.selectedSection == 0
              ? 'Dashboard'
              : widget.selectedSection == 1
              ? 'New Orders'
              : widget.selectedSection == 2
              ? 'Allot Orders'
              : 'Track Orders',
          subtitle: widget.propertyName,
          roleColor: AppTheme.managerColor,
          roleLabel: 'Service Manager',
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
                : _buildSectionContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent() {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Color(0xFFEF4444),
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load orders',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Retry',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.managerColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }
    switch (widget.selectedSection) {
      case 0:
        return _buildOverview();
      case 1:
        return _buildNewOrders();
      case 2:
        return _buildAllotOrders();
      case 3:
        return _buildTrackOrders();
      default:
        return _buildOverview();
    }
  }

  // ─── OVERVIEW ────────────────────────────────────────────────────────────

  Widget _buildOverview() {
    final newCount = _newOrders.length;
    final unallottedCount = _unallottedOrders.length;
    final allottedCount = _allottedOrders.length;
    final totalAttention = newCount + unallottedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.managerColor.withAlpha(60),
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
                      'Service Manager',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.employeeName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (totalAttention > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '$totalAttention orders need attention',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.manage_accounts_rounded,
                color: Colors.white54,
                size: 40,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _buildKpi(
                'New Orders',
                '$newCount',
                AppTheme.warning,
                AppTheme.warningContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpi(
                'Pending Allot',
                '$unallottedCount',
                AppTheme.primary,
                AppTheme.primaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpi(
                'In Progress',
                '$allottedCount',
                AppTheme.success,
                AppTheme.successContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // New orders preview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'New Orders',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (newCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$newCount pending',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.error,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_newOrders.isEmpty)
          EmptyStateWidget(
            icon: Icons.check_circle_rounded,
            title: 'All caught up!',
            description: 'No new orders at the moment.',
          )
        else
          ..._newOrders
              .take(3)
              .map((o) => _buildOrderCard(o, showAcceptReject: true)),

        if (unallottedCount > 0) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pending Allotment',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$unallottedCount unassigned',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._unallottedOrders
              .take(2)
              .map((o) => _buildOrderCard(o, showAllotButton: true)),
        ],

        const SizedBox(height: 20),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── SECTION 1: NEW ORDERS (status = ordered) ────────────────────────────

  Widget _buildNewOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'New Orders',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Accept or reject incoming service requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 20),

        if (_newOrders.isEmpty)
          EmptyStateWidget(
            icon: Icons.inbox_rounded,
            title: 'No new orders',
            description: 'All incoming orders have been processed.',
          )
        else
          ..._newOrders.map((o) => _buildOrderCard(o, showAcceptReject: true)),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── SECTION 2: ALLOT ORDERS ─────────────────────────────────────────────
  // Shows: (a) unallotted in_progress orders, (b) newly accepted (ordered) orders for allotment

  Widget _buildAllotOrders() {
    // Orders eligible for allotment: unallotted in_progress + new orders
    final forAllotment = [..._unallottedOrders, ..._newOrders];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Allot Orders',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Assign service employees to orders',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 20),

        if (_serviceEmployees.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warningContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: AppTheme.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No service employees found for this department.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (forAllotment.isEmpty)
          EmptyStateWidget(
            icon: Icons.assignment_turned_in_rounded,
            title: 'All orders assigned',
            description: 'No orders pending allotment.',
          )
        else
          ...forAllotment.map((order) => _buildAllotCard(order)),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAllotCard(Map<String, dynamic> order) {
    final orderId = order['so_id'] as String? ?? '';
    final roomNumber = order['room_number'] as String? ?? '-';
    final serviceName = order['serv_name'] as String? ?? 'Service';
    final status = order['status'] as String? ?? 'ordered';
    final resolvedRoomId = order['resolved_room_id'] as String? ?? '';
    final amount = (order['so_total'] as num?)?.toDouble() ?? 0.0;
    final allottedEmpId = _pendingAllotments[orderId];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: allottedEmpId != null
              ? AppTheme.managerColor.withAlpha(80)
              : AppTheme.outline,
        ),
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
          Row(
            children: [
              _orderIdBadge(orderId),
              const SizedBox(width: 8),
              _roomBadge(roomNumber),
              const Spacer(),
              StatusBadgeWidget(
                status: status == 'ordered'
                    ? BadgeStatus.pending
                    : BadgeStatus.inProgress,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            serviceName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (amount > 0) ...[
            const SizedBox(height: 2),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.managerColor,
              ),
            ),
          ],
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: allottedEmpId,
            hint: Text(
              'Assign to employee',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
            onChanged: (empId) async {
              if (empId == null) return;
              final emp = _serviceEmployees.firstWhere(
                (e) => e['emp_id'] == empId,
                orElse: () => {},
              );
              if (emp.isEmpty) return;

              // If order is still 'ordered', accept it first
              if (status == 'ordered') {
                try {
                  await SupabaseService.instance.updateOrderStatus(
                    orderId,
                    'in_progress',
                  );
                } catch (_) {}
              }

              try {
                final session = SupabaseService.instance.currentSession;
                await SupabaseService.instance.createOrderAllotment(
                  orderId: orderId,
                  employeeId: empId,
                  alloterEmployeeId: session?.empId ?? empId,
                  roomId: resolvedRoomId.isNotEmpty ? resolvedRoomId : empId,
                  orderPrice: amount,
                );
                setState(() => _pendingAllotments[orderId] = empId);
                Fluttertoast.showToast(
                  msg: 'Order assigned to ${emp['full_name']}',
                  backgroundColor: AppTheme.success,
                  textColor: Colors.white,
                );
                _loadData();
              } catch (e) {
                Fluttertoast.showToast(
                  msg: 'Failed to assign: $e',
                  backgroundColor: AppTheme.error,
                  textColor: Colors.white,
                );
              }
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.managerColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: _serviceEmployees.map((emp) {
              final isActive = emp['is_active'] == true;
              final name = emp['full_name'] as String? ?? 'Unknown';
              return DropdownMenuItem<String>(
                value: emp['emp_id'] as String,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── SECTION 3: TRACK ORDERS (in_progress + allotted) ───────────────────

  Widget _buildTrackOrders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Order Tracking',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Live status of allotted service orders',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 20),

        if (_allottedOrders.isEmpty)
          EmptyStateWidget(
            icon: Icons.track_changes_rounded,
            title: 'No orders in progress',
            description: 'Allotted orders will appear here.',
          )
        else
          ..._allottedOrders.map((order) => _buildTrackCard(order)),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTrackCard(Map<String, dynamic> order) {
    final orderId = order['so_id'] as String? ?? '';
    final roomNumber = order['room_number'] as String? ?? '-';
    final serviceName = order['serv_name'] as String? ?? 'Service';
    final empName = order['allotted_employee_name'] as String? ?? 'Unknown';
    final createdAt = order['created_at'] as String? ?? '';
    final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';
    final phone = order['user_phone_no'] as String? ?? '';
    final amount = (order['so_total'] as num?)?.toDouble() ?? 0.0;
    final items =
        (order['service_order_items'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.managerColor.withAlpha(40)),
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
              _orderIdBadge(orderId),
              const SizedBox(width: 8),
              _roomBadge(roomNumber),
              const Spacer(),
              Text(
                timeStr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            serviceName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.person_rounded,
                size: 13,
                color: AppTheme.managerColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Assigned to: $empName',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.managerColor,
                ),
              ),
              if (phone.isNotEmpty) ...[
                const Spacer(),
                Text(
                  phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ],
            ],
          ),
          if (items.isNotEmpty) _buildOrderItemsSection(items, amount),
          const SizedBox(height: 14),

          // Progress steps
          Row(
            children: [
              _buildTrackStep('Received', 0, 1, Icons.receipt_rounded),
              _buildTrackConnector(true),
              _buildTrackStep('In Progress', 1, 1, Icons.settings_rounded),
              _buildTrackConnector(false),
              _buildTrackStep('Delivered', 2, 1, Icons.check_circle_rounded),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(orderId, 'delivered'),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: Text(
                'Mark Delivered',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED ORDER CARD ───────────────────────────────────────────────────

  Widget _buildOrderCard(
    Map<String, dynamic> order, {
    bool showAcceptReject = false,
    bool showAllotButton = false,
  }) {
    final status = order['status'] as String? ?? 'ordered';
    final isOrdered = status == 'ordered';
    final orderId = order['so_id'] as String? ?? '';
    final roomNumber = order['room_number'] as String? ?? '-';
    final serviceName = order['serv_name'] as String? ?? 'Service';
    final amount = (order['so_total'] as num?)?.toDouble() ?? 0.0;
    final createdAt = order['created_at'] as String? ?? '';
    final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';
    final phone = order['user_phone_no'] as String? ?? '';
    final items =
        (order['service_order_items'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOrdered ? AppTheme.warning.withAlpha(100) : AppTheme.outline,
          width: isOrdered ? 1.5 : 1,
        ),
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
          Row(
            children: [
              _orderIdBadge(orderId),
              const SizedBox(width: 8),
              _roomBadge(roomNumber),
              const Spacer(),
              StatusBadgeWidget(
                status: isOrdered
                    ? BadgeStatus.pending
                    : status == 'in_progress'
                    ? BadgeStatus.inProgress
                    : status == 'cancelled'
                    ? BadgeStatus.cancelled
                    : BadgeStatus.delivered,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            serviceName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (phone.isNotEmpty)
                Text(
                  phone,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              const Spacer(),
              if (amount > 0)
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) _buildOrderItemsSection(items, amount),
          if (showAcceptReject && isOrdered) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.outlineVariant),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(orderId),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(
                      'Reject',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(orderId, 'in_progress'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      'Accept',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.managerColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (showAllotButton) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.outlineVariant),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onSectionChanged(2),
                icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                label: Text(
                  'Allot Now',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection(
    List<Map<String, dynamic>> items,
    double orderTotal,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppTheme.outlineVariant),
        const SizedBox(height: 10),
        Text(
          'Items Ordered',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((item) {
          final itemName = item['item_name'] as String? ?? '-';
          final qty = (item['qty'] as num?)?.toInt() ?? 1;
          final cost = (item['cost'] as num?)?.toDouble();
          final itemSp = (item['item_sp'] as num?)?.toDouble() ?? 0.0;
          final lineTotal = cost ?? (qty * itemSp);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    itemName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '× $qty',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₹${lineTotal.toStringAsFixed(0)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Total: ₹${orderTotal.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.managerColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  Widget _orderIdBadge(String orderId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#${orderId.isNotEmpty ? orderId.substring(0, orderId.length.clamp(0, 8)).toUpperCase() : '-'}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _roomBadge(String roomNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bed_rounded,
            size: 11,
            color: AppTheme.onSurfaceMuted,
          ),
          const SizedBox(width: 4),
          Text(
            'Room $roomNumber',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.surface,
        title: Text(
          'Reject Order',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Cancel this order? This cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Back',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateOrderStatus(orderId, 'cancelled');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              elevation: 0,
            ),
            child: Text(
              'Reject',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      await SupabaseService.instance.updateOrderStatus(orderId, status);
      Fluttertoast.showToast(
        msg: status == 'in_progress'
            ? 'Order accepted'
            : status == 'delivered'
            ? 'Order marked as delivered'
            : 'Order cancelled',
        backgroundColor: status == 'cancelled'
            ? AppTheme.error
            : AppTheme.success,
        textColor: Colors.white,
      );
      _loadData();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed: $e',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }

  Widget _buildTrackStep(String label, int step, int current, IconData icon) {
    final isCompleted = current >= step;
    final isActive = current == step;
    final color = isCompleted ? AppTheme.success : AppTheme.onSurfaceVariant;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppTheme.successContainer
                  : AppTheme.surfaceVariant,
              border: Border.all(
                color: isCompleted ? AppTheme.success : AppTheme.outline,
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: isActive ? AppTheme.success : AppTheme.outline,
      ),
    );
  }

  Widget _buildKpi(String label, String value, Color color, Color bgColor) {
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
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}
