import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/loading_skeleton_widget.dart';
import '../../../widgets/status_badge_widget.dart';
import '../../../services/supabase_service.dart';
import '../../../data/services/stay_service.dart';
import './dashboard_app_bar_widget.dart';

class SuperAdminDashboardWidget extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String employeeName;
  final String propertyName;
  final String propertyId;
  final int selectedSection;
  final bool isTablet;
  final Function(int) onSectionChanged;

  const SuperAdminDashboardWidget({
    super.key,
    required this.scaffoldKey,
    required this.employeeName,
    required this.propertyName,
    required this.propertyId,
    required this.selectedSection,
    required this.isTablet,
    required this.onSectionChanged,
  });

  @override
  State<SuperAdminDashboardWidget> createState() =>
      _SuperAdminDashboardWidgetState();
}

class _SuperAdminDashboardWidgetState extends State<SuperAdminDashboardWidget>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _entranceController;
  late List<Animation<double>> _itemAnimations;

  List<Map<String, dynamic>> _employeeMaps = [];
  List<Map<String, dynamic>> _orderMaps = [];
  List<Map<String, dynamic>> _transactionMaps = [];
  List<Map<String, dynamic>> _servicesList = [];
  List<Map<String, dynamic>> _allStays = [];
  Map<String, dynamic> _propertyData = {};

  String _employeeFilter = 'all';
  String _orderStatusFilter = 'all';
  String _txStatusFilter = 'all';
  String _stayTabFilter = 'Upcoming'; // Upcoming, Active, Ended
  final TextEditingController _employeeSearchController =
      TextEditingController();

  // Property edit controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  Timer? _periodicRefreshTimer;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _itemAnimations = List.generate(
      6,
      (i) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(
            i * 0.08,
            (i * 0.08 + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      ),
    );
    _loadData();
    // Auto-refresh SuperAdmin metrics & stays every 30 seconds
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadData(silent: true);
      }
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchEmployees(widget.propertyId),
        SupabaseService.instance.fetchServiceOrders(
          propertyId: widget.propertyId,
        ),
        SupabaseService.instance.fetchPropertyDetails(widget.propertyId),
        SupabaseService.instance.fetchTransactions(widget.propertyId),
        SupabaseService.instance.fetchServices(),
        SupabaseService.instance.fetchAllStaysForSuperAdmin(widget.propertyId),
      ]);

      final employees = results[0] as List<Map<String, dynamic>>;
      final orders = results[1] as List<Map<String, dynamic>>;
      final property = results[2] as Map<String, dynamic>?;
      final transactions = results[3] as List<Map<String, dynamic>>;
      final services = results[4] as List<Map<String, dynamic>>;
      final stays = results[5] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          _employeeMaps = employees;
          _orderMaps = orders;
          _transactionMaps = transactions;
          _servicesList = services;
          _allStays = stays;
          _propertyData = property ?? {'name': widget.propertyName};
          _nameController.text = (_propertyData['name'] as String?) ?? '';
          _addressController.text =
              (_propertyData['address_ln1'] as String?) ?? '';
          _phoneController.text =
              (_propertyData['contact_number'] as String?) ?? '';
          _emailController.text = (_propertyData['email'] as String?) ?? '';
          _isLoading = false;
        });
        if (!silent) _entranceController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) _entranceController.forward();
      }
    }
  }

  @override
  void dispose() {
    _periodicRefreshTimer?.cancel();
    _entranceController.dispose();
    _employeeSearchController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  BadgeStatus _orderBadgeStatus(String status) {
    switch (status) {
      case 'ordered':
        return BadgeStatus.pending;
      case 'in_progress':
        return BadgeStatus.inProgress;
      case 'delivered':
        return BadgeStatus.delivered;
      case 'cancelled':
        return BadgeStatus.cancelled;
      default:
        return BadgeStatus.pending;
    }
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    final query = _employeeSearchController.text.toLowerCase();
    return _employeeMaps.where((e) {
      final matchesFilter =
          _employeeFilter == 'all' || e['role'] == _employeeFilter;
      final matchesSearch =
          query.isEmpty ||
          (e['full_name'] as String).toLowerCase().contains(query) ||
          (e['phone_no'] as String).contains(query) ||
          (e['service_name'] as String).toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orderMaps.where((o) {
      return _orderStatusFilter == 'all' || o['status'] == _orderStatusFilter;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    return _transactionMaps.where((t) {
      return _txStatusFilter == 'all' || t['status'] == _txStatusFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sectionTitles = [
      'Dashboard',
      'Employees',
      'Property Details',
      'Manage Orders',
      'Transactions',
      'Manage Stays',
    ];
    final title = widget.selectedSection < sectionTitles.length
        ? sectionTitles[widget.selectedSection]
        : 'Dashboard';

    return CustomScrollView(
      slivers: [
        DashboardAppBarWidget(
          scaffoldKey: widget.scaffoldKey,
          title: title,
          subtitle: widget.propertyName,
          roleColor: AppTheme.superAdminColor,
          roleLabel: 'Super Admin',
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
    switch (widget.selectedSection) {
      case 0:
        return _buildOverviewSection();
      case 1:
        return _buildEmployeesSection();
      case 2:
        return _buildPropertySection();
      case 3:
        return _buildOrdersSection();
      case 4:
        return _buildTransactionsSection();
      case 5:
        return _buildStaysSection();
      default:
        return _buildOverviewSection();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OVERVIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverviewSection() {
    final pendingOrders = _orderMaps
        .where((o) => o['status'] == 'ordered')
        .length;
    final activeEmployees = _employeeMaps
        .where((e) => e['is_active'] == true)
        .length;
    final totalRevenue = _transactionMaps
        .where((t) => t['status'] == 'paid')
        .fold<double>(
          0.0,
          (sum, t) => sum + ((t['total_amount'] as num?)?.toDouble() ?? 0.0),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildAnimatedItem(index: 0, child: _buildGreetingCard()),
        const SizedBox(height: 16),

        _buildAnimatedItem(
          index: 1,
          child: widget.isTablet
              ? Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        'Total Staff',
                        '${_employeeMaps.length}',
                        Icons.people_rounded,
                        AppTheme.managerColor,
                        AppTheme.managerContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        'Active Staff',
                        '$activeEmployees',
                        Icons.person_rounded,
                        AppTheme.receptionColor,
                        AppTheme.receptionContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        'Pending Orders',
                        '$pendingOrders',
                        Icons.pending_actions_rounded,
                        AppTheme.warning,
                        AppTheme.warningContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        'Revenue',
                        '₹${totalRevenue.toStringAsFixed(0)}',
                        Icons.currency_rupee_rounded,
                        AppTheme.success,
                        AppTheme.successContainer,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            'Total Staff',
                            '${_employeeMaps.length}',
                            Icons.people_rounded,
                            AppTheme.managerColor,
                            AppTheme.managerContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            'Active Staff',
                            '$activeEmployees',
                            Icons.person_rounded,
                            AppTheme.receptionColor,
                            AppTheme.receptionContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            'Pending Orders',
                            '$pendingOrders',
                            Icons.pending_actions_rounded,
                            AppTheme.warning,
                            AppTheme.warningContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            'Revenue',
                            '₹${totalRevenue.toStringAsFixed(0)}',
                            Icons.currency_rupee_rounded,
                            AppTheme.success,
                            AppTheme.successContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 24),

        _buildAnimatedItem(
          index: 2,
          child: _buildSectionHeader('Quick Actions'),
        ),
        const SizedBox(height: 12),

        _buildAnimatedItem(
          index: 3,
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Manage Employees',
                  Icons.people_rounded,
                  AppTheme.superAdminColor,
                  AppTheme.superAdminContainer,
                  () => widget.onSectionChanged(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'View Orders',
                  Icons.receipt_long_rounded,
                  AppTheme.warning,
                  AppTheme.warningContainer,
                  () => widget.onSectionChanged(3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildAnimatedItem(
          index: 4,
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Transactions',
                  Icons.account_balance_wallet_rounded,
                  AppTheme.success,
                  AppTheme.successContainer,
                  () => widget.onSectionChanged(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Property Settings',
                  Icons.business_rounded,
                  AppTheme.receptionColor,
                  AppTheme.receptionContainer,
                  () => widget.onSectionChanged(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildAnimatedItem(
          index: 5,
          child: _buildQuickActionCard(
            'Manage Stays',
            Icons.hotel_rounded,
            const Color(0xFF7C3AED),
            const Color(0xFFEDE9FE),
            () => widget.onSectionChanged(5),
          ),
        ),

        const SizedBox(height: 24),

        _buildAnimatedItem(
          index: 5,
          child: _buildSectionHeader('Recent Orders'),
        ),
        const SizedBox(height: 12),

        ..._orderMaps.take(3).map((order) => _buildOrderCard(order)),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPLOYEES SECTION — Full CRUD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmployeesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Add Employee Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showEmployeeDialog(null),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: Text(
              'Add New Employee',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.superAdminColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 14),

        TextField(
          controller: _employeeSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search by name, mobile, service...',
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppTheme.onSurfaceMuted,
            ),
            suffixIcon: _employeeSearchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _employeeSearchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.superAdminColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                'All',
                'all',
                _employeeFilter,
                (v) => setState(() => _employeeFilter = v),
                AppTheme.superAdminColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Reception',
                'RECEPTION_DESK',
                _employeeFilter,
                (v) => setState(() => _employeeFilter = v),
                AppTheme.receptionColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Manager',
                'SERVICE_MANAGER',
                _employeeFilter,
                (v) => setState(() => _employeeFilter = v),
                AppTheme.managerColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Employee',
                'SERVICE_EMPLOYEE',
                _employeeFilter,
                (v) => setState(() => _employeeFilter = v),
                AppTheme.employeeColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          '${_filteredEmployees.length} employees found',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 12),

        if (_filteredEmployees.isEmpty)
          EmptyStateWidget(
            icon: Icons.people_rounded,
            title: 'No employees found',
            description: 'Tap "Add New Employee" to get started.',
          )
        else
          ..._filteredEmployees.map((emp) => _buildEmployeeCard(emp)),

        const SizedBox(height: 24),
      ],
    );
  }

  void _showEmployeeDialog(Map<String, dynamic>? emp) {
    final isEdit = emp != null;
    final fNameCtrl = TextEditingController(
      text: isEdit ? (emp['full_name'] as String).split(' ').first : '',
    );
    final lNameCtrl = TextEditingController(
      text: isEdit
          ? (emp['full_name'] as String).split(' ').skip(1).join(' ')
          : '',
    );
    final phoneCtrl = TextEditingController(
      text: isEdit ? emp['phone_no'] as String? ?? '' : '',
    );
    String selectedRole = isEdit ? emp['role'] as String : 'SERVICE_EMPLOYEE';
    String? selectedServiceDept = isEdit
        ? emp['service_dept'] as String?
        : null;
    bool isActive = isEdit ? (emp['is_active'] as bool? ?? true) : true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.superAdminContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: AppTheme.superAdminColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Edit Employee' : 'Add Employee',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField(
                  'First Name',
                  fNameCtrl,
                  Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                _dialogField(
                  'Last Name',
                  lNameCtrl,
                  Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                _dialogField(
                  'Phone Number',
                  phoneCtrl,
                  Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Text(
                  'Role',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.outline),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      borderRadius: BorderRadius.circular(10),
                      items: const [
                        DropdownMenuItem(
                          value: 'RECEPTION_DESK',
                          child: Text('Reception Desk'),
                        ),
                        DropdownMenuItem(
                          value: 'SERVICE_MANAGER',
                          child: Text('Service Manager'),
                        ),
                        DropdownMenuItem(
                          value: 'SERVICE_EMPLOYEE',
                          child: Text('Service Employee'),
                        ),
                        DropdownMenuItem(
                          value: 'SUPERADMIN',
                          child: Text('Super Admin'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedRole = v);
                      },
                    ),
                  ),
                ),
                if (selectedRole == 'SERVICE_MANAGER' ||
                    selectedRole == 'SERVICE_EMPLOYEE') ...[
                  const SizedBox(height: 12),
                  Text(
                    'Service Department',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.outline),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedServiceDept,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        borderRadius: BorderRadius.circular(10),
                        hint: const Text('Select department'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None'),
                          ),
                          ..._servicesList.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s['serv_id'] as String,
                              child: Text(s['name'] as String? ?? ''),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => selectedServiceDept = v),
                      ),
                    ),
                  ),
                ],
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Active',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        activeThumbColor: AppTheme.success,
                        onChanged: (v) => setDialogState(() => isActive = v),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveEmployee(
                  emp: emp,
                  firstName: fNameCtrl.text,
                  lastName: lNameCtrl.text,
                  phoneNo: phoneCtrl.text,
                  role: selectedRole,
                  serviceDept: selectedServiceDept,
                  isActive: isActive,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.superAdminColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                isEdit ? 'Save Changes' : 'Add Employee',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppTheme.onSurfaceMuted),
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
                color: AppTheme.superAdminColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveEmployee({
    required Map<String, dynamic>? emp,
    required String firstName,
    required String lastName,
    required String phoneNo,
    required String role,
    String? serviceDept,
    required bool isActive,
  }) async {
    if (firstName.trim().isEmpty || phoneNo.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'First name and phone number are required',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
      return;
    }
    try {
      if (emp == null) {
        await SupabaseService.instance.createEmployee(
          propertyId: widget.propertyId,
          firstName: firstName,
          lastName: lastName,
          phoneNo: phoneNo,
          role: role,
          serviceDept: serviceDept,
        );
        Fluttertoast.showToast(
          msg: 'Employee added successfully',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
        );
      } else {
        await SupabaseService.instance.updateEmployee(
          empId: emp['emp_id'] as String,
          firstName: firstName,
          lastName: lastName,
          phoneNo: phoneNo,
          role: role,
          serviceDept: serviceDept,
          isActive: isActive,
        );
        Fluttertoast.showToast(
          msg: 'Employee updated successfully',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
        );
      }
      setState(() => _isLoading = true);
      _loadData();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed: $e',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }

  void _confirmDeleteEmployee(Map<String, dynamic> emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Employee',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove ${emp['full_name']}? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.instance.deleteEmployee(
                  emp['emp_id'] as String,
                );
                Fluttertoast.showToast(
                  msg: '${emp['full_name']} removed',
                  backgroundColor: AppTheme.success,
                  textColor: Colors.white,
                );
                setState(() => _isLoading = true);
                _loadData();
              } catch (e) {
                Fluttertoast.showToast(
                  msg: 'Failed: $e',
                  backgroundColor: AppTheme.error,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROPERTY SECTION
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPropertySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_propertyData['name'] as String?) ??
                              widget.propertyName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          (_propertyData['city'] as String?) ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppTheme.outlineVariant),
              const SizedBox(height: 20),
              _buildPropertyField(
                'Property Name',
                _nameController,
                Icons.hotel_rounded,
              ),
              const SizedBox(height: 14),
              _buildPropertyField(
                'Address',
                _addressController,
                Icons.location_on_rounded,
              ),
              const SizedBox(height: 14),
              _buildPropertyField(
                'Phone',
                _phoneController,
                Icons.phone_rounded,
              ),
              const SizedBox(height: 14),
              _buildPropertyField(
                'Email',
                _emailController,
                Icons.email_rounded,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildPropertyInfoTile(
                      'City',
                      (_propertyData['city'] as String?) ?? '-',
                      Icons.location_city_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPropertyInfoTile(
                      'State',
                      (_propertyData['state'] as String?) ?? '-',
                      Icons.map_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savePropertyDetails,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    'Save Changes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.superAdminColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _savePropertyDetails() async {
    try {
      await SupabaseService.instance.updatePropertyDetails(widget.propertyId, {
        'name': _nameController.text.trim(),
        'address_ln1': _addressController.text.trim(),
        'contact_number': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      });
      Fluttertoast.showToast(
        msg: 'Property details updated successfully',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to update: $e',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDERS SECTION — with discount
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                'All',
                'all',
                _orderStatusFilter,
                (v) => setState(() => _orderStatusFilter = v),
                AppTheme.primary,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Ordered',
                'ordered',
                _orderStatusFilter,
                (v) => setState(() => _orderStatusFilter = v),
                AppTheme.warning,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'In Progress',
                'in_progress',
                _orderStatusFilter,
                (v) => setState(() => _orderStatusFilter = v),
                AppTheme.primary,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Delivered',
                'delivered',
                _orderStatusFilter,
                (v) => setState(() => _orderStatusFilter = v),
                AppTheme.success,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Cancelled',
                'cancelled',
                _orderStatusFilter,
                (v) => setState(() => _orderStatusFilter = v),
                AppTheme.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_filteredOrders.isEmpty)
          EmptyStateWidget(
            icon: Icons.receipt_long_rounded,
            title: 'No orders found',
            description: 'No orders match the selected filter.',
          )
        else
          ..._filteredOrders.map(
            (order) => _buildOrderCard(order, showEditAction: true),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  void _showDiscountDialog(Map<String, dynamic> order) {
    final currentTotal = (order['so_total'] as num?)?.toDouble() ?? 0.0;
    final discountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.warningContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.discount_rounded,
                size: 18,
                color: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Apply Discount',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Total',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  Text(
                    '₹${currentTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Discount Amount (₹)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: discountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.currency_rupee_rounded,
                  size: 18,
                  color: AppTheme.onSurfaceMuted,
                ),
                hintText: 'Enter discount amount',
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
                    color: AppTheme.superAdminColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The discount will be deducted from the order total.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
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
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final discountVal = double.tryParse(discountCtrl.text.trim());
              if (discountVal == null || discountVal <= 0) {
                Fluttertoast.showToast(
                  msg: 'Enter a valid discount amount',
                  backgroundColor: AppTheme.error,
                  textColor: Colors.white,
                );
                return;
              }
              if (discountVal > currentTotal) {
                Fluttertoast.showToast(
                  msg: 'Discount cannot exceed order total',
                  backgroundColor: AppTheme.error,
                  textColor: Colors.white,
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await SupabaseService.instance.applyOrderDiscount(
                  orderId: order['so_id'] as String,
                  discountAmount: discountVal,
                  currentTotal: currentTotal,
                );
                Fluttertoast.showToast(
                  msg: 'Discount of ₹${discountVal.toStringAsFixed(2)} applied',
                  backgroundColor: AppTheme.success,
                  textColor: Colors.white,
                );
                setState(() => _isLoading = true);
                _loadData();
              } catch (e) {
                Fluttertoast.showToast(
                  msg: 'Failed: $e',
                  backgroundColor: AppTheme.error,
                  textColor: Colors.white,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.superAdminColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Apply',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRANSACTIONS SECTION
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTransactionsSection() {
    final totalPaid = _transactionMaps
        .where((t) => t['status'] == 'paid')
        .fold<double>(
          0.0,
          (s, t) => s + ((t['total_amount'] as num?)?.toDouble() ?? 0.0),
        );
    final totalPending = _transactionMaps
        .where((t) => t['status'] == 'pending')
        .fold<double>(
          0.0,
          (s, t) => s + ((t['total_amount'] as num?)?.toDouble() ?? 0.0),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Summary cards
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Total Collected',
                '₹${totalPaid.toStringAsFixed(0)}',
                Icons.check_circle_rounded,
                AppTheme.success,
                AppTheme.successContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Pending',
                '₹${totalPending.toStringAsFixed(0)}',
                Icons.pending_rounded,
                AppTheme.warning,
                AppTheme.warningContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Status filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                'All',
                'all',
                _txStatusFilter,
                (v) => setState(() => _txStatusFilter = v),
                AppTheme.primary,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Paid',
                'paid',
                _txStatusFilter,
                (v) => setState(() => _txStatusFilter = v),
                AppTheme.success,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Pending',
                'pending',
                _txStatusFilter,
                (v) => setState(() => _txStatusFilter = v),
                AppTheme.warning,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Failed',
                'failed',
                _txStatusFilter,
                (v) => setState(() => _txStatusFilter = v),
                AppTheme.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          '${_filteredTransactions.length} transactions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 12),

        if (_filteredTransactions.isEmpty)
          EmptyStateWidget(
            icon: Icons.account_balance_wallet_rounded,
            title: 'No transactions found',
            description:
                'Transactions will appear here once payments are made.',
          )
        else
          ..._filteredTransactions.map((tx) => _buildTransactionCard(tx)),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final status = tx['status'] as String? ?? 'pending';
    final amount = (tx['total_amount'] as num?)?.toDouble() ?? 0.0;
    final currency = tx['currency'] as String? ?? 'INR';
    final txId = tx['transaction_id'] as String? ?? '';
    final paymentMethod = tx['payment_method'] as String? ?? '-';
    final createdAt = tx['created_at'] as String? ?? '';
    final paidAt = tx['paid_at'] as String?;
    final userMap = tx['users'] as Map<String, dynamic>?;
    final userName = userMap?['name'] as String? ?? 'Guest';
    final userPhone = userMap?['mobile_no'] as String? ?? '';

    final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';
    final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';

    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    switch (status) {
      case 'paid':
        statusColor = AppTheme.success;
        statusBg = AppTheme.successContainer;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'failed':
        statusColor = AppTheme.error;
        statusBg = AppTheme.errorContainer;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'processing':
        statusColor = AppTheme.primary;
        statusBg = AppTheme.primaryContainer;
        statusIcon = Icons.sync_rounded;
        break;
      default:
        statusColor = AppTheme.warning;
        statusBg = AppTheme.warningContainer;
        statusIcon = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'paid'
              ? AppTheme.success.withAlpha(60)
              : AppTheme.outline,
          width: status == 'paid' ? 1.5 : 1,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  txId.length > 12 ? txId.substring(0, 12) : txId,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userPhone.isNotEmpty)
                      Text(
                        userPhone,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency ${amount.toStringAsFixed(2)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: status == 'paid'
                          ? AppTheme.success
                          : AppTheme.onSurface,
                    ),
                  ),
                  if (paymentMethod != '-' && paymentMethod.isNotEmpty)
                    Text(
                      paymentMethod,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: AppTheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '$dateStr  $timeStr',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              if (paidAt != null && paidAt.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Paid ${paidAt.length >= 10 ? paidAt.substring(0, 10) : paidAt}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGreetingCard() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3730A3), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.superAdminColor.withAlpha(60),
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
                  '$greeting,',
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
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Super Admin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppTheme.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
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

  Widget _buildQuickActionCard(
    String label,
    IconData icon,
    Color color,
    Color bgColor,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withAlpha(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppTheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order, {
    bool showEditAction = false,
  }) {
    final status = order['status'] as String? ?? 'ordered';
    final roomData = order['rooms'] as Map<String, dynamic>?;
    final roomNumber = roomData?['room_number'] as String? ?? '-';
    final serviceData = order['services'] as Map<String, dynamic>?;
    final serviceName = serviceData?['name'] as String? ?? 'Service';
    final amount = (order['so_total'] as num?)?.toDouble() ?? 0.0;
    final createdAt = order['created_at'] as String? ?? '';
    final timeStr = createdAt.length >= 16 ? createdAt.substring(11, 16) : '';
    final orderId = (order['so_id'] as String? ?? '').length >= 8
        ? (order['so_id'] as String).substring(0, 8).toUpperCase()
        : (order['so_id'] as String? ?? '').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'ordered'
              ? AppTheme.warning.withAlpha(80)
              : AppTheme.outline,
          width: status == 'ordered' ? 1.5 : 1,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$orderId',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bed_rounded,
                      size: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Room $roomNumber',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              StatusBadgeWidget(status: _orderBadgeStatus(status)),
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
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                order['order_type'] as String? ?? '',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
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
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (showEditAction) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.outlineVariant),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Discount button always visible for superadmin
                _buildMiniAction(
                  'Add Discount',
                  Icons.discount_rounded,
                  AppTheme.superAdminColor,
                  () => _showDiscountDialog(order),
                ),
                const SizedBox(width: 8),
                if (status == 'ordered')
                  _buildMiniAction(
                    'Cancel',
                    Icons.cancel_rounded,
                    AppTheme.error,
                    () => _updateOrderStatus(
                      order['so_id'] as String,
                      'cancelled',
                    ),
                  ),
                if (status == 'in_progress') ...[
                  const SizedBox(width: 8),
                  _buildMiniAction(
                    'Mark Delivered',
                    Icons.check_circle_rounded,
                    AppTheme.success,
                    () => _updateOrderStatus(
                      order['so_id'] as String,
                      'delivered',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      await SupabaseService.instance.updateOrderStatus(orderId, status);
      Fluttertoast.showToast(
        msg: 'Order status updated to $status',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
      );
      setState(() => _isLoading = true);
      _loadData();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed: $e',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final role = emp['role'] as String? ?? 'SERVICE_EMPLOYEE';
    Color roleColor;
    Color roleBg;
    String roleLabel;
    switch (role) {
      case 'RECEPTION_DESK':
        roleColor = AppTheme.receptionColor;
        roleBg = AppTheme.receptionContainer;
        roleLabel = 'Reception';
        break;
      case 'SERVICE_MANAGER':
        roleColor = AppTheme.managerColor;
        roleBg = AppTheme.managerContainer;
        roleLabel = 'Manager';
        break;
      case 'SUPERADMIN':
        roleColor = AppTheme.superAdminColor;
        roleBg = AppTheme.superAdminContainer;
        roleLabel = 'Super Admin';
        break;
      default:
        roleColor = AppTheme.employeeColor;
        roleBg = AppTheme.employeeContainer;
        roleLabel = 'Employee';
    }

    final isActive = emp['is_active'] == true;
    final fullName = emp['full_name'] as String? ?? 'Unknown';
    final phoneNo = emp['phone_no'] as String? ?? '';
    final serviceName = emp['service_name'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: roleBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    fullName
                        .split(' ')
                        .map((p) => p.isNotEmpty ? p[0] : '')
                        .take(2)
                        .join(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.success
                                : AppTheme.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleBg,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            roleLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                            ),
                          ),
                        ),
                        if (serviceName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              serviceName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.onSurfaceMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phoneNo,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildMiniAction(
                'Edit',
                Icons.edit_rounded,
                AppTheme.primary,
                () => _showEmployeeDialog(emp),
              ),
              const SizedBox(width: 8),
              _buildMiniAction(
                'Delete',
                Icons.delete_rounded,
                AppTheme.error,
                () => _confirmDeleteEmployee(emp),
              ),
              const Spacer(),
              Text(
                isActive ? 'Active' : 'Inactive',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? AppTheme.success
                      : AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                value: isActive,
                activeThumbColor: AppTheme.success,
                onChanged: (val) => _toggleEmployeeStatus(emp, val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEmployeeStatus(
    Map<String, dynamic> emp,
    bool newStatus,
  ) async {
    try {
      await SupabaseService.instance.updateEmployeeStatus(
        emp['emp_id'] as String,
        newStatus,
      );
      Fluttertoast.showToast(
        msg: '${emp['full_name']} ${newStatus ? 'activated' : 'deactivated'}',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
      );
      setState(() {
        final idx = _employeeMaps.indexWhere(
          (e) => e['emp_id'] == emp['emp_id'],
        );
        if (idx != -1) {
          _employeeMaps[idx] = {..._employeeMaps[idx], 'is_active': newStatus};
        }
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed: $e',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }

  Widget _buildPropertyField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppTheme.onSurfaceMuted),
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
                color: AppTheme.superAdminColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String current,
    Function(String) onChanged,
    Color color,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : AppTheme.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? color : AppTheme.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? color : AppTheme.onSurfaceMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurface,
      ),
    );
  }

  Widget _buildMiniAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAYS SECTION — SuperAdmin Full CRUD
  // ─────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredStays {
    return _allStays.where((s) {
      final status = (s['status'] as String?) ?? '';
      if (_stayTabFilter == 'Upcoming') return status == 'Upcoming';
      if (_stayTabFilter == 'Active') return status == 'Active';
      if (_stayTabFilter == 'Ended') return status == 'Ended';
      return true;
    }).toList();
  }

  Widget _buildStaysSection() {
    final upcomingCount = _allStays
        .where((s) => s['status'] == 'Upcoming')
        .length;
    final activeCount = _allStays.where((s) => s['status'] == 'Active').length;
    final endedCount = _allStays.where((s) => s['status'] == 'Ended').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // KPI Row
        Row(
          children: [
            Expanded(
              child: _buildStayKpiCard(
                'Upcoming',
                '$upcomingCount',
                Icons.schedule_rounded,
                const Color(0xFF7C3AED),
                const Color(0xFFEDE9FE),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStayKpiCard(
                'Active',
                '$activeCount',
                Icons.hotel_rounded,
                AppTheme.success,
                AppTheme.successContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStayKpiCard(
                'Ended',
                '$endedCount',
                Icons.check_circle_rounded,
                AppTheme.onSurfaceMuted,
                AppTheme.surfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Add Stay Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showStayDialog(null),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Add New Stay',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Tab Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                'Upcoming',
                'Upcoming',
                _stayTabFilter,
                (v) => setState(() => _stayTabFilter = v),
                const Color(0xFF7C3AED),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Active',
                'Active',
                _stayTabFilter,
                (v) => setState(() => _stayTabFilter = v),
                AppTheme.success,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Ended',
                'Ended',
                _stayTabFilter,
                (v) => setState(() => _stayTabFilter = v),
                AppTheme.onSurfaceMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_filteredStays.length} stays',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 10),
        if (_filteredStays.isEmpty)
          EmptyStateWidget(
            icon: Icons.hotel_rounded,
            title: 'No ${_stayTabFilter.toLowerCase()} stays',
            description: 'Tap "Add New Stay" to create one.',
          )
        else
          ..._filteredStays.map((stay) => _buildStayCard(stay)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStayKpiCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStayCard(Map<String, dynamic> stay) {
    final stayId = stay['stay_id'] as String? ?? '';
    final status = stay['status'] as String? ?? '';
    final checkIn = stay['check_in_date'] as String? ?? '';
    final checkOut = stay['check_out_date'] as String? ?? '';
    final mainUser = stay['users'] as Map<String, dynamic>?;
    final guestName = mainUser?['name'] as String? ?? 'Unknown Guest';
    final guestMobile = mainUser?['mobile_no'] as String? ?? '';

    // Rooms
    final stayRooms = stay['stay_rooms'] as List? ?? [];
    final roomNumbers = stayRooms
        .map((sr) {
          final room =
              (sr as Map<String, dynamic>)['rooms'] as Map<String, dynamic>?;
          return room?['room_number'] as String? ?? '-';
        })
        .join(', ');
    final roomTypes = stayRooms
        .map((sr) {
          final room =
              (sr as Map<String, dynamic>)['rooms'] as Map<String, dynamic>?;
          return room?['type'] as String? ?? '';
        })
        .where((t) => t.isNotEmpty)
        .join(', ');

    // Guests
    final stayGuests = stay['stay_guests'] as List? ?? [];
    final guestCount = stayGuests.length;

    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    switch (status) {
      case 'Active':
        statusColor = AppTheme.success;
        statusBg = AppTheme.successContainer;
        statusIcon = Icons.hotel_rounded;
        break;
      case 'Upcoming':
        statusColor = const Color(0xFF7C3AED);
        statusBg = const Color(0xFFEDE9FE);
        statusIcon = Icons.schedule_rounded;
        break;
      default:
        statusColor = AppTheme.onSurfaceMuted;
        statusBg = AppTheme.surfaceVariant;
        statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: statusBg.withAlpha(80),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guestName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (guestMobile.isNotEmpty)
                        Text(
                          guestMobile,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
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
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: statusColor.withAlpha(60)),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStayDetailItem(
                        Icons.login_rounded,
                        'Check-In',
                        checkIn,
                        AppTheme.receptionColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStayDetailItem(
                        Icons.logout_rounded,
                        'Check-Out',
                        checkOut,
                        AppTheme.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildStayDetailItem(
                        Icons.meeting_room_rounded,
                        'Room(s)',
                        roomNumbers.isNotEmpty ? roomNumbers : '-',
                        AppTheme.managerColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStayDetailItem(
                        Icons.people_rounded,
                        'Guests',
                        '$guestCount guest${guestCount != 1 ? 's' : ''}',
                        AppTheme.superAdminColor,
                      ),
                    ),
                  ],
                ),
                if (roomTypes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.category_rounded,
                        size: 13,
                        color: AppTheme.onSurfaceMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        roomTypes,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ],
                // Guest list
                if (stayGuests.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppTheme.outline),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.group_rounded,
                        size: 14,
                        color: AppTheme.onSurfaceMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'All Guests',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...stayGuests.take(4).map((g) {
                    final gMap = g as Map<String, dynamic>;
                    final u = gMap['users'] as Map<String, dynamic>?;
                    final name = u?['name'] as String? ?? 'Guest';
                    final mobile = u?['mobile_no'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'G',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (mobile.isNotEmpty)
                            Text(
                              mobile,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppTheme.onSurfaceMuted,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (stayGuests.length > 4)
                    Text(
                      '+${stayGuests.length - 4} more guests',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniAction(
                        'Edit',
                        Icons.edit_rounded,
                        AppTheme.primary,
                        () => _showStayDialog(stay),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (status == 'Active')
                      Expanded(
                        child: _buildMiniAction(
                          'Checkout',
                          Icons.logout_rounded,
                          AppTheme.warning,
                          () => _confirmStayCheckout(stay),
                        ),
                      ),
                    if (status != 'Active') const Spacer(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniAction(
                        'Delete',
                        Icons.delete_rounded,
                        AppTheme.error,
                        () => _confirmDeleteStay(stayId),
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

  Widget _buildStayDetailItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStayDialog(Map<String, dynamic>? stay) {
    final isEdit = stay != null;
    final mainUser = isEdit ? stay['users'] as Map<String, dynamic>? : null;
    final stayRooms = isEdit ? (stay['stay_rooms'] as List? ?? []) : [];

    final guestNameCtrl = TextEditingController(
      text: mainUser?['name'] as String? ?? '',
    );
    final guestMobileCtrl = TextEditingController(
      text: mainUser?['mobile_no'] as String? ?? '',
    );
    final roomIdCtrl = TextEditingController(
      text: stayRooms.isNotEmpty
          ? ((stayRooms[0] as Map<String, dynamic>)['room_id'] as String? ?? '')
          : '',
    );

    DateTime checkIn = isEdit
        ? DateTime.tryParse(stay['check_in_date'] as String? ?? '') ??
              DateTime.now()
        : DateTime.now();
    DateTime checkOut = isEdit
        ? DateTime.tryParse(stay['check_out_date'] as String? ?? '') ??
              DateTime.now().add(const Duration(days: 1))
        : DateTime.now().add(const Duration(days: 1));
    String selectedStatus = isEdit
        ? (stay['status'] as String? ?? 'Upcoming')
        : 'Upcoming';

    // Fetch available rooms for dropdown
    List<Map<String, dynamic>> availableRooms = [];
    String? selectedRoomId = roomIdCtrl.text.isNotEmpty
        ? roomIdCtrl.text
        : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Load rooms on first build
          if (availableRooms.isEmpty) {
            SupabaseService.instance.fetchRooms(widget.propertyId).then((
              rooms,
            ) {
              if (ctx.mounted) {
                setDialogState(() => availableRooms = rooms);
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              isEdit ? 'Edit Stay' : 'Add New Stay',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isEdit) ...[
                    _buildDialogLabel('Guest Name'),
                    _buildDialogTextField(guestNameCtrl, 'e.g. John Doe'),
                    const SizedBox(height: 12),
                    _buildDialogLabel('Guest Mobile'),
                    _buildDialogTextField(
                      guestMobileCtrl,
                      'e.g. +91XXXXXXXXXX',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogLabel('Room'),
                    availableRooms.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: selectedRoomId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppTheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppTheme.outline,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppTheme.outline,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            hint: const Text('Select Room'),
                            items: availableRooms.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['room_id'] as String,
                                child: Text(
                                  'Room ${r['room_number']} (${r['type'] ?? 'Standard'})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedRoomId = v),
                          ),
                    const SizedBox(height: 12),
                  ],
                  _buildDialogLabel('Status'),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.outline),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: ['Upcoming', 'Active', 'Ended'].map((s) {
                      return DropdownMenuItem<String>(
                        value: s,
                        child: Text(
                          s,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(
                      () => selectedStatus = v ?? selectedStatus,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogLabel('Check-In Date'),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: checkIn,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => checkIn = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.outline),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${checkIn.year}-${checkIn.month.toString().padLeft(2, '0')}-${checkIn.day.toString().padLeft(2, '0')}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDialogLabel('Check-Out Date'),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: checkOut,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => checkOut = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.outline),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: AppTheme.warning,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${checkOut.year}-${checkOut.month.toString().padLeft(2, '0')}-${checkOut.day.toString().padLeft(2, '0')}',
                            style: GoogleFonts.plusJakartaSans(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _saveStay(
                    isEdit: isEdit,
                    stay: stay,
                    guestName: guestNameCtrl.text.trim(),
                    guestMobile: guestMobileCtrl.text.trim(),
                    roomId: selectedRoomId ?? '',
                    checkIn: checkIn,
                    checkOut: checkOut,
                    status: selectedStatus,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isEdit ? 'Save Changes' : 'Create Stay',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveStay({
    required bool isEdit,
    Map<String, dynamic>? stay,
    required String guestName,
    required String guestMobile,
    required String roomId,
    required DateTime checkIn,
    required DateTime checkOut,
    required String status,
  }) async {
    try {
      if (isEdit && stay != null) {
        await SupabaseService.instance.updateStay(
          stayId: stay['stay_id'] as String,
          checkInDate: checkIn,
          checkOutDate: checkOut,
          status: status,
        );
        Fluttertoast.showToast(msg: 'Stay updated successfully');
      } else {
        if (guestMobile.isEmpty || roomId.isEmpty) {
          Fluttertoast.showToast(msg: 'Please fill all required fields');
          return;
        }
        await SupabaseService.instance.createStayForSuperAdmin(
          propertyId: widget.propertyId,
          guestMobile: guestMobile,
          guestName: guestName,
          roomId: roomId,
          checkInDate: checkIn,
          checkOutDate: checkOut,
          status: status,
        );
        Fluttertoast.showToast(msg: 'Stay created successfully');
      }
      await _reloadStays();
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _reloadStays() async {
    try {
      final stays = await SupabaseService.instance.fetchAllStaysForSuperAdmin(
        widget.propertyId,
      );
      if (mounted) setState(() => _allStays = stays);
    } catch (_) {}
  }

  void _confirmStayCheckout(Map<String, dynamic> stay) {
    final stayId = stay['stay_id'] as String? ?? '';
    final stayRooms = stay['stay_rooms'] as List? ?? [];
    final roomIds = stayRooms
        .map((sr) => (sr as Map<String, dynamic>)['room_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Checkout',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will mark the stay as Ended and release all rooms. Continue?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // BUG-1 fix: Route through StayService so the 2-way Apaleo checkout
                // is triggered. Bypassing this caused guests to resurrect on next sync.
                final roomId = roomIds.isNotEmpty ? roomIds.first : null;
                final result = await StayService().checkoutStay(stayId: stayId, roomId: roomId);
                if (!result.pmsSynced && result.pmsWarning != null) {
                  Fluttertoast.showToast(
                    msg: '⚠️ Checked out locally. ${result.pmsWarning}',
                    toastLength: Toast.LENGTH_LONG,
                  );
                } else {
                  Fluttertoast.showToast(msg: 'Guest checked out successfully');
                }
                await _reloadStays();
              } catch (e) {
                Fluttertoast.showToast(
                  msg: e.toString().replaceFirst('Exception: ', ''),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Checkout',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStay(String stayId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Stay',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete this stay? This action cannot be undone.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.instance.deleteStay(stayId);
                Fluttertoast.showToast(msg: 'Stay deleted');
                await _reloadStays();
              } catch (e) {
                Fluttertoast.showToast(
                  msg: e.toString().replaceFirst('Exception: ', ''),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurfaceMuted,
        ),
      ),
    );
  }

  Widget _buildDialogTextField(
    TextEditingController ctrl,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.plusJakartaSans(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildAnimatedItem({required int index, required Widget child}) {
    return FadeTransition(
      opacity: _itemAnimations[index],
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
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
