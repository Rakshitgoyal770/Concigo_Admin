import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import './widgets/role_card_widget.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late List<AnimationController> _cardControllers;
  late List<Animation<double>> _cardOpacities;
  late List<Animation<Offset>> _cardSlides;

  final List<Map<String, dynamic>> _roles = [
    {
      'role': 'SUPERADMIN',
      'title': 'Super Admin',
      'subtitle': 'Full property control & management',
      'description':
          'Manage employees, orders, property settings, and all operational data.',
      'icon': Icons.admin_panel_settings_rounded,
      'color': AppTheme.superAdminColor,
      'bgColor': AppTheme.superAdminContainer,
      'gradient': [const Color(0xFF7C3AED), const Color(0xFF9333EA)],
    },
    {
      'role': 'RECEPTION_DESK',
      'title': 'Reception Desk',
      'subtitle': 'Guest check-ins & stays',
      'description':
          'Handle guest arrivals, room assignments, and checkout operations.',
      'icon': Icons.desk_rounded,
      'color': AppTheme.receptionColor,
      'bgColor': AppTheme.receptionContainer,
      'gradient': [const Color(0xFF0891B2), const Color(0xFF0284C7)],
    },
    {
      'role': 'SERVICE_MANAGER',
      'title': 'Service Manager',
      'subtitle': 'Order management & team',
      'description': 'Accept, reject, and assign service orders to your team.',
      'icon': Icons.manage_accounts_rounded,
      'color': AppTheme.managerColor,
      'bgColor': AppTheme.managerContainer,
      'gradient': [const Color(0xFF059669), const Color(0xFF10B981)],
    },
    {
      'role': 'SERVICE_EMPLOYEE',
      'title': 'Service Employee',
      'subtitle': 'Assigned orders & delivery',
      'description': 'View your assigned orders and mark them as delivered.',
      'icon': Icons.room_service_rounded,
      'color': AppTheme.employeeColor,
      'bgColor': AppTheme.employeeContainer,
      'gradient': [const Color(0xFFD97706), const Color(0xFFF59E0B)],
    },
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _cardControllers = List.generate(
      _roles.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _cardOpacities = _cardControllers
        .map(
          (c) => Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)),
        )
        .toList();

    _cardSlides = _cardControllers
        .map(
          (c) => Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)),
        )
        .toList();

    _staggerCards();
  }

  Future<void> _staggerCards() async {
    for (int i = 0; i < _cardControllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) _cardControllers[i].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onRoleSelected(String role) {
    Navigator.pushNamed(
      context,
      AppRoutes.loginVerificationScreen,
      arguments: {'role': role},
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 48 : 24,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Z',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Zappy Admin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              Text(
                'Welcome to\nZappy Admin',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isTablet ? 36 : 30,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select your role to continue',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),

              const SizedBox(height: 32),

              // Role Cards
              if (isTablet)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _roles.length,
                  itemBuilder: (context, i) {
                    return AnimatedBuilder(
                      animation: _cardControllers[i],
                      builder: (context, child) {
                        return SlideTransition(
                          position: _cardSlides[i],
                          child: Opacity(
                            opacity: _cardOpacities[i].value,
                            child: child,
                          ),
                        );
                      },
                      child: RoleCardWidget(
                        role: _roles[i]['role'] as String,
                        title: _roles[i]['title'] as String,
                        subtitle: _roles[i]['subtitle'] as String,
                        description: _roles[i]['description'] as String,
                        icon: _roles[i]['icon'] as IconData,
                        color: _roles[i]['color'] as Color,
                        bgColor: _roles[i]['bgColor'] as Color,
                        gradientColors: _roles[i]['gradient'] as List<Color>,
                        isTablet: true,
                        onTap: () =>
                            _onRoleSelected(_roles[i]['role'] as String),
                      ),
                    );
                  },
                )
              else
                Column(
                  children: List.generate(_roles.length, (i) {
                    return AnimatedBuilder(
                      animation: _cardControllers[i],
                      builder: (context, child) {
                        return SlideTransition(
                          position: _cardSlides[i],
                          child: Opacity(
                            opacity: _cardOpacities[i].value,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: RoleCardWidget(
                          role: _roles[i]['role'] as String,
                          title: _roles[i]['title'] as String,
                          subtitle: _roles[i]['subtitle'] as String,
                          description: _roles[i]['description'] as String,
                          icon: _roles[i]['icon'] as IconData,
                          color: _roles[i]['color'] as Color,
                          bgColor: _roles[i]['bgColor'] as Color,
                          gradientColors: _roles[i]['gradient'] as List<Color>,
                          isTablet: false,
                          onTap: () =>
                              _onRoleSelected(_roles[i]['role'] as String),
                        ),
                      ),
                    );
                  }),
                ),

              const SizedBox(height: 24),

              // Footer
              Center(
                child: Text(
                  '© 2026 Zappy Hotels. All rights reserved.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
