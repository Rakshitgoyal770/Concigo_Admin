import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../services/supabase_service.dart';
import './dashboard_app_bar_widget.dart';
import './billing_widgets.dart';

class LaundryManagerDashboardWidget extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String employeeName;
  final String propertyName;
  final String propertyId;
  final String empId;
  final String? serviceId;
  final int selectedSection;
  final bool isTablet;
  final Function(int) onSectionChanged;

  const LaundryManagerDashboardWidget({
    super.key,
    required this.scaffoldKey,
    required this.employeeName,
    required this.propertyName,
    required this.propertyId,
    required this.empId,
    this.serviceId,
    required this.selectedSection,
    required this.isTablet,
    required this.onSectionChanged,
  });

  @override
  State<LaundryManagerDashboardWidget> createState() =>
      _LaundryManagerDashboardWidgetState();
}

class _LaundryManagerDashboardWidgetState
    extends State<LaundryManagerDashboardWidget>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _entranceController;

  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _employees = [];
  String? _errorMessage;
  String _statusFilter = 'all';

  static const Color _laundryColor = Color(0xFF0891B2);
  static const Color _laundryContainer = Color(0xFFECFEFF);

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
        SupabaseService.instance.fetchLaundryRequests(
          propertyId: widget.propertyId,
        ),
        SupabaseService.instance.fetchLaundryEmployees(widget.propertyId),
      ]);
      if (mounted) {
        setState(() {
          _requests = results[0];
          _employees = results[1];
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

  List<Map<String, dynamic>> get _filteredRequests {
    if (_statusFilter == 'all') return _requests;
    if (_statusFilter == 'pending') {
      return _requests.where((r) => r['status'] == 'requested').toList();
    }
    if (_statusFilter == 'assigned') {
      return _requests
          .where(
            (r) =>
                r['assigned_to'] != null &&
                r['status'] != 'completed' &&
                r['status'] != 'cancelled',
          )
          .toList();
    }
    if (_statusFilter == 'completed') {
      return _requests.where((r) => r['status'] == 'completed').toList();
    }
    return _requests;
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
              ? 'Laundry Requests'
              : widget.selectedSection == 2
              ? 'Assign Staff'
              : 'Billing',
          subtitle: widget.propertyName,
          roleColor: _laundryColor,
          roleLabel: 'Laundry Manager',
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
              'Failed to load requests',
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
                backgroundColor: _laundryColor,
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
        return _buildRequestsList();
      case 2:
        return _buildAssignSection();
      case 3:
        return _buildBillingSection();
      default:
        return _buildOverview();
    }
  }

  Widget _buildOverview() {
    final pending = _requests.where((r) => r['status'] == 'requested').length;
    final assigned = _requests
        .where(
          (r) =>
              r['assigned_to'] != null &&
              r['status'] != 'completed' &&
              r['status'] != 'cancelled',
        )
        .length;
    final completed = _requests.where((r) => r['status'] == 'completed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
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
                      'Laundry Manager',
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
                    if (pending > 0)
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
                          '$pending requests need attention',
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
                Icons.local_laundry_service_rounded,
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
                'Pending',
                '$pending',
                AppTheme.warning,
                AppTheme.warningContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpi(
                'Assigned',
                '$assigned',
                _laundryColor,
                _laundryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildKpi(
                'Completed',
                '$completed',
                AppTheme.success,
                AppTheme.successContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Recent Requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (_requests.isEmpty)
          EmptyStateWidget(
            icon: Icons.local_laundry_service_rounded,
            title: 'No laundry requests',
            description: 'Laundry requests will appear here.',
          )
        else
          ..._requests.take(4).map((r) => _buildRequestCard(r)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRequestsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Laundry Requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage and assign laundry requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 16),
        _buildFilterTabs(),
        const SizedBox(height: 16),
        if (_filteredRequests.isEmpty)
          EmptyStateWidget(
            icon: Icons.local_laundry_service_rounded,
            title: 'No requests',
            description: 'No laundry requests match this filter.',
          )
        else
          ..._filteredRequests.map((r) => _buildRequestCard(r)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAssignSection() {
    final unassigned = _requests
        .where(
          (r) =>
              r['assigned_to'] == null &&
              r['status'] != 'completed' &&
              r['status'] != 'cancelled',
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Assign Staff',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Assign laundry employees to requests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 20),
        if (_employees.isEmpty)
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
                    'No laundry employees found.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (unassigned.isEmpty)
          EmptyStateWidget(
            icon: Icons.assignment_turned_in_rounded,
            title: 'All assigned',
            description: 'No unassigned laundry requests.',
          )
        else
          ...unassigned.map((r) => _buildAssignCard(r)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBillingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Billing',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Create offline bills for laundry services',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 20),
        BillingFormWidget(
          propertyId: widget.propertyId,
          empId: widget.empId,
          serviceId: widget.serviceId ?? '',
          accentColor: _laundryColor,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFilterTabs() {
    final tabs = [
      ('all', 'All'),
      ('pending', 'Pending'),
      ('assigned', 'Assigned'),
      ('completed', 'Completed'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isActive = _statusFilter == tab.$1;
          return GestureDetector(
            onTap: () => setState(() => _statusFilter = tab.$1),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? _laundryColor : AppTheme.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isActive ? _laundryColor : AppTheme.outline,
                ),
              ),
              child: Text(
                tab.$2,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.onSurfaceMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final reqId = req['request_id'] as String? ?? '';
    final guestName = req['guest_name'] as String? ?? 'Guest';
    final roomNumber = req['room_number'] as String? ?? '-';
    final mobileNo = req['mobile_no'] as String? ?? '';
    final status = req['status'] as String? ?? 'requested';
    final createdAt = req['created_at'] as String? ?? '';
    final pickupTime = req['preferred_pickup_time'] as String? ?? '-';
    final assignedName = req['assigned_emp_name'] as String?;
    final serviceRequested = req['service_requested'];
    final timeStr = createdAt.length >= 16
        ? createdAt.substring(0, 16).replaceFirst('T', ' ')
        : createdAt;

    final statusColor = _statusColor(status);
    final statusBg = _statusBg(status);

    // Parse service_requested JSONB
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
        border: Border.all(color: _laundryColor.withAlpha(40), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _laundryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_laundry_service_rounded,
                  size: 14,
                  color: _laundryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '#${reqId.substring(0, reqId.length.clamp(0, 8)).toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _laundryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
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
                const SizedBox(height: 10),
                if (items.isNotEmpty) ...[
                  Text(
                    'Items:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                    const Spacer(),
                    if (mobileNo.isNotEmpty)
                      Text(
                        mobileNo,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Requested: $timeStr',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                if (assignedName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_pin_rounded,
                        size: 13,
                        color: _laundryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Assigned: $assignedName',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _laundryColor,
                        ),
                      ),
                    ],
                  ),
                ],
                if (status != 'completed' && status != 'cancelled') ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppTheme.outlineVariant),
                  const SizedBox(height: 10),
                  _buildStatusActions(req),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActions(Map<String, dynamic> req) {
    final status = req['status'] as String? ?? 'requested';
    final reqId = req['request_id'] as String? ?? '';
    return Row(
      children: [
        if (status == 'requested')
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(reqId, 'in_progress'),
              icon: const Icon(Icons.play_arrow_rounded, size: 14),
              label: Text(
                'Start',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _laundryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        if (status == 'in_progress') ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(reqId, 'completed'),
              icon: const Icon(Icons.check_circle_rounded, size: 14),
              label: Text(
                'Complete',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (status != 'cancelled')
          OutlinedButton.icon(
            onPressed: () => _updateStatus(reqId, 'cancelled'),
            icon: const Icon(Icons.close_rounded, size: 14),
            label: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAssignCard(Map<String, dynamic> req) {
    final reqId = req['request_id'] as String? ?? '';
    final guestName = req['guest_name'] as String? ?? 'Guest';
    final roomNumber = req['room_number'] as String? ?? '-';
    final pickupTime = req['preferred_pickup_time'] as String? ?? '-';
    final currentAssignedId = req['assigned_to'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: currentAssignedId != null
              ? _laundryColor.withAlpha(80)
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
          const SizedBox(height: 8),
          Text(
            'Pickup: $pickupTime',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: currentAssignedId,
            hint: Text(
              'Assign to employee',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
            onChanged: (empId) async {
              if (empId == null) return;
              await _assignEmployee(reqId, empId);
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
                borderSide: const BorderSide(color: _laundryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: _employees.map((emp) {
              final name = emp['full_name'] as String? ?? 'Unknown';
              return DropdownMenuItem<String>(
                value: emp['emp_id'] as String,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.success,
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

  Future<void> _assignEmployee(String reqId, String empId) async {
    try {
      final emp = _employees.firstWhere(
        (e) => e['emp_id'] == empId,
        orElse: () => {},
      );
      await SupabaseService.instance.assignLaundryRequest(reqId, empId);
      Fluttertoast.showToast(
        msg: 'Assigned to ${emp['full_name'] ?? 'employee'}',
        backgroundColor: AppTheme.success,
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

  Future<void> _updateStatus(String reqId, String status) async {
    try {
      await SupabaseService.instance.updateLaundryRequestStatus(reqId, status);
      Fluttertoast.showToast(
        msg: 'Status updated',
        backgroundColor: AppTheme.success,
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

  Color _statusColor(String status) {
    switch (status) {
      case 'requested':
        return AppTheme.warning;
      case 'in_progress':
        return _laundryColor;
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.onSurfaceMuted;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'requested':
        return AppTheme.warningContainer;
      case 'in_progress':
        return _laundryContainer;
      case 'completed':
        return AppTheme.successContainer;
      case 'cancelled':
        return AppTheme.errorContainer;
      default:
        return AppTheme.surfaceVariant;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'requested':
        return 'Requested';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
