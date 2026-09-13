import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class RoleCardWidget extends StatefulWidget {
  final String role;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final List<Color> gradientColors;
  final bool isTablet;
  final VoidCallback onTap;

  const RoleCardWidget({
    super.key,
    required this.role,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.gradientColors,
    required this.isTablet,
    required this.onTap,
  });

  @override
  State<RoleCardWidget> createState() => _RoleCardWidgetState();
}

class _RoleCardWidgetState extends State<RoleCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _pressController.forward();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _pressController.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _pressController.reverse();
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha(_isPressed ? 40 : 20),
                blurRadius: _isPressed ? 20 : 16,
                offset: const Offset(0, 6),
                spreadRadius: _isPressed ? 2 : 0,
              ),
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: _isPressed ? widget.color.withAlpha(60) : AppTheme.outline,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Top gradient bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.gradientColors),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(widget.isTablet ? 24 : 20),
                  child: widget.isTablet
                      ? _buildTabletLayout()
                      : _buildPhoneLayout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(widget.icon, size: 26, color: widget.color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurfaceMuted,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: widget.color,
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(widget.icon, size: 28, color: widget.color),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: widget.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          widget.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: widget.color,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.description,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppTheme.onSurfaceMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
