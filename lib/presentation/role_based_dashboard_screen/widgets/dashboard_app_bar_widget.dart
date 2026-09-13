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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
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

  String _getGreetingEmoji() {
    final hour = _now.hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  String _getInitials() {
    final parts = widget.employeeName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'Z';
  }

  String _formatTime() {
    final h = _now.hour > 12
        ? _now.hour - 12
        : (_now.hour == 0 ? 12 : _now.hour);
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final period = _now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m:$s $period';
  }

  String _formatDate() {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[_now.weekday - 1];
    final month = months[_now.month - 1];
    return '$dayName, ${_now.day} $month ${_now.year}';
  }

  String _getFirstName() {
    final parts = widget.employeeName.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : widget.employeeName;
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = widget.roleColor;
    final roleBg = roleColor.withAlpha(18);
    final roleBorder = roleColor.withAlpha(50);

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 148,
      backgroundColor: AppTheme.background,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withAlpha(15),
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: GestureDetector(
            onTap: () => widget.scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_rounded,
                size: 18,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: roleBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: roleBorder),
              ),
              child: Center(
                child: Text(
                  _getInitials(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: roleColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppTheme.background,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 8, 60, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting row
                  Row(
                    children: [
                      Text(
                        '${_getGreeting()}, ${_getFirstName()}! ${_getGreetingEmoji()}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Property + Role row
                  Row(
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.business_rounded,
                              size: 12,
                              color: AppTheme.onSurfaceMuted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.onSurfaceMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: roleBorder),
                        ),
                        child: Text(
                          widget.roleLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Date + Time row
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 11,
                        color: AppTheme.onSurfaceMuted.withAlpha(160),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.onSurfaceMuted.withAlpha(180),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: roleColor.withAlpha(180),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: roleColor.withAlpha(200),
                          letterSpacing: 0.3,
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
