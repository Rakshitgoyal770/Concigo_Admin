import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

/// Five-Star Luxury Hospitality Heartbeat Badge
/// Displays an animated pulsating radar dot, live connection status,
/// and elapsed time since last sync/heartbeat.
class LiveHeartbeatBadge extends StatefulWidget {
  final DateTime? lastPulseTime;
  final bool isSyncing;
  final int intervalSeconds;
  final VoidCallback? onTap;
  final String label;

  const LiveHeartbeatBadge({
    super.key,
    this.lastPulseTime,
    this.isSyncing = false,
    this.intervalSeconds = 10,
    this.onTap,
    this.label = 'LIVE QUEUE',
  });

  @override
  State<LiveHeartbeatBadge> createState() => _LiveHeartbeatBadgeState();
}

class _LiveHeartbeatBadgeState extends State<LiveHeartbeatBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  Timer? _ticker;
  int _secondsAgo = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _pulseOpacity = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _updateSecondsAgo();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateSecondsAgo();
      }
    });
  }

  void _updateSecondsAgo() {
    if (widget.lastPulseTime == null) {
      setState(() => _secondsAgo = 0);
      return;
    }
    final diff = DateTime.now().difference(widget.lastPulseTime!).inSeconds;
    if (diff != _secondsAgo) {
      setState(() => _secondsAgo = diff >= 0 ? diff : 0);
    }
  }

  @override
  void didUpdateWidget(covariant LiveHeartbeatBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastPulseTime != widget.lastPulseTime) {
      _updateSecondsAgo();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatElapsed() {
    if (widget.isSyncing) return 'Pulsing...';
    if (_secondsAgo <= 2) return 'Just now';
    if (_secondsAgo < 60) return '${_secondsAgo}s ago';
    return '${(_secondsAgo / 60).floor()}m ago';
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF10B981); // Emerald green for healthy heartbeat
    const activeLight = Color(0xFFECFDF5);
    const activeBorder = Color(0xFFA7F3D0);

    return Tooltip(
      message: 'Realtime WebSocket active • Auto-checks every ${widget.intervalSeconds}s • Tap to pulse now',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          hoverColor: activeBorder.withOpacity(0.3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: activeLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeBorder, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Pulsing Heartbeat Radar
                SizedBox(
                  width: 14,
                  height: 14,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseScale.value,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeColor.withOpacity(_pulseOpacity.value),
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeColor,
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withOpacity(0.5),
                              blurRadius: 3,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapH8,

                // Label and status text
                Text(
                  widget.label,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    fontSize: 10.5,
                    color: const Color(0xFF065F46),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Color(0xFF059669),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatElapsed(),
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 10.5,
                    color: const Color(0xFF047857),
                  ),
                ),

                if (widget.onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.isSyncing ? Icons.refresh_rounded : Icons.sync_rounded,
                    size: 13,
                    color: const Color(0xFF059669),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
