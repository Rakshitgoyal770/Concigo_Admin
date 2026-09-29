import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class DashboardAppBarWidget extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final String title;
  final String subtitle;
  final Color roleColor;
  final String roleLabel;
  final String employeeName;

  const DashboardAppBarWidget({
    super.key,
    required this.scaffoldKey,
    required this.title,
    required this.subtitle,
    required this.roleColor,
    required this.roleLabel,
    required this.employeeName,
  });

  @override
  State<DashboardAppBarWidget> createState() => _DashboardAppBarWidgetState();
}

class _DashboardAppBarWidgetState extends State<DashboardAppBarWidget> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Tick every minute — no need for per-second rebuild, reduces setState calls
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getGreeting() {
    final hour = _now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getInitials() {
    final parts = widget.employeeName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'C';
  }

  String _formatDateTime() {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dayName = days[_now.weekday - 1];
    final month = months[_now.month - 1];
    final h = _now.hour > 12 ? _now.hour - 12 : (_now.hour == 0 ? 12 : _now.hour);
    final m = _now.minute.toString().padLeft(2, '0');
    final period = _now.hour >= 12 ? 'PM' : 'AM';
    return '$dayName, ${_now.day} $month  ·  $h:$m $period';
  }

  String _getFirstName() {
    final parts = widget.employeeName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : widget.employeeName;
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = widget.roleColor;
    final roleBg = roleColor.withAlpha(20);
    final roleBorder = roleColor.withAlpha(45);

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 136,
      backgroundColor: AppTheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Menu button — opens drawer
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Center(
          child: GestureDetector(
            onTap: () => widget.scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: const Icon(
                Icons.menu_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      // Avatar + notification
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.brandGold.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.brandGold.withAlpha(80)),
              ),
              child: Center(
                child: Text(
                  _getInitials(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandGold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A1628), Color(0xFF1E3A5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(64, 8, 64, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Concigo logo + brand name
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/concigo_logo_transparent.png',
                        height: 18,
                        width: 18,
                        color: AppTheme.brandGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'CONCIGO',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.brandGold,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Greeting
                  Text(
                    '${_getGreeting()}, ${_getFirstName()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // Property · Role · Date
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white60,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: Colors.white30,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleBg,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: roleBorder),
                        ),
                        child: Text(
                          widget.roleLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Date & time
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 10,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white38,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
