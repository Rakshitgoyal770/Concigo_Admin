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
      case 'RECEPTION_DESK':
        return AppTheme.receptionColor;
      case 'SERVICE_MANAGER':
        return AppTheme.managerColor;
      case 'SERVICE_EMPLOYEE':
        return AppTheme.employeeColor;
      default:
        return AppTheme.primary;
    }
  }

  Color _getRoleBgColor() {
    switch (role) {
      case 'SUPERADMIN':
        return AppTheme.superAdminContainer;
      case 'RECEPTION_DESK':
        return AppTheme.receptionContainer;
      case 'SERVICE_MANAGER':
        return AppTheme.managerContainer;
      case 'SERVICE_EMPLOYEE':
        return AppTheme.employeeContainer;
      default:
        return AppTheme.primaryContainer;
    }
  }

  String _getRoleLabel() {
    switch (role) {
      case 'SUPERADMIN':
        return 'Super Admin';
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
    final roleBgColor = _getRoleBgColor();

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.72,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: Colors.white.withAlpha(80),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _getRoleLabel(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withAlpha(230),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      size: 14,
                      color: Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        propertyName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
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
