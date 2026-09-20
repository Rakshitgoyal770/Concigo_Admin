import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../core/widgets/luxury_text_field.dart';
import '../../../../data/providers/supabase_providers.dart';
import '../../../../data/providers/reception_providers.dart';

class InstantWalkInDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialRoom;

  const InstantWalkInDialog({
    super.key,
    this.initialRoom,
  });

  @override
  ConsumerState<InstantWalkInDialog> createState() => _InstantWalkInDialogState();
}

class _InstantWalkInDialogState extends ConsumerState<InstantWalkInDialog> {
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _tariffController = TextEditingController();

  final List<Map<String, dynamic>> _selectedRooms = [];
  final DateTime _checkInDate = DateTime.now();
  final DateTime _checkOutDate = DateTime.now().add(const Duration(days: 1));
  bool _isSearchingPhone = false;
  bool _isSubmitting = false;
  bool _physicalIdVerified = true;
  String? _errorMessage;

  String _roomSearchQuery = '';
  String _selectedCategory = 'All';
  String _selectedFloor = 'All Floors';

  @override
  void initState() {
    super.initState();
    if (widget.initialRoom != null) {
      _selectedRooms.add(widget.initialRoom!);
      _recalculateTariff();
    }
  }

  void _recalculateTariff() {
    double total = 0;
    for (final r in _selectedRooms) {
      final base = r['base_price'] ?? r['price_per_night'] ?? 2500;
      total += (double.tryParse(base.toString()) ?? 2500.0);
    }
    _tariffController.text = total > 0 ? total.toStringAsFixed(0) : '2500';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _tariffController.dispose();
    super.dispose();
  }

  Future<void> _lookupPhone(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.length < 10) return;

    setState(() {
      _isSearchingPhone = true;
      _errorMessage = null;
    });

