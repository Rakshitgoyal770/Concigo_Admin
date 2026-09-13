import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _bgController;
  late AnimationController _logoRevealController;
  late AnimationController _logoScaleController;
  late AnimationController _titleController;
  late AnimationController _taglineController;
  late AnimationController _ctaController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;

  // Background
  late Animation<double> _bgOpacity;

  // Logo reveal (Netflix-style: starts as a dot, expands)
  late Animation<double> _logoReveal;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoGlow;

  // Title letter-by-letter
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleScale;

  // Tagline
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  // CTA
  late Animation<double> _ctaOpacity;
  late Animation<Offset> _ctaSlide;

  // Shimmer on logo
  late Animation<double> _shimmer;

  // Particle controller
  late Animation<double> _particle;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ctaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Background fade in
    _bgOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeOut));

    // Logo reveal: scale from 0 → 1 with overshoot (Netflix dot expand)
    _logoReveal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoRevealController, curve: Curves.easeOutExpo),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoScaleController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoRevealController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoScaleController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Title slide up + fade
    _titleOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _titleController, curve: Curves.easeOut));
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
        );
    _titleScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
    );

    // Tagline
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _taglineController,
            curve: Curves.easeOutCubic,
          ),
        );

    // CTA
    _ctaOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctaController, curve: Curves.easeOut));
    _ctaSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _ctaController, curve: Curves.easeOutCubic),
        );

    // Shimmer
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Particle
    _particle = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_particleController);

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Check for existing persistent session
    final session = await SupabaseService.instance.loadPersistedSession();
    if (session != null && session.propertyId.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.roleBasedDashboardScreen,
          arguments: {
            'role': session.role,
            'employeeName': session.fullName,
            'propertyName': session.propertyName,
            'propertyId': session.propertyId,
            'serviceId': session.serviceDept,
            'empId': session.empId,
          },
        );
        return;
      }
    }

    // Phase 1: Background fades in
    _bgController.forward();
    await Future.delayed(const Duration(milliseconds: 300));

    // Phase 2: Logo dot appears and expands (Netflix-style)
    _logoRevealController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _logoScaleController.forward();
    await Future.delayed(const Duration(milliseconds: 900));

    // Phase 3: Title sweeps up
    _titleController.forward();
    await Future.delayed(const Duration(milliseconds: 350));

    // Phase 4: Tagline
    _taglineController.forward();
    await Future.delayed(const Duration(milliseconds: 350));

    // Phase 5: CTA button
    _ctaController.forward();
    await Future.delayed(const Duration(milliseconds: 2200));

    // Auto-navigate
    if (mounted) {
      _navigateToLogin();
    }
  }

  Future<void> _navigateToLogin() async {
    final session = await SupabaseService.instance.loadPersistedSession();
    if (!mounted) return;

    if (session != null && session.propertyId.isNotEmpty) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.roleBasedDashboardScreen,
        arguments: {
          'role': session.role,
          'employeeName': session.fullName,
          'propertyName': session.propertyName,
          'propertyId': session.propertyId,
          'serviceId': session.serviceDept,
          'empId': session.empId,
        },
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.loginVerificationScreen);
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoRevealController.dispose();
    _logoScaleController.dispose();
    _titleController.dispose();
    _taglineController.dispose();
    _ctaController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgController,
          _logoRevealController,
          _logoScaleController,
          _titleController,
          _taglineController,
          _ctaController,
          _particleController,
          _shimmerController,
        ]),
        builder: (context, child) {
          return Stack(
            children: [
              // ── Background: white with subtle animated gradient accent ──
              Opacity(
                opacity: _bgOpacity.value,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white,
                ),
              ),

              // ── Animated background accent circles ──
              Opacity(
                opacity: _bgOpacity.value * 0.6,
                child: Stack(
                  children: [
                    // Top-right large circle
                    Positioned(
                      top: -size.height * 0.15,
                      right: -size.width * 0.2,
                      child: _AnimatedCircle(
                        size: size.width * 0.8,
                        color: AppTheme.primaryContainer,
                        progress: _particle.value,
                        phase: 0.0,
                      ),
                    ),
                    // Bottom-left circle
                    Positioned(
                      bottom: -size.height * 0.1,
                      left: -size.width * 0.15,
                      child: _AnimatedCircle(
                        size: size.width * 0.65,
                        color: const Color(0xFFEEF2FF),
                        progress: _particle.value,
                        phase: 0.33,
                      ),
                    ),
                    // Center subtle circle
                    Positioned(
                      top: size.height * 0.35,
                      right: -size.width * 0.3,
                      child: _AnimatedCircle(
                        size: size.width * 0.5,
                        color: const Color(0xFFF5F3FF),
                        progress: _particle.value,
                        phase: 0.66,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Floating particles ──
              Opacity(
                opacity: _bgOpacity.value * 0.5,
                child: _FloatingParticles(
                  progress: _particle.value,
                  size: size,
                ),
              ),

              // ── Main content ──
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 48.0 : 32.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),

                        // ── Logo reveal (Netflix-style dot → icon) ──
                        Transform.scale(
                          scale: _logoScale.value,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: _LogoWidget(
                              size: isTablet ? 110.0 : 88.0,
                              glowProgress: _logoGlow.value,
                              shimmerValue: _shimmer.value,
                            ),
                          ),
                        ),

                        SizedBox(height: isTablet ? 36 : 32),

                        // ── Company name ──
                        SlideTransition(
                          position: _titleSlide,
                          child: Transform.scale(
                            scale: _titleScale.value,
                            child: Opacity(
                              opacity: _titleOpacity.value,
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    AppTheme.primary,
                                    AppTheme.primaryLight,
                                    AppTheme.primaryMuted,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: Text(
                                  'ConcigoDesk',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: isTablet ? 44 : 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -1.0,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: isTablet ? 14 : 10),

                        // ── Tagline ──
                        SlideTransition(
                          position: _taglineSlide,
                          child: Opacity(
                            opacity: _taglineOpacity.value,
                            child: Text(
                              'Hotel operations, simplified.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: isTablet ? 17 : 15,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.onSurfaceMuted,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // ── CTA ──
                        SlideTransition(
                          position: _ctaSlide,
                          child: Opacity(
                            opacity: _ctaOpacity.value,
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _navigateToLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          14.0,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Get Started',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: isTablet ? 16 : 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Staff access only',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: isTablet ? 40 : 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Logo Widget with glow and shimmer ──
class _LogoWidget extends StatelessWidget {
  final double size;
  final double glowProgress;
  final double shimmerValue;

  const _LogoWidget({
    required this.size,
    required this.glowProgress,
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppTheme.outline, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha((glowProgress * 40).round()),
            blurRadius: 40 * glowProgress,
            spreadRadius: 8 * glowProgress,
          ),
          BoxShadow(
            color: AppTheme.primaryLight.withAlpha((glowProgress * 25).round()),
            blurRadius: 80 * glowProgress,
            spreadRadius: 4 * glowProgress,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Stack(
          children: [
            // Logo mark
            Center(
              child: Padding(
                padding: EdgeInsets.all(size * 0.1),
                child: Image.asset(
                  'assets/images/icon-removebg-preview-1782753555857.png',
                  width: size * 0.75,
                  height: size * 0.75,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Shimmer overlay
            Positioned.fill(
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(shimmerValue - 1, 0),
                  end: Alignment(shimmerValue, 0),
                  colors: [
                    Colors.white.withAlpha(0),
                    Colors.white.withAlpha(60),
                    Colors.white.withAlpha(0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Container(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated background circle ──
class _AnimatedCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double progress;
  final double phase;

  const _AnimatedCircle({
    required this.size,
    required this.color,
    required this.progress,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final offset = (progress + phase) % 1.0;
    final scale = 0.95 + 0.05 * (offset < 0.5 ? offset * 2 : (1 - offset) * 2);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

// ── Floating particles ──
class _FloatingParticles extends StatelessWidget {
  final double progress;
  final Size size;

  const _FloatingParticles({required this.progress, required this.size});

  @override
  Widget build(BuildContext context) {
    final particles = [
      _ParticleData(0.15, 0.3, 4.0, AppTheme.primaryMuted, 0.0),
      _ParticleData(0.75, 0.15, 6.0, AppTheme.primaryLight, 0.2),
      _ParticleData(0.85, 0.6, 3.5, AppTheme.primary, 0.4),
      _ParticleData(0.1, 0.7, 5.0, AppTheme.primaryMuted, 0.6),
      _ParticleData(0.5, 0.85, 4.5, AppTheme.primaryLight, 0.15),
      _ParticleData(0.65, 0.45, 3.0, AppTheme.primary, 0.55),
      _ParticleData(0.3, 0.1, 5.5, AppTheme.primaryMuted, 0.75),
      _ParticleData(0.9, 0.85, 4.0, AppTheme.primaryLight, 0.35),
    ];

    return Stack(
      children: particles.map((p) {
        final phase = (progress + p.phase) % 1.0;
        final dy = (phase < 0.5 ? phase * 2 : (1 - phase) * 2) * 12.0;
        return Positioned(
          left: size.width * p.x,
          top: size.height * p.y - dy,
          child: Container(
            width: p.radius * 2,
            height: p.radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.color.withAlpha(60),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ParticleData {
  final double x, y, radius, phase;
  final Color color;
  const _ParticleData(this.x, this.y, this.radius, this.color, this.phase);
}
