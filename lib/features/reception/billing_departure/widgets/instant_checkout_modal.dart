import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/supabase_providers.dart';
import '../../../../data/providers/reception_providers.dart';

class InstantCheckoutModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> stay;

  const InstantCheckoutModal({
    super.key,
    required this.stay,
  });

  @override
  ConsumerState<InstantCheckoutModal> createState() => _InstantCheckoutModalState();
}

class _InstantCheckoutModalState extends ConsumerState<InstantCheckoutModal> {
  bool _isProcessing = false;
  bool _markHousekeeping = true;
  String? _errorMessage;

  Future<void> _processCheckout() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final stayId = (widget.stay['stay_id'] ?? widget.stay['id']).toString();
    final roomId = (widget.stay['room_id'] ?? '').toString().trim();
    final guestName = (widget.stay['guest_name'] ?? widget.stay['user_name'] ?? 'Guest').toString();
    final roomNum = (widget.stay['room_number'] ?? widget.stay['room_no'] ?? 'N/A').toString();

    try {
      final stayService = ref.read(stayServiceProvider);
      final roomService = ref.read(roomServiceProvider);

      // 1. Checkout Stay — now returns CheckoutResult (ISSUE-16)
      final result = await stayService.checkoutStay(stayId: stayId, roomId: roomId);

      // 2. Set all assigned rooms to Needs Cleaning if requested
      if (_markHousekeeping) {
        final roomsToClean = <String>{};
        if (roomId.isNotEmpty && roomId != 'null' && roomId != 'N/A') {
          roomsToClean.add(roomId);
        }
        final stayRooms = widget.stay['stay_rooms'] as List?;
        if (stayRooms != null) {
          for (final sr in stayRooms) {
            final rid = (sr is Map ? sr['room_id'] : null)?.toString().trim();
            if (rid != null && rid.isNotEmpty && rid != 'null' && rid != 'N/A') {
              roomsToClean.add(rid);
            }
          }
        }
        for (final r in roomsToClean) {
          try {
            await roomService.updateRoomStatus(r, 'cleaning');
          } catch (_) {}
        }
      }

      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);

        // Show PMS warning if sync failed
        if (!result.pmsSynced && result.pmsWarning != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 8),
              content: Text(
                '⚠️ ${result.pmsWarning}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Stay for $guestName (Room $roomNum) successfully checked out!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Checkout failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stay = widget.stay;
    final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
    final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'N/A').toString();

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.departureLight,
                    borderRadius: AppSpacing.roundedMd,
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.departure, size: 22),
                ),
                AppSpacing.gapH12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Complete Departure & Checkout', style: AppTypography.titleMedium),
                      Text('Release Room $roomNum assigned to $guestName', style: AppTypography.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: AppColors.departure, fontSize: 13)),
              AppSpacing.gapV12,
            ],

            Text(
              'Are you sure you want to finalize departure for $guestName in Room $roomNum?',
              style: AppTypography.bodyLarge,
            ),
            AppSpacing.gapV16,

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _markHousekeeping,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _markHousekeeping = v ?? true),
                  ),
                  AppSpacing.gapH8,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notify Housekeeping (Needs Cleaning)', style: AppTypography.labelMedium),
                        Text('Instantly updates Room $roomNum on the Housekeeping matrix', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapV24,

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 360;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                    ),
                    AppSpacing.gapH8,
                    LuxuryButton(
                      text: isNarrow ? 'Checkout' : 'Confirm Checkout & Release',
                      variant: LuxuryButtonVariant.danger,
                      icon: Icons.check,
                      height: 38,
                      isLoading: _isProcessing,
                      onPressed: _processCheckout,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
