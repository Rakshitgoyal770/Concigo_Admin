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
  final List<String> _selectedRoomIds = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final stay = widget.stay;
    final phone = (stay['phone_number'] ?? stay['mobile_no'] ?? '').toString();
    _mobileController.text = phone;

    final stayRooms = stay['stay_rooms'] as List?;
    if (stayRooms != null && stayRooms.isNotEmpty) {
      for (final sr in stayRooms) {
        final rid = (sr as Map<String, dynamic>)['room_id']?.toString();
        if (rid != null && rid.isNotEmpty && rid != 'null' && !_selectedRoomIds.contains(rid)) {
          _selectedRoomIds.add(rid);
        }
      }
    } else {
      final existingRoomId = stay['room_id']?.toString();
      if (existingRoomId != null && existingRoomId.isNotEmpty && existingRoomId != 'null') {
        _selectedRoomIds.add(existingRoomId);
      }
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

    if (_selectedRoomIds.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one room before activating the stay.');
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

      // 2. Check room availability for all selected rooms (excluding current stay)
      for (final rid in _selectedRoomIds) {
        final isAvail = await stayService.checkRoomAvailable(
          roomId: rid,
          checkInDate: DateTime.now(),
          checkOutDate: DateTime.now().add(const Duration(days: 1)),
          excludeStayId: stayId,
        );
        if (!isAvail) {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'One or more selected rooms are currently occupied or assigned to another active guest.';
          });
          return;
        }
      }

      // 3. Fetch existing room_ids for this stay
      final existingRows = await supabaseService.client
          .from('stay_rooms')
          .select('room_id')
          .eq('stay_id', stayId);
      final existingRids = (existingRows as List)
          .map((r) => (r as Map<String, dynamic>)['room_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();

      // 4. Identify rooms that were removed/swapped out
      final removedRids = existingRids.where((id) => !_selectedRoomIds.contains(id)).toList();

      // 5. Identify rooms that are newly added
      final addedRids = _selectedRoomIds.where((id) => !existingRids.contains(id)).toList();

      // 6. Delete removed rooms from stay_rooms and free them up in rooms table
      for (final rid in removedRids) {
        await supabaseService.client
            .from('stay_rooms')
            .delete()
            .eq('stay_id', stayId)
            .eq('room_id', rid);

        // Release the old room
        try {
          await supabaseService.client
              .from('rooms')
              .update({
                'is_booked': false,
                'status': 'vacant',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('room_id', rid);
        } catch (_) {}
      }

      // 7. Insert newly added rooms into stay_rooms
      for (final rid in addedRids) {
        try {
          await supabaseService.client.from('stay_rooms').insert({
            'stay_id': stayId,
            'room_id': rid,
          });
        } catch (_) {}
      }

      // 8. Mark all currently selected rooms as Occupied & booked
      for (final rid in _selectedRoomIds) {
        await roomService.updateRoomStatus(rid, 'occupied');
        try {
          await supabaseService.client
              .from('rooms')
              .update({
                'is_booked': true,
                'status': 'occupied',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('room_id', rid);
        } catch (_) {}
      }

      // 9. Activate the stay record in Supabase
      await supabaseService.client
          .from('stay')
          .update({'status': 'Active'})
          .eq('stay_id', stayId);

      // 10. Update checkin_requests if applicable
      if (checkinRequestId != null && checkinRequestId.isNotEmpty) {
        try {
          await supabaseService.client
              .from('checkin_requests')
              .update({'accept_type': 'REGULAR', 'status': 'COMPLETED'})
              .eq('id', checkinRequestId);
        } catch (_) {}
      }

      // 5. Invalidate Riverpod Reception State
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

  String _roomSearchQuery = '';
  String _selectedCategory = 'All';
  String _selectedFloor = 'All Floors';

  String _getCat(Map<String, dynamic> r) =>
      (r['type'] ?? r['room_type'] ?? r['category'] ?? 'Standard').toString();

  String _getFloor(Map<String, dynamic> r) {
    if (r['floor'] != null && r['floor'].toString().isNotEmpty) {
      return 'Floor ${r['floor']}';
    }
    final numStr = (r['room_number'] ?? r['room_no'] ?? '').toString();
    final val = int.tryParse(numStr);
    if (val != null && val >= 100) return 'Floor ${val ~/ 100}';
    return 'Ground Floor';
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
            width: 560,
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
                              Text(guestName, style: AppTypography.labelLarge, overflow: TextOverflow.ellipsis),
                              Text('$phone • Stay: $checkIn to $checkOut', style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const LuxuryBadge(label: 'Online Booking', variant: LuxuryBadgeVariant.info, isSmall: true),
                      ],
                    ),
                  ),
                  AppSpacing.gapV16,

                  // Step 1: Room Assignment
                  roomsAsync.when(
                    data: (rooms) {
                      final vacantRooms = rooms.where((r) {
                        final isBooked = r['is_booked'] == true;
                        final rId = (r['room_id'] ?? r['id']).toString();
                        return !isBooked || _selectedRoomIds.contains(rId);
                      }).toList();

                      final distinctCategories = vacantRooms.map(_getCat).toSet().toList();
                      final allCategories = ['All', ...distinctCategories];
                      final floors = ['All Floors', ...vacantRooms.map(_getFloor).toSet()];

                      final filteredRooms = vacantRooms.where((r) {
                        final rNum = (r['room_number'] ?? r['room_no'] ?? '').toString().toLowerCase();
                        final rCat = _getCat(r).toLowerCase();
                        final rFloor = _getFloor(r).toLowerCase();
                        final q = _roomSearchQuery.toLowerCase().trim();

                        final matchQ = q.isEmpty || rNum.contains(q) || rCat.contains(q) || rFloor.contains(q);
                        final matchCat = _selectedCategory == 'All' || _getCat(r) == _selectedCategory;
                        final matchFloor = _selectedFloor == 'All Floors' || _getFloor(r) == _selectedFloor;

                        return matchQ && matchCat && matchFloor;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '1. Assign Physical Room(s)',
                                        style: AppTypography.labelLarge,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedRoomIds.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${_selectedRoomIds.length} assigned',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasAssignedRoom
                                ? 'Review pre-reserved rooms or filter by room type / number to reassign.'
                                : 'Select room(s) by type or room number to assign to this guest upon arrival.',
                            style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),

                          // Quick Assigned Rooms Chips Bar (if any selected)
                          if (_selectedRoomIds.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: AppSpacing.roundedMd,
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.key_rounded, size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _selectedRoomIds.map((rid) {
                                          final match = rooms.firstWhere(
                                            (r) => (r['room_id'] ?? r['id']).toString() == rid,
                                            orElse: () => <String, dynamic>{},
                                          );
                                          final num = (match['room_number'] ?? match['room_no'] ?? rid).toString();
                                          final cat = match.isNotEmpty ? _getCat(match) : '';

                                          return Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Room #$num ($cat)',
                                                  style: AppTypography.labelSmall.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                InkWell(
                                                  onTap: () => setState(() => _selectedRoomIds.remove(rid)),
                                                  child: const Icon(Icons.close, size: 13, color: AppColors.departure),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() => _selectedRoomIds.clear()),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.departure,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                    ),
                                    child: const Text('Clear', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Filter & Search Controls
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Search Input
                                SizedBox(
                                  height: 36,
                                  child: TextField(
                                    onChanged: (val) => setState(() => _roomSearchQuery = val),
                                    style: AppTypography.bodySmall.copyWith(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Search room number (e.g. 101, 204, Deluxe)...',
                                      hintStyle: AppTypography.bodySmall.copyWith(fontSize: 12, color: AppColors.textSecondary),
                                      prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                                      suffixIcon: _roomSearchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 14),
                                              onPressed: () => setState(() => _roomSearchQuery = ''),
                                            )
                                          : null,
                                      filled: true,
                                      fillColor: AppColors.surface,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Category & Floor Chips
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...allCategories.map((cat) {
                                        final isSel = _selectedCategory == cat;
                                        final count = cat == 'All'
                                            ? vacantRooms.length
                                            : vacantRooms.where((r) => _getCat(r) == cat).length;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: ChoiceChip(
                                            label: Text('$cat ($count)', style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                                            selected: isSel,
                                            selectedColor: AppColors.primaryLight,
                                            backgroundColor: AppColors.surface,
                                            labelStyle: TextStyle(color: isSel ? AppColors.primary : AppColors.textSecondary),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(6),
                                              side: BorderSide(color: isSel ? AppColors.primary : AppColors.border),
                                            ),
                                            onSelected: (_) => setState(() => _selectedCategory = cat),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                          ),
                                        );
                                      }),
                                      if (floors.length > 2) ...[
                                        Container(width: 1, height: 18, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 6)),
                                        ...floors.map((fl) {
                                          final isSel = _selectedFloor == fl;
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: ChoiceChip(
                                              label: Text(fl, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                                              selected: isSel,
                                              selectedColor: AppColors.infoLight,
                                              backgroundColor: AppColors.surface,
                                              labelStyle: TextStyle(color: isSel ? AppColors.info : AppColors.textSecondary),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                                side: BorderSide(color: isSel ? AppColors.info : AppColors.border),
                                              ),
                                              onSelected: (_) => setState(() => _selectedFloor = fl),
                                              visualDensity: VisualDensity.compact,
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Smart Room Cards View
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: filteredRooms.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No available rooms match your filter.',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: filteredRooms.map((r) {
                                        final rId = (r['room_id'] ?? r['id']).toString();
                                        final rNum = (r['room_number'] ?? r['room_no']).toString();
                                        final rType = _getCat(r);
                                        final rFloor = _getFloor(r);
                                        final isSelected = _selectedRoomIds.contains(rId);

                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedRoomIds.remove(rId);
                                              } else {
                                                _selectedRoomIds.add(rId);
                                              }
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            width: 100,
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: isSelected ? AppColors.primaryLight : AppColors.surface,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected ? AppColors.primary : AppColors.border,
                                                width: isSelected ? 1.5 : 1,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: AppColors.primary.withValues(alpha: 0.15),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      '#$rNum',
                                                      style: AppTypography.labelMedium.copyWith(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    Icon(
                                                      isSelected ? Icons.check_circle : Icons.bed_outlined,
                                                      size: 13,
                                                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  rType,
                                                  style: AppTypography.bodySmall.copyWith(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  rFloor,
                                                  style: AppTypography.bodySmall.copyWith(
                                                    fontSize: 9,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ],
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