    try {
      final guest = await ref.read(guestServiceProvider).searchUserByPhone(cleanPhone);
      if (guest != null && mounted) {
        setState(() {
          _firstNameController.text = guest['first_name'] ?? guest['f_name'] ?? '';
          _lastNameController.text = guest['last_name'] ?? guest['l_name'] ?? '';
          _emailController.text = guest['email'] ?? '';
        });
      }
    } catch (e) {
      // Not found, will create new guest seamlessly
    } finally {
      if (mounted) setState(() => _isSearchingPhone = false);
    }
  }

  Future<void> _processWalkIn() async {
    final phone = _phoneController.text.trim();
    final fName = _firstNameController.text.trim();
    final lName = _lastNameController.text.trim();

    if (phone.isEmpty || fName.isEmpty) {
      setState(() => _errorMessage = 'Please provide guest phone number and name.');
      return;
    }

    if (_selectedRooms.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one available room.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final guestService = ref.read(guestServiceProvider);
      final stayService = ref.read(stayServiceProvider);
      final roomService = ref.read(roomServiceProvider);
      final propId = await ref.read(resolvedPropertyIdProvider.future);

      // 1. Get or create user
      await guestService.getOrCreateUser(phone);

      final roomIds = _selectedRooms
          .map((r) => (r['room_id'] ?? r['id']).toString())
          .toList();
      final roomNumbers = _selectedRooms
          .map((r) => (r['room_number'] ?? r['room_no']).toString())
          .toList();

      // Check if all rooms are available
      for (final r in _selectedRooms) {
        final rid = (r['room_id'] ?? r['id']).toString();
        final rnum = (r['room_number'] ?? r['room_no']).toString();
        final isAvail = await stayService.checkRoomAvailable(
          roomId: rid,
          checkInDate: _checkInDate,
          checkOutDate: _checkOutDate,
        );
        if (!isAvail) {
          setState(() => _errorMessage = 'Room $rnum is already booked or occupied.');
          return;
        }
      }

      // 2. Create Stay record with all room IDs
      final stayId = await stayService.createStay(
        propertyId: propId,
        guestMobiles: [phone],
        roomIds: roomIds,
        checkInDate: _checkInDate,
        checkOutDate: _checkOutDate,
      );

      // 3. Activate stay and mark each room occupied
      for (final rid in roomIds) {
        await stayService.activateStay(
          stayId: stayId,
          roomId: rid,
          assignRoom: true,
        );
        await roomService.updateRoomStatus(rid, 'occupied');
      }

      // 4. Invalidate Reception Providers
      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Walk-In Activated! ${roomNumbers.length > 1 ? "Rooms" : "Room"} ${roomNumbers.join(", ")} assigned to $fName $lName.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Walk-In failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(receptionRoomsProvider);

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          return Container(
            width: 540,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Responsive Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.infoLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.flash_on_rounded, color: AppColors.info, size: 20),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instant Desk Walk-In',
                              style: AppTypography.titleMedium.copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '30-second rapid check-in & room allotment',
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

                  // Step 1: Guest Identity
                  Text('1. Guest Identity', style: AppTypography.labelLarge),
                  AppSpacing.gapV12,
                  LuxuryTextField(
                    controller: _phoneController,
                    label: 'Phone Number (Primary Key)',
                    hintText: 'e.g. 9876543210',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: AppColors.primary),
                    suffixIcon: _isSearchingPhone
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search, size: 18),
                            onPressed: () => _lookupPhone(_phoneController.text),
                          ),
                    onChanged: (val) {
                      if (val.trim().length >= 10) _lookupPhone(val);
                    },
                  ),
                  AppSpacing.gapV12,

                  if (isNarrow) ...[
                    LuxuryTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      hintText: 'John',
                    ),
                    AppSpacing.gapV12,
                    LuxuryTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      hintText: 'Doe',
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: LuxuryTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            hintText: 'John',
                          ),
                        ),
                        AppSpacing.gapH12,
                        Expanded(
                          child: LuxuryTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            hintText: 'Doe',
                          ),
                        ),
                      ],
                    ),
                  ],
                  AppSpacing.gapV12,
                  LuxuryTextField(
                    controller: _emailController,
                    label: 'Email (Optional)',
                    hintText: 'guest@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AppSpacing.gapV16,

                  // Step 2: Room Allocation
                  roomsAsync.when(
                    data: (rooms) {
                      final vacantRooms = rooms.where((r) {
                        final isBooked = r['is_booked'] == true;
                        final status = (r['status'] as String? ?? '').toUpperCase();
                        return !isBooked && (status != 'OCCUPIED' && status != 'MAINTENANCE');
                      }).toList();

                      String getCat(Map<String, dynamic> r) =>
                          (r['type'] ?? r['room_type'] ?? r['category'] ?? 'Standard').toString();
                      String getFloor(Map<String, dynamic> r) {
                        if (r['floor'] != null && r['floor'].toString().isNotEmpty) {
                          return 'Floor ${r['floor']}';
                        }
                        final numStr = (r['room_number'] ?? r['room_no'] ?? '').toString();
                        final val = int.tryParse(numStr);
                        if (val != null && val >= 100) return 'Floor ${val ~/ 100}';
                        return 'Ground Floor';
                      }

                      final categories = ['All', ...vacantRooms.map(getCat).toSet()];
                      final floors = ['All Floors', ...vacantRooms.map(getFloor).toSet()];

                      final filteredRooms = vacantRooms.where((r) {
                        final rNum = (r['room_number'] ?? r['room_no'] ?? '').toString().toLowerCase();
                        final rCat = getCat(r).toLowerCase();
                        final rFloor = getFloor(r).toLowerCase();
                        final q = _roomSearchQuery.toLowerCase().trim();

                        final matchQ = q.isEmpty || rNum.contains(q) || rCat.contains(q) || rFloor.contains(q);
                        final matchCat = _selectedCategory == 'All' || getCat(r) == _selectedCategory;
                        final matchFloor = _selectedFloor == 'All Floors' || getFloor(r) == _selectedFloor;

                        return matchQ && matchCat && matchFloor;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text('2. Room Allocation & Tariff', style: AppTypography.labelLarge),
                                ],
                              ),
                              if (_selectedRooms.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${_selectedRooms.length} selected',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select one or multiple vacant rooms for this walk-in guest.',
                            style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),

                          // Search & Quick Filter Controls
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
                                // Room Search Box
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
                                if (categories.length > 1) ...[
                                  const SizedBox(height: 8),
                                  // Category & Floor Filter Chips
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ...categories.map((cat) {
                                          final isSel = _selectedCategory == cat;
                                          final count = cat == 'All'
                                              ? vacantRooms.length
                                              : vacantRooms.where((r) => getCat(r) == cat).length;
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Smart Room Cards View
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: vacantRooms.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No vacant rooms currently available.',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ),
                                  )
                                : filteredRooms.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            'No rooms match your filter or search.',
                                            style: AppTypography.bodySmall.copyWith(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: filteredRooms.map((r) {
                                            final rId = (r['room_id'] ?? r['id']).toString();
                                            final rNum = (r['room_number'] ?? r['room_no']).toString();
                                            final rType = getCat(r);
                                            final rFloor = getFloor(r);
                                            final price = r['base_price'] ?? r['price_per_night'] ?? 2500;
                                            final isSelected = _selectedRooms.any(
                                              (sr) => (sr['room_id'] ?? sr['id']).toString() == rId,
                                            );

                                            return InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (!isSelected) {
                                                    _selectedRooms.add(r);
                                                  } else {
                                                    _selectedRooms.removeWhere(
                                                      (sr) => (sr['room_id'] ?? sr['id']).toString() == rId,
                                                    );
                                                  }
                                                  _recalculateTariff();
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(10),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 150),
                                                width: 110,
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: isSelected ? AppColors.primaryLight : AppColors.surface,
                                                  borderRadius: BorderRadius.circular(10),
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
                                                          'Room $rNum',
                                                          style: AppTypography.labelMedium.copyWith(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w700,
                                                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                                          ),
                                                        ),
                                                        Icon(
                                                          isSelected ? Icons.check_circle : Icons.bed_outlined,
                                                          size: 14,
                                                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          rFloor,
                                                          style: AppTypography.bodySmall.copyWith(
                                                            fontSize: 9,
                                                            color: AppColors.textMuted,
                                                          ),
                                                        ),
                                                        Text(
                                                          '₹$price',
                                                          style: AppTypography.labelSmall.copyWith(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: AppColors.primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                          ),
                          if (_selectedRooms.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_selectedRooms.length} room${_selectedRooms.length > 1 ? "s" : ""} selected',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedRooms.clear();
                                      _recalculateTariff();
                                    });
                                  },
                                  icon: const Icon(Icons.clear_all_rounded, size: 14),
                                  label: const Text('Clear All Rooms', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.departure,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading rooms: $e'),
                  ),
                  AppSpacing.gapV12,
                  LuxuryTextField(
                    controller: _tariffController,
                    label: 'Tariff Rate (₹ / Night)',
                    hintText: '2500',
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                  ),
                  AppSpacing.gapV16,

                  // Step 3: Physical ID Checkbox
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: AppSpacing.roundedMd,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _physicalIdVerified,
                          activeColor: AppColors.success,
                          onChanged: (val) => setState(() => _physicalIdVerified = val ?? true),
                        ),
                        AppSpacing.gapH8,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Physical ID Card Verified at Desk', style: AppTypography.labelMedium),
                              Text(
                                'Government ID (Aadhaar / Passport / DL) inspected by receptionist',
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapV20,

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
                      ),
                      AppSpacing.gapH8,
                      LuxuryButton(
                        text: 'Activate Stay (30s)',
                        variant: LuxuryButtonVariant.primary,
                        icon: Icons.check_circle_outline,
                        height: 38,
                        isLoading: _isSubmitting,
                        onPressed: _processWalkIn,
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
