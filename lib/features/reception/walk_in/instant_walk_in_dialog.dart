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

  Map<String, dynamic>? _selectedRoom;
  DateTime _checkInDate = DateTime.now();
  DateTime _checkOutDate = DateTime.now().add(const Duration(days: 1));
  bool _isSearchingPhone = false;
  bool _isSubmitting = false;
  bool _physicalIdVerified = true;
  String? _guestId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.initialRoom;
    if (_selectedRoom != null) {
      final basePrice = _selectedRoom?['base_price'] ?? _selectedRoom?['price_per_night'] ?? 2500;
      _tariffController.text = basePrice.toString();
    }
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
          _guestId = guest['user_id'] ?? guest['id'];
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
    final tariff = double.tryParse(_tariffController.text.trim()) ?? 2500.0;

    if (phone.isEmpty || fName.isEmpty) {
      setState(() => _errorMessage = 'Please provide guest phone number and name.');
      return;
    }

    if (_selectedRoom == null) {
      setState(() => _errorMessage = 'Please select an available room.');
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

      final roomId = (_selectedRoom!['room_id'] ?? _selectedRoom!['id']).toString();
      final roomNumber = (_selectedRoom!['room_number'] ?? _selectedRoom!['room_no']).toString();

      // Check if room is available
      final isAvail = await stayService.checkRoomAvailable(
        roomId: roomId,
        checkInDate: _checkInDate,
        checkOutDate: _checkOutDate,
      );
      if (!isAvail) {
        setState(() => _errorMessage = 'Room $roomNumber is already booked or occupied.');
        return;
      }

      // 2. Create Stay record
      final stayId = await stayService.createStay(
        propertyId: propId,
        guestMobiles: [phone],
        roomIds: [roomId],
        checkInDate: _checkInDate,
        checkOutDate: _checkOutDate,
      );

      // 3. Activate stay immediately
      await stayService.activateStay(
        stayId: stayId,
        roomId: roomId,
        assignRoom: true,
      );

      // 4. Mark Room Occupied
      await roomService.updateRoomStatus(roomId, 'occupied');

      // 5. Invalidate Reception Providers
      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Walk-In Activated! Room $roomNumber assigned to $fName $lName.'),
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
                  Text('2. Room & Tariff', style: AppTypography.labelLarge),
                  AppSpacing.gapV12,
                  roomsAsync.when(
                    data: (rooms) {
                      final vacantRooms = rooms.where((r) {
                        final isBooked = r['is_booked'] == true;
                        final status = (r['status'] as String? ?? '').toUpperCase();
                        return !isBooked && (status != 'OCCUPIED' && status != 'MAINTENANCE');
                      }).toList();

                      return DropdownButtonFormField<String>(
                        value: _selectedRoom != null
                            ? (_selectedRoom!['room_id'] ?? _selectedRoom!['id']).toString()
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Available Room',
                          prefixIcon: Icon(Icons.meeting_room_outlined, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          final chosen = vacantRooms.firstWhere((r) => (r['room_id'] ?? r['id']).toString() == val);
                          setState(() {
                            _selectedRoom = chosen;
                            final price = chosen['base_price'] ?? chosen['price_per_night'] ?? 2500;
                            _tariffController.text = price.toString();
                          });
                        },
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
