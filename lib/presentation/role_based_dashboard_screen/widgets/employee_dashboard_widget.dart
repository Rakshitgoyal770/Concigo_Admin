import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../services/supabase_service.dart';
import './dashboard_app_bar_widget.dart';

class EmployeeDashboardWidget extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String employeeName;
  final String propertyName;
  final String propertyId;
  final String serviceId;
  final String empId;
  final int selectedSection;
  final bool isTablet;
  final Function(int) onSectionChanged;

  const EmployeeDashboardWidget({
    super.key,
    required this.scaffoldKey,
    required this.employeeName,
    required this.propertyName,
    required this.propertyId,
    required this.serviceId,
    required this.empId,
    required this.selectedSection,
    required this.isTablet,
    required this.onSectionChanged,
  });

  @override
  State<EmployeeDashboardWidget> createState() =>
      _EmployeeDashboardWidgetState();
}

class _EmployeeDashboardWidgetState extends State<EmployeeDashboardWidget>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _entranceController;
  late List<Animation<double>> _cardAnimations;

  // Normalized allotment maps from supabase_service
  List<Map<String, dynamic>> _assignedOrderMaps = [];

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
      final allotments = await SupabaseService.instance.fetchEmployeeAllotments(
        widget.empId,
      );
      if (mounted) {
        setState(() {
          _assignedOrderMaps = allotments;
          _isLoading = false;
        });
        _entranceController.forward();
      }
    } catch (e) {
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

  int get _pendingCount => _assignedOrderMaps.where((o) {
    final status = o['status'] as String? ?? '';
    return status == 'in_progress' || status == 'ordered';
  }).length;

  int get _deliveredCount => _assignedOrderMaps.where((o) {
    return (o['status'] as String?) == 'delivered';
  }).length;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        DashboardAppBarWidget(
          scaffoldKey: widget.scaffoldKey,
          title: widget.selectedSection == 0 ? 'My Dashboard' : 'My Orders',
          subtitle: widget.propertyName,
          roleColor: AppTheme.employeeColor,
          roleLabel: 'Service Employee',
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
                colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.employeeColor.withAlpha(60),
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
                    Icons.room_service_rounded,
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
                  '${_assignedOrderMaps.length}',
                  Icons.assignment_rounded,
                  AppTheme.employeeColor,
                  AppTheme.employeeContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'In Progress',
                  '$_pendingCount',
                  Icons.pending_actions_rounded,
                  AppTheme.warning,
                  AppTheme.warningContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Delivered',
                  '$_deliveredCount',
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
              'Orders Assigned to Me',
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

        if (_assignedOrderMaps.isEmpty)
          EmptyStateWidget(
            icon: Icons.room_service_rounded,
            title: 'No orders assigned',
            description: 'You have no active orders. Check back soon.',
          )
        else
          ..._assignedOrderMaps.asMap().entries.map((entry) {
            return _buildAnimatedCard(
              index: entry.key + 2,
              child: _buildAssignedOrderCard(entry.value),
            );
          }),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAssignedOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'ordered';
    final isDelivered = status == 'delivered';
    final roomNumber = order['room_number'] as String? ?? '-';
    final floor = order['floor'] as String? ?? '-';
    final serviceName = order['service_name'] as String? ?? 'Service';
    final amount = (order['order_price'] as num?)?.toDouble() ?? 0.0;
    final soTotal = (order['so_total'] as num?)?.toDouble() ?? amount;
    final phone = order['user_phone_no'] as String? ?? '';
    final createdAt = order['created_at'] as String? ?? '';
    final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';
    final soId = order['so_id'] as String? ?? '';
    final shortId = soId.isNotEmpty
        ? '#${soId.substring(0, 8).toUpperCase()}'
        : '-';
    final items =
        (order['service_order_items'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDelivered
              ? AppTheme.successContainer
              : AppTheme.employeeColor.withAlpha(60),
          width: isDelivered ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDelivered
                ? Colors.black.withAlpha(6)
                : AppTheme.employeeColor.withAlpha(20),
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
              color: isDelivered
                  ? AppTheme.successContainer
                  : AppTheme.employeeContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDelivered
                      ? Icons.check_circle_rounded
                      : Icons.pending_actions_rounded,
                  size: 16,
                  color: isDelivered
                      ? AppTheme.success
                      : AppTheme.employeeColor,
                ),
                const SizedBox(width: 8),
                Text(
                  shortId,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDelivered
                        ? AppTheme.success
                        : AppTheme.employeeColor,
                  ),
                ),
                const Spacer(),
                Text(
                  timeStr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: isDelivered
                        ? AppTheme.success.withAlpha(180)
                        : AppTheme.employeeColor.withAlpha(180),
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
                    _buildInfoPill(
                      Icons.bed_rounded,
                      'Room $roomNumber',
                      AppTheme.receptionColor,
                      AppTheme.receptionContainer,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoPill(
                      Icons.layers_rounded,
                      'Floor $floor',
                      AppTheme.onSurfaceMuted,
                      AppTheme.surfaceVariant,
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
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Guest: $phone',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],

                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                        'Total: ₹${soTotal.toStringAsFixed(0)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.employeeColor,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1, color: AppTheme.outlineVariant),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Amount',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ),
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    if (!isDelivered)
                      ElevatedButton.icon(
                        onPressed: () => _confirmDelivery(order),
                        icon: const Icon(Icons.check_rounded, size: 16),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppTheme.success,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Delivered',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelivery(Map<String, dynamic> order) {
    final soId = order['so_id'] as String? ?? '';
    final serviceName = order['service_name'] as String? ?? 'Service';
    final roomNumber = order['room_number'] as String? ?? '-';
    final phone = order['user_phone_no'] as String? ?? '';
    final shortId = soId.isNotEmpty
        ? '#${soId.substring(0, 8).toUpperCase()}'
        : '-';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.surface,
        title: Text(
          'Confirm Delivery',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mark this order as delivered?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortId,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    serviceName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Room $roomNumber${phone.isNotEmpty ? ' · $phone' : ''}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _markDelivered(soId, order);
            },
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(
              'Confirm Delivery',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markDelivered(String soId, Map<String, dynamic> order) async {
    try {
      await SupabaseService.instance.updateOrderStatus(soId, 'delivered');
      // Update local state immediately
      setState(() {
        final idx = _assignedOrderMaps.indexWhere((o) => o['so_id'] == soId);
        if (idx != -1) {
          _assignedOrderMaps[idx] = {
            ..._assignedOrderMaps[idx],
            'status': 'delivered',
          };
        }
      });
      Fluttertoast.showToast(
        msg: 'Order marked as delivered!',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to update: $e',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }

  Widget _buildInfoPill(
    IconData icon,
    String label,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
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
