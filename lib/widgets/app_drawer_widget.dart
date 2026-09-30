import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../routes/app_routes.dart';

class AppDrawerWidget extends StatelessWidget {
  final String employeeName;
  final String role;
  final String propertyName;
  final int selectedIndex;
  final List<DrawerItem> items;
  final VoidCallback onLogout;

  const AppDrawerWidget({
    super.key,
    required this.employeeName,
    required this.role,
    required this.propertyName,
    required this.selectedIndex,
    required this.items,
    required this.onLogout,
  });


  Color _getRoleColor() {
    switch (role) {
      case 'SUPERADMIN':
        return AppTheme.superAdminColor;
      case 'RECEPTION':
      case 'RECEPTIONIST':
      case 'RECEPTION_DESK':
        return AppTheme.receptionColor;
      case 'SERVICE_MANAGER':
        return AppTheme.managerColor;
      case 'SERVICE_EMPLOYEE':
        return AppTheme.employeeColor;
      case 'SPA_MANAGER':
      case 'SPA_EMPLOYEE':
        return AppTheme.spaColor;
      case 'LAUNDRY_MANAGER':
      case 'LAUNDRY_EMPLOYEE':
        return AppTheme.laundryColor;
      default:
        return AppTheme.primary;
    }
  }


  String _getRoleLabel() {
    switch (role) {
      case 'SUPERADMIN':
        return 'Super Admin';
      case 'RECEPTION':
      case 'RECEPTIONIST':
      case 'RECEPTION_DESK':
        return 'Reception Desk';
      case 'SERVICE_MANAGER':
        return 'Service Manager';
      case 'SERVICE_EMPLOYEE':
        return 'Service Employee';
      default:
        return role;
    }
  }

  String _getInitials() {
    final parts = employeeName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'Z';
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor();

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.72,
      child: Column(
        children: [
          // Header — Concigo Deep Navy brand
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 20,
              left: 22,
              right: 22,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A1628), Color(0xFF1E3A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Concigo wordmark
                Row(
                  children: [
                    Image.asset(
                      'assets/images/concigo_logo_transparent.png',
                      height: 14,
                      width: 14,
                      color: AppTheme.brandGold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'CONCIGO',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.brandGold,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Avatar with role color ring
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: roleColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: roleColor.withAlpha(120),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employeeName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: roleColor.withAlpha(60)),
                            ),
                            child: Text(
                              _getRoleLabel(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: roleColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.location_city_rounded,
                      size: 12,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        propertyName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const SizedBox(height: 8),
                ...items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          item.onTap?.call();
                        },
                        borderRadius: BorderRadius.circular(12),
                        splashColor: AppTheme.primaryContainer,
                        highlightColor: AppTheme.primaryContainer.withAlpha(80),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 20,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.onSurfaceMuted,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : AppTheme.onSurface,
                                  ),
                                ),
                              ),
                              if (item.badge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    item.badge!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Footer - Logout
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.outlineVariant, width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Info links row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoLink(
                      context,
                      Icons.gavel_rounded,
                      'Terms',
                      AppRoutes.termsAndConditionsScreen,
                    ),
                    _buildInfoDivider(),
                    _buildInfoLink(
                      context,
                      Icons.shield_rounded,
                      'Privacy',
                      AppRoutes.privacyPolicyScreen,
                    ),
                    _buildInfoDivider(),
                    _buildInfoLink(
                      context,
                      Icons.support_agent_rounded,
                      'Contact',
                      AppRoutes.contactUsScreen,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Logout button
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showLogoutDialog(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    splashColor: AppTheme.errorContainer,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: AppTheme.error,
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Logout',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildInfoLink(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.onSurfaceMuted),
              const SizedBox(height: 3),
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
        ),
      ),
    );
  }

  Widget _buildInfoDivider() {
    return Container(width: 1, height: 28, color: AppTheme.outlineVariant);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.surface,
        title: Text(
          'Logout',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to logout from Zappy Admin?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.onSurfaceMuted,
          ),
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onLogout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Logout',
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
}

class DrawerItem {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback? onTap;

  const DrawerItem({
    required this.icon,
    required this.label,
    this.badge,
    this.onTap,
  });
}
