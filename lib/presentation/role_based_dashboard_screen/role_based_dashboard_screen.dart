import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer_widget.dart';
import './widgets/employee_dashboard_widget.dart';
import './widgets/manager_dashboard_widget.dart';
import './widgets/superadmin_dashboard_widget.dart';
import './widgets/spa_manager_dashboard_widget.dart';
import './widgets/laundry_manager_dashboard_widget.dart';
import './widgets/spa_employee_dashboard_widget.dart';
import './widgets/laundry_employee_dashboard_widget.dart';
import '../../services/supabase_service.dart';
import '../manage_inventory/manage_inventory_screen.dart';
import '../../features/reception/shell/reception_shell.dart';
import '../../widgets/role_switcher_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleBasedDashboardScreen extends StatefulWidget {
  final String role;
  final String employeeName;
  final String propertyName;
  final String propertyId;
  final String? serviceId;
  final String? empId;

  const RoleBasedDashboardScreen({
    super.key,
    required this.role,
    required this.employeeName,
    required this.propertyName,
    required this.propertyId,
    this.serviceId,
    this.empId,
  });

  @override
  State<RoleBasedDashboardScreen> createState() =>
      _RoleBasedDashboardScreenState();
}

class _RoleBasedDashboardScreenState extends State<RoleBasedDashboardScreen> {
  // TODO: Replace with Riverpod/Bloc for production
  int _selectedDrawerIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  List<DrawerItem> _getDrawerItems() {
    switch (widget.role) {
      case 'SUPERADMIN':
        return [
          DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            onTap: () => setState(() => _selectedDrawerIndex = 0),
          ),
          DrawerItem(
            icon: Icons.people_rounded,
            label: 'Employees',
            onTap: () => setState(() => _selectedDrawerIndex = 1),
          ),
          DrawerItem(
            icon: Icons.business_rounded,
            label: 'Property Details',
            onTap: () => setState(() => _selectedDrawerIndex = 2),
          ),
          DrawerItem(
            icon: Icons.receipt_long_rounded,
            label: 'Manage Orders',
            onTap: () => setState(() => _selectedDrawerIndex = 3),
          ),
          DrawerItem(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Transactions',
            onTap: () => setState(() => _selectedDrawerIndex = 4),
          ),
          DrawerItem(
            icon: Icons.hotel_rounded,
            label: 'Manage Stays',
            onTap: () => setState(() => _selectedDrawerIndex = 5),
          ),
        ];
      case 'SERVICE_MANAGER':
        return [
          DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            onTap: () => setState(() => _selectedDrawerIndex = 0),
          ),
          DrawerItem(
            icon: Icons.receipt_long_rounded,
            label: 'Manage Orders',
            onTap: () => setState(() => _selectedDrawerIndex = 1),
          ),
          DrawerItem(
            icon: Icons.assignment_rounded,
            label: 'Allot Orders',
            onTap: () => setState(() => _selectedDrawerIndex = 2),
          ),
          DrawerItem(
            icon: Icons.track_changes_rounded,
            label: 'Track Orders',
            onTap: () => setState(() => _selectedDrawerIndex = 3),
          ),
          DrawerItem(
            icon: Icons.inventory_2_rounded,
            label: 'Manage Inventory',
            onTap: () => setState(() => _selectedDrawerIndex = 4),
          ),
        ];
      case 'SERVICE_EMPLOYEE':
        return [
          DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            onTap: () => setState(() => _selectedDrawerIndex = 0),
          ),
          DrawerItem(
            icon: Icons.task_alt_rounded,
            label: 'My Orders',
            onTap: () => setState(() => _selectedDrawerIndex = 1),
          ),
        ];
      case 'SPA_MANAGER':
        return [
          DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            onTap: () => setState(() => _selectedDrawerIndex = 0),
          ),
          DrawerItem(
            icon: Icons.spa_rounded,
            label: 'Spa Requests',
            onTap: () => setState(() => _selectedDrawerIndex = 1),
          ),
          DrawerItem(
            icon: Icons.assignment_ind_rounded,
            label: 'Assign Staff',
            onTap: () => setState(() => _selectedDrawerIndex = 2),
          ),
          DrawerItem(
            icon: Icons.receipt_long_rounded,
            label: 'Billing',
            onTap: () => setState(() => _selectedDrawerIndex = 3),
          ),
          DrawerItem(
            icon: Icons.inventory_2_rounded,
            label: 'Manage Inventory',
            onTap: () => setState(() => _selectedDrawerIndex = 4),
          ),
        ];
      case 'SPA_EMPLOYEE':
        return [
          DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            onTap: () => setState(() => _selectedDrawerIndex = 0),
          ),
          DrawerItem(
            icon: Icons.spa_rounded,
            label: 'My Assignments',
            onTap: () => setState(() => _selectedDrawerIndex = 1),
          ),
        ];
      case 'LAUNDRY_MANAGER':
        return [
          DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            onTap: () => setState(() => _selectedDrawerIndex = 0),
          ),
          DrawerItem(
            icon: Icons.local_laundry_service_rounded,
            label: 'Laundry Requests',
            onTap: () => setState(() => _selectedDrawerIndex = 1),
          ),
          DrawerItem(
            icon: Icons.assignment_ind_rounded,
            label: 'Assign Staff',
            onTap: () => setState(() => _selectedDrawerIndex = 2),
          ),
          DrawerItem(
            icon: Icons.receipt_long_rounded,
            label: 'Billing',
            onTap: () => setState(() => _selectedDrawerIndex = 3),
          ),
          DrawerItem(
            icon: Icons.inventory_2_rounded,
            label: 'Manage Inventory',
            onTap: () => setState(() => _selectedDrawerIndex = 4),
          ),
        ];
      case 'LAUNDRY_EMPLOYEE':
        return [
          DrawerItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            onTap: () => setState(() => _selectedDrawerIndex = 0),
          ),
          DrawerItem(
            icon: Icons.local_laundry_service_rounded,
            label: 'My Assignments',
            onTap: () => setState(() => _selectedDrawerIndex = 1),
          ),
        ];
      default:
        return [DrawerItem(icon: Icons.dashboard_rounded, label: 'Dashboard')];
    }
  }

  void _handleLogout() {
    SupabaseService.instance.clearSession();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.loginVerificationScreen,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dark navy app bar → white status bar icons
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    final isTablet = MediaQuery.of(context).size.width >= 600;

    final hasMultipleRoles = (SupabaseService.instance.currentSession?.authorizedRoles.length ?? 0) > 1;
    final isReception = const ['RECEPTION', 'RECEPTION_DESK', 'RECEPTIONIST'].contains(widget.role);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: AppDrawerWidget(
        employeeName: widget.employeeName,
        role: widget.role,
        propertyName: widget.propertyName,
        selectedIndex: _selectedDrawerIndex,
        items: _getDrawerItems(),
        onLogout: _handleLogout,
      ),
      body: Stack(
        children: [
          _buildRoleDashboard(isTablet),
          if (!isReception && hasMultipleRoles)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => RoleSwitcherDialog.show(context),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border(
                          left: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 0.8),
                          right: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 0.8),
                          bottom: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 0.8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'WORKSTATION SHUTTER',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: Color(0xFF38BDF8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleDashboard(bool isTablet) {
    switch (widget.role) {
      case 'SUPERADMIN':
        return SuperAdminDashboardWidget(
          scaffoldKey: _scaffoldKey,
          employeeName: widget.employeeName,
          propertyName: widget.propertyName,
          propertyId: widget.propertyId,
          selectedSection: _selectedDrawerIndex,
          isTablet: isTablet,
          onSectionChanged: (i) => setState(() => _selectedDrawerIndex = i),
        );
      case 'RECEPTION':
      case 'RECEPTION_DESK':
      case 'RECEPTIONIST':
        return ReceptionShell(
          employeeName: widget.employeeName,
          propertyName: widget.propertyName,
          propertyId: widget.propertyId,
          onLogout: _handleLogout,
        );
      case 'SERVICE_MANAGER':
        if (_selectedDrawerIndex == 4) {
          return ManageInventoryScreen(
            propertyId: widget.propertyId,
            propertyName: widget.propertyName,
            serviceType: InventoryServiceType.kitchen,
            scaffoldKey: _scaffoldKey,
          );
        }
        return ManagerDashboardWidget(
          scaffoldKey: _scaffoldKey,
          employeeName: widget.employeeName,
          propertyName: widget.propertyName,
          propertyId: widget.propertyId,
          serviceId: widget.serviceId ?? '',
          selectedSection: _selectedDrawerIndex,
          isTablet: isTablet,
          onSectionChanged: (i) => setState(() => _selectedDrawerIndex = i),
        );
      case 'SERVICE_EMPLOYEE':
        return EmployeeDashboardWidget(
          scaffoldKey: _scaffoldKey,
          employeeName: widget.employeeName,
          propertyName: widget.propertyName,
          propertyId: widget.propertyId,
          serviceId: widget.serviceId ?? '',
          empId: widget.empId ?? '',
          selectedSection: _selectedDrawerIndex,
          isTablet: isTablet,
          onSectionChanged: (i) => setState(() => _selectedDrawerIndex = i),
        );
      case 'SPA_MANAGER':
        if (_selectedDrawerIndex == 4) {
          return ManageInventoryScreen(
            propertyId: widget.propertyId,
            propertyName: widget.propertyName,
            serviceType: InventoryServiceType.spa,
            scaffoldKey: _scaffoldKey,
          );
        }
        return SpaManagerDashboardWidget(
          scaffoldKey: _scaffoldKey,
          employeeName: widget.employeeName,
          propertyName: widget.propertyName,
          propertyId: widget.propertyId,
          empId: widget.empId ?? '',
          serviceId: widget.serviceId,
          selectedSection: _selectedDrawerIndex,
          isTablet: isTablet,
          onSectionChanged: (i) => setState(() => _selectedDrawerIndex = i),
        );
      case 'SPA_EMPLOYEE':
        return SpaEmployeeDashboardWidget(
          scaffoldKey: _scaffoldKey,
          employeeName: widget.employeeName,
          propertyName: widget.propertyName,
          propertyId: widget.propertyId,
          empId: widget.empId ?? '',
          selectedSection: _selectedDrawerIndex,
          isTablet: isTablet,
          onSectionChanged: (i) => setState(() => _selectedDrawerIndex = i),
        );
      case 'LAUNDRY_MANAGER':
        if (_selectedDrawerIndex == 4) {
          return ManageInventoryScreen(
            propertyId: widget.propertyId,
            propertyName: widget.propertyName,
            serviceType: InventoryServiceType.laundry,
            scaffoldKey: _scaffoldKey,
          );
        }
        return LaundryManagerDashboardWidget(
          scaffoldKey: _scaffoldKey,
          employeeName: widget.employeeName,
          propertyName: widget.propertyName,
          propertyId: widget.propertyId,
          empId: widget.empId ?? '',
          serviceId: widget.serviceId,
          selectedSection: _selectedDrawerIndex,
          isTablet: isTablet,
          onSectionChanged: (i) => setState(() => _selectedDrawerIndex = i),
        );
      case 'LAUNDRY_EMPLOYEE':
        return LaundryEmployeeDashboardWidget(
          scaffoldKey: _scaffoldKey,
          employeeName: widget.employeeName,
          propertyName: widget.propertyName,
          propertyId: widget.propertyId,
          empId: widget.empId ?? '',
          selectedSection: _selectedDrawerIndex,
          isTablet: isTablet,
          onSectionChanged: (i) => setState(() => _selectedDrawerIndex = i),
        );
      default:
        return const Center(child: Text('Unknown role'));
    }
  }
}
