import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../routes/app_routes.dart';
import '../services/supabase_service.dart';

class RoleSwitcherDialog extends StatelessWidget {
  /// If [isInitialLogin] is true, this shutter is shown right after OTP verification.
  /// The user must pick a role to proceed (cannot dismiss).
  final bool isInitialLogin;
  final List<Map<String, dynamic>>? overrideRoles;

  const RoleSwitcherDialog({
    super.key,
    this.isInitialLogin = false,
    this.overrideRoles,
  });

  /// Presents the Role Selector as a smooth, luxury top shutter sliding down from the ceiling.
  static Future<void> show(
    BuildContext context, {
    bool isInitialLogin = false,
    List<Map<String, dynamic>>? roles,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: !isInitialLogin,
      barrierLabel: 'Workstation Shutter',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim, secAnim) {
        return Align(
          alignment: Alignment.topCenter,
          child: RoleSwitcherDialog(
            isInitialLogin: isInitialLogin,
            overrideRoles: roles,
          ),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1), // Starts above top of screen
            end: Offset.zero,           // Slides down flush to top
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  static IconData getRoleIcon(String role) {
    switch (role.toUpperCase()) {
      case 'SUPERADMIN':
        return Icons.admin_panel_settings_rounded;
      case 'RECEPTION':
      case 'RECEPTION_DESK':
      case 'RECEPTIONIST':
        return Icons.desk_rounded;
      case 'SERVICE_MANAGER':
        return Icons.manage_accounts_rounded;
      case 'SERVICE_EMPLOYEE':
        return Icons.room_service_rounded;
      case 'SPA_MANAGER':
      case 'SPA_EMPLOYEE':
        return Icons.spa_rounded;
      case 'LAUNDRY_MANAGER':
      case 'LAUNDRY_EMPLOYEE':
        return Icons.local_laundry_service_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  static Color getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'SUPERADMIN':
        return const Color(0xFF7C3AED);
      case 'RECEPTION':
      case 'RECEPTION_DESK':
      case 'RECEPTIONIST':
        return const Color(0xFF0891B2);
      case 'SERVICE_MANAGER':
        return const Color(0xFF059669);
      case 'SERVICE_EMPLOYEE':
        return const Color(0xFFD97706);
      case 'SPA_MANAGER':
      case 'SPA_EMPLOYEE':
        return const Color(0xFFEC4899);
      case 'LAUNDRY_MANAGER':
      case 'LAUNDRY_EMPLOYEE':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  static String formatRoleName(String role) {
    switch (role.toUpperCase()) {
      case 'SUPERADMIN':
        return 'Super Administrator';
      case 'RECEPTION':
      case 'RECEPTION_DESK':
      case 'RECEPTIONIST':
        return 'Front Desk & Reception';
      case 'SERVICE_MANAGER':
        return 'Service / F&B Manager';
      case 'SERVICE_EMPLOYEE':
        return 'Service Associate';
      case 'SPA_MANAGER':
        return 'Spa Manager';
      case 'SPA_EMPLOYEE':
        return 'Spa Therapist / Staff';
      case 'LAUNDRY_MANAGER':
        return 'Laundry Manager';
      case 'LAUNDRY_EMPLOYEE':
        return 'Laundry Staff';
      default:
        return role.replaceAll('_', ' ');
    }
  }

  void _switchRole(BuildContext context, Map<String, dynamic> targetEmp) {
    final session = SupabaseService.instance.currentSession;
    final allRoles = overrideRoles ?? session?.authorizedRoles ?? [targetEmp];

    final propName = (targetEmp['property_name'] as String?) ??
        ((targetEmp['hotel_property'] as Map<String, dynamic>?)?['name'] as String?) ??
        session?.propertyName ??
        'Concigo Property';

    SupabaseService.instance.buildSession(
      employee: targetEmp,
      propertyName: propName,
      allRoles: allRoles,
    );

    final updated = SupabaseService.instance.currentSession!;

    Fluttertoast.showToast(
      msg: 'Switched to ${formatRoleName(updated.role)}',
      backgroundColor: getRoleColor(updated.role),
      textColor: Colors.white,
    );

    Navigator.of(context).pop();

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleBasedDashboardScreen,
      (route) => false,
      arguments: {
        'role': updated.role,
        'employeeName': updated.fullName.isNotEmpty ? updated.fullName : 'Staff',
        'propertyName': updated.propertyName,
        'propertyId': updated.propertyId,
        'serviceId': updated.serviceDept,
        'empId': updated.empId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SupabaseService.instance.currentSession;
    final roles = overrideRoles ?? session?.authorizedRoles ?? [];
    final currentEmpId = session?.empId ?? '';

    return GestureDetector(
      // Slide/flick up to close shutter
      onVerticalDragUpdate: (details) {
        if (!isInitialLogin && details.primaryDelta! < -8) {
          Navigator.of(context).pop();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 820),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Brand & Title & Close
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.dashboard_customize_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isInitialLogin ? 'SELECT ACTIVE WORKSPACE' : 'WORKSTATION CONTROL SHUTTER',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFC7D2FE), width: 0.8),
                                  ),
                                  child: Text(
                                    '${roles.length} AVAILABLE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isInitialLogin
                                  ? 'Your phone number has credentials across multiple departments.'
                                  : 'Select any role below to switch your live dashboard and permissions instantly.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isInitialLogin)
                        IconButton(
                          tooltip: 'Close Shutter',
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 14),

                  // Roles List / Grid
                  if (roles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'No additional roles found for this account.',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.52,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: roles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final emp = roles[index];
                          final empId = emp['emp_id']?.toString() ?? '';
                          final role = emp['role']?.toString() ?? '';
                          final isActive = !isInitialLogin && empId == currentEmpId;

                          final propName = (emp['property_name'] as String?) ??
                              ((emp['hotel_property'] as Map<String, dynamic>?)?['name'] as String?) ??
                              'Hotel Property';

                          final serviceName = emp['service_name'] as String?;
                          final roleColor = getRoleColor(role);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isActive ? null : () => _switchRole(context, emp),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? roleColor.withValues(alpha: 0.06)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isActive ? roleColor : const Color(0xFFE2E8F0),
                                    width: isActive ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Icon badge
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        getRoleIcon(role),
                                        color: roleColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  formatRoleName(role),
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF1E293B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isActive) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: roleColor,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    'ACTIVE',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.5,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.business_rounded,
                                                size: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  propName,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    color: const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (serviceName != null && serviceName.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                const Text('•', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    serviceName,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      color: roleColor,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    // Action indicator
                                    if (isActive)
                                      Icon(Icons.check_circle_rounded, color: roleColor, size: 20)
                                    else
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 13),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // ── BOTTOM SHUTTER HANDLE (UP ARROW) ─────────────────────────
                  if (!isInitialLogin) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 38,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'SLIDE UP TO CLOSE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
