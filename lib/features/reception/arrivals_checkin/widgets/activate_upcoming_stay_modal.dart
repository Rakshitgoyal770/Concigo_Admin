import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_text_field.dart';
import '../../../../data/providers/supabase_providers.dart';
import '../../../../data/providers/reception_providers.dart';

class ActivateUpcomingStayModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> stay;

  const ActivateUpcomingStayModal({
    super.key,
    required this.stay,
  });

  @override
  ConsumerState<ActivateUpcomingStayModal> createState() => _ActivateUpcomingStayModalState();
}

class _ActivateUpcomingStayModalState extends ConsumerState<ActivateUpcomingStayModal> {
  final _codeController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _isProcessing = false;
  String? _selectedRoomId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final stay = widget.stay;
    final phone = (stay['phone_number'] ?? stay['mobile_no'] ?? '').toString();
    _mobileController.text = phone;

    final existingRoomId = stay['room_id']?.toString();
    if (existingRoomId != null && existingRoomId.isNotEmpty && existingRoomId != 'null') {
      _selectedRoomId = existingRoomId;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleActivation() async {
    final stay = widget.stay;
    final stayId = (stay['stay_id'] ?? stay['id']).toString();
    final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
    final checkinRequestId = stay['checkin_request_id']?.toString();
    final hasAssignedRoom = stay['room_id'] != null && stay['room_id'].toString().isNotEmpty && stay['room_id'].toString() != 'null';

    if (_selectedRoomId == null || _selectedRoomId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a room before activating the stay.');
      return;
    }

    final code = _codeController.text.trim();
    final mobile = _mobileController.text.trim();

    if (code.isEmpty || mobile.isEmpty) {
      setState(() => _errorMessage = 'Please enter both mobile number and check-in code.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final stayService = ref.read(stayServiceProvider);
      final roomService = ref.read(roomServiceProvider);
      final supabaseService = ref.read(supabaseServiceProvider);

      // 1. Verify Check-in Code
      final isValidCode = await supabaseService.verifyCheckinCode(
        stayId: stayId,
        mobileNo: mobile,
        checkinCode: code,
      );

      if (!isValidCode) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Invalid check-in code or mobile number mismatch.';
        });
        return;
      }

      // 2. Check room availability
      final isAvail = await stayService.checkRoomAvailable(
        roomId: _selectedRoomId!,
        checkInDate: DateTime.now(),
        checkOutDate: DateTime.now().add(const Duration(days: 1)),
        excludeStayId: stayId,
      );
      if (!isAvail) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Selected room is currently occupied or assigned to another active guest.';
        });
        return;
      }

      // 3. Activate the Stay in Supabase
      await stayService.activateStay(
        stayId: stayId,
        roomId: _selectedRoomId!,
        assignRoom: !hasAssignedRoom,
        checkinRequestId: checkinRequestId,
        acceptType: 'REGULAR',
      );

      // 3. Mark Room as Occupied
      await roomService.updateRoomStatus(_selectedRoomId!, 'occupied');

      // 4. Invalidate Riverpod Reception State
      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Stay successfully activated for $guestName!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Activation failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stay = widget.stay;
    final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
    final phone = (stay['phone_number'] ?? stay['mobile_no'] ?? '').toString();
    final checkIn = (stay['check_in_date'] ?? 'Today').toString().split('T')[0];
    final checkOut = (stay['check_out_date'] ?? 'Tomorrow').toString().split('T')[0];
    final assignedRoomNum = stay['room_number']?.toString();
    final hasAssignedRoom = assignedRoomNum != null && assignedRoomNum.isNotEmpty && assignedRoomNum != 'null' && assignedRoomNum != 'N/A';

    final roomsAsync = ref.watch(receptionRoomsProvider);

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: 540,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modal Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.flight_land_rounded, color: AppColors.primary, size: 20),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activate Online / Scheduled Stay',
                              style: AppTypography.titleMedium.copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Complete guest arrival & room assignment',
                              style: AppTypography.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.departureLight,
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: AppColors.departureBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AppColors.departure),
                          AppSpacing.gapH8,
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.departure),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapV12,
                  ],

                  // Guest Summary Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: AppSpacing.roundedMd,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.person, size: 16, color: AppColors.primary),
                          ),
                        ),
                        AppSpacing.gapH12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(guestName, style: AppTypography.labelLarge),
                              Text('$phone • Stay: $checkIn to $checkOut', style: AppTypography.bodySmall),
                            ],
                          ),
                        ),
                        const LuxuryBadge(label: 'Online Booking', variant: LuxuryBadgeVariant.info, isSmall: true),
                      ],
                    ),
                  ),
                  AppSpacing.gapV16,

                  // Step 1: Room Assignment
                  Text('1. Assigned Room', style: AppTypography.labelLarge),
                  AppSpacing.gapV8,

                  roomsAsync.when(
                    data: (rooms) {
                      final vacantRooms = rooms.where((r) {
                        final isBooked = r['is_booked'] == true;
                        final rId = (r['room_id'] ?? r['id']).toString();
                        return !isBooked || rId == _selectedRoomId;
                      }).toList();

                      return DropdownButtonFormField<String>(
                        initialValue: _selectedRoomId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: hasAssignedRoom ? 'Pre-Assigned Room' : 'Select Available Room to Assign',
                          prefixIcon: const Icon(Icons.meeting_room_outlined, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: vacantRooms.map((r) {
                          final rId = (r['room_id'] ?? r['id']).toString();
                          final rNum = (r['room_number'] ?? r['room_no']).toString();
                          final rType = (r['type'] ?? r['room_type'] ?? r['category'] ?? 'Standard').toString();
                          return DropdownMenuItem(
                            value: rId,
                            child: Text('Room $rNum ($rType)', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedRoomId = val);
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading rooms: $e'),
                  ),
                  AppSpacing.gapV16,

                  // Step 2: Verification with Guest App Code
                  Text('2. Guest Check-In Verification Code', style: AppTypography.labelLarge),
                  AppSpacing.gapV4,
                  Text(
                    'Enter the 4-digit fast-track code displayed on the guest’s Concigo app',
                    style: AppTypography.bodySmall,
                  ),
                  AppSpacing.gapV12,

                  LuxuryTextField(
                    controller: _codeController,
                    label: 'Guest App Check-In Code',
                    hintText: 'e.g. 8492',
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.pin_outlined, size: 18, color: AppColors.primary),
                  ),
                  AppSpacing.gapV24,

                  // Action Buttons
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                      ),
                      LuxuryButton(
                        text: 'Complete Check-In',
                        variant: LuxuryButtonVariant.primary,
                        icon: Icons.check_circle_outline,
                        height: 38,
                        isLoading: _isProcessing,
                        onPressed: _handleActivation,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
