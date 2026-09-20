import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../core/widgets/luxury_text_field.dart';
import '../../../../data/providers/supabase_providers.dart';
import '../../../../data/providers/reception_providers.dart';

class CreateUpcomingBookingDialog extends ConsumerStatefulWidget {
  const CreateUpcomingBookingDialog({super.key});

  @override
  ConsumerState<CreateUpcomingBookingDialog> createState() => _CreateUpcomingBookingDialogState();
}

class _CreateUpcomingBookingDialogState extends ConsumerState<CreateUpcomingBookingDialog> {
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime _checkInDate = DateTime.now();
  DateTime _checkOutDate = DateTime.now().add(const Duration(days: 1));
  final List<String> _selectedRoomIds = [];
  bool _isSearchingPhone = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool _showSpecificRooms = false;
  String _roomSearchQuery = '';
  String _selectedCategory = 'All';
  String _selectedFloor = 'All Floors';

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
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
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearchingPhone = false);
    }
  }

  Future<void> _selectDate({required bool isCheckIn}) async {
    final initial = isCheckIn ? _checkInDate : _checkOutDate;
    final firstDate = isCheckIn ? DateTime.now().subtract(const Duration(days: 1)) : _checkInDate;
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          if (_checkOutDate.isBefore(_checkInDate) || _checkOutDate.isAtSameMomentAs(_checkInDate)) {
            _checkOutDate = _checkInDate.add(const Duration(days: 1));
          }
        } else {
          _checkOutDate = picked;
        }
        // Clear selected rooms when dates change to re-validate availability
        _selectedRoomIds.clear();
      });
    }
  }

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

  int _countSelectedInCategory(String cat, List<Map<String, dynamic>> rooms) {
    return rooms.where((r) {
      final rId = (r['room_id'] ?? r['id']).toString();
      final rCat = _getCat(r);
      return rCat == cat && _selectedRoomIds.contains(rId);
    }).length;
  }

  Future<void> _incrementCategory(String cat, List<Map<String, dynamic>> rooms) async {
    final availableCandidates = rooms.where((r) {
      final rId = (r['room_id'] ?? r['id']).toString();
      final rCat = _getCat(r);
      return rCat == cat && !_selectedRoomIds.contains(rId);
    }).toList();

    if (availableCandidates.isEmpty) {
      setState(() => _errorMessage = 'All rooms in $cat category are currently selected.');
      return;
    }

    final candidate = availableCandidates.first;
    final rId = (candidate['room_id'] ?? candidate['id']).toString();

    final isAvail = await ref.read(stayServiceProvider).checkRoomAvailable(
      roomId: rId,
      checkInDate: _checkInDate,
      checkOutDate: _checkOutDate,
    );

    if (!isAvail && mounted) {
      setState(() {
        _errorMessage = 'No more available $cat rooms for the selected dates.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _errorMessage = null;
        _selectedRoomIds.add(rId);
      });
    }
  }

  void _decrementCategory(String cat, List<Map<String, dynamic>> rooms) {
    for (int i = _selectedRoomIds.length - 1; i >= 0; i--) {
      final rId = _selectedRoomIds[i];
      final match = rooms.firstWhere(
        (r) => (r['room_id'] ?? r['id']).toString() == rId,
        orElse: () => <String, dynamic>{},
      );
      if (match.isNotEmpty && _getCat(match) == cat) {
        setState(() {
          _selectedRoomIds.removeAt(i);
        });
        return;
      }
    }
  }

  Future<void> _submitReservation() async {
    final phone = _phoneController.text.trim();
    final fName = _firstNameController.text.trim();
    final lName = _lastNameController.text.trim();
    final fullName = '$fName $lName'.trim();

    if (phone.isEmpty || fName.isEmpty) {
      setState(() => _errorMessage = 'Please provide guest phone number and name.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final stayService = ref.read(stayServiceProvider);
      final propId = await ref.read(resolvedPropertyIdProvider.future);

      await stayService.createUpcomingStay(
        propertyId: propId,
        mobileNo: phone,
        guestName: fullName.isNotEmpty ? fullName : 'Guest',
        checkInDate: _checkInDate,
        checkOutDate: _checkOutDate,
        roomIds: _selectedRoomIds,
      );

      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        final roomCountLabel = _selectedRoomIds.isNotEmpty
            ? ' (${_selectedRoomIds.length} room${_selectedRoomIds.length > 1 ? "s" : ""})'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Reservation created for $fullName$roomCountLabel! Added to Upcoming queue.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to create booking: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(receptionRoomsProvider);
    final dateFormat = DateFormat('EEE, dd MMM yyyy');

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          return Container(
            width: 560,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.infoLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(Icons.event_note_rounded, color: AppColors.info, size: 20),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Upcoming Reservation',
                              style: AppTypography.titleMedium.copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Select room types & counts (assign physical keys at check-in)',
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

                  // Guest Identity Section
                  Text('1. Guest Details', style: AppTypography.labelLarge),
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

                  // Dates & Stay Schedule Section
                  Text('2. Stay Schedule & Room Types', style: AppTypography.labelLarge),
                  AppSpacing.gapV12,

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(isCheckIn: true),
                          borderRadius: AppSpacing.roundedMd,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Check-In Date', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        dateFormat.format(_checkInDate),
                                        style: AppTypography.labelMedium.copyWith(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(isCheckIn: false),
                          borderRadius: AppSpacing.roundedMd,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Check-Out Date', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.departure),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        dateFormat.format(_checkOutDate),
                                        style: AppTypography.labelMedium.copyWith(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapV16,

                  // Room Categories & Quantity Selection
                  roomsAsync.when(
                    data: (rooms) {
                      final distinctCategories = rooms.map(_getCat).toSet().toList();
                      final allCategories = ['All', ...distinctCategories];
                      final floors = ['All Floors', ...rooms.map(_getFloor).toSet()];

                      final selectedRoomsSummary = <String, int>{};
                      for (final rid in _selectedRoomIds) {
                        final match = rooms.firstWhere(
                          (r) => (r['room_id'] ?? r['id']).toString() == rid,
                          orElse: () => <String, dynamic>{},
                        );
                        if (match.isNotEmpty) {
                          final c = _getCat(match);
                          selectedRoomsSummary[c] = (selectedRoomsSummary[c] ?? 0) + 1;
                        }
                      }

                      final filteredRooms = rooms.where((r) {
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
                                        'Select Room Types & Quantity',
                                        style: AppTypography.labelMedium.copyWith(fontSize: 13),
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
                                    '${_selectedRoomIds.length} room${_selectedRoomIds.length > 1 ? "s" : ""} added',
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
                            'Choose how many rooms per type. Physical room numbers are assigned upon guest arrival.',
                            style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),

                          // Category Quantity Steppers List
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: distinctCategories.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderSubtle),
                              itemBuilder: (context, idx) {
                                final cat = distinctCategories[idx];
                                final catRooms = rooms.where((r) => _getCat(r) == cat).toList();
                                final totalInCat = catRooms.length;
                                final selectedCount = _countSelectedInCategory(cat, rooms);

                                final sampleRoom = catRooms.isNotEmpty ? catRooms.first : null;
                                final price = sampleRoom?['price'] ?? sampleRoom?['price_per_night'] ?? sampleRoom?['base_price'];
                                final priceText = price != null ? '₹$price / night • ' : '';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: selectedCount > 0 ? AppColors.primaryLight : AppColors.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: selectedCount > 0 ? AppColors.primary : AppColors.border,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.king_bed_outlined,
                                          size: 16,
                                          color: selectedCount > 0 ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat,
                                              style: AppTypography.labelMedium.copyWith(
                                                fontSize: 13,
                                                fontWeight: selectedCount > 0 ? FontWeight.w700 : FontWeight.w600,
                                                color: selectedCount > 0 ? AppColors.primary : AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$priceText$totalInCat total inventory',
                                              style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Quantity Stepper
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: selectedCount > 0
                                                ? () => _decrementCategory(cat, rooms)
                                                : null,
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: selectedCount > 0 ? AppColors.surface : AppColors.surfaceSubtle,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: selectedCount > 0 ? AppColors.border : AppColors.borderSubtle,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.remove,
                                                size: 14,
                                                color: selectedCount > 0 ? AppColors.textPrimary : AppColors.textMuted,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 38,
                                            alignment: Alignment.center,
                                            child: Text(
                                              '$selectedCount',
                                              style: AppTypography.titleSmall.copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: selectedCount > 0 ? AppColors.primary : AppColors.textMuted,
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: selectedCount < totalInCat
                                                ? () => _incrementCategory(cat, rooms)
                                                : null,
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: selectedCount < totalInCat ? AppColors.primary : AppColors.surfaceSubtle,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Icon(
                                                Icons.add,
                                                size: 14,
                                                color: selectedCount < totalInCat ? Colors.white : AppColors.textMuted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          // Summary of selection
                          if (_selectedRoomIds.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: AppSpacing.roundedMd,
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Reserved: ${selectedRoomsSummary.entries.map((e) => "${e.value}x ${e.key}").join(", ")}',
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
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
                                    child: const Text('Reset', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Optional Specific Room Picking Accordion
                          InkWell(
                            onTap: () => setState(() => _showSpecificRooms = !_showSpecificRooms),
                            borderRadius: AppSpacing.roundedMd,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _showSpecificRooms ? AppColors.surfaceSubtle : AppColors.surface,
                                borderRadius: AppSpacing.roundedMd,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _showSpecificRooms ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Custom Pick Specific Rooms (Optional)',
                                      style: AppTypography.labelMedium.copyWith(fontSize: 12, color: AppColors.textSecondary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_selectedRoomIds.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_selectedRoomIds.length} assigned',
                                      style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Expanded Specific Rooms View
                          if (_showSpecificRooms) ...[
                            const SizedBox(height: 8),
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
                                        hintText: 'Search room number (e.g. 101, 204, Suite)...',
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

                                  // Category & Floor Filter Chips
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ...allCategories.map((cat) {
                                          final isSel = _selectedCategory == cat;
                                          final count = cat == 'All'
                                              ? rooms.length
                                              : rooms.where((r) => _getCat(r) == cat).length;
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
                                  const SizedBox(height: 8),

                                  // Smart Room Cards Grid
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 180),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: AppSpacing.roundedMd,
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: filteredRooms.isEmpty
                                        ? Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Text(
                                                'No rooms match your filter.',
                                                style: AppTypography.bodySmall.copyWith(fontSize: 12, color: AppColors.textSecondary),
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
                                                final isSelected = _selectedRoomIds.contains(rId);

                                                return InkWell(
                                                  onTap: () async {
                                                    if (!isSelected) {
                                                      final isAvail = await ref.read(stayServiceProvider).checkRoomAvailable(
                                                        roomId: rId,
                                                        checkInDate: _checkInDate,
                                                        checkOutDate: _checkOutDate,
                                                      );
                                                      if (!isAvail && mounted) {
                                                        setState(() {
                                                          _errorMessage = 'Room $rNum is already booked for these dates.';
                                                        });
                                                        return;
                                                      }
                                                      setState(() {
                                                        _errorMessage = null;
                                                        _selectedRoomIds.add(rId);
                                                      });
                                                    } else {
                                                      setState(() {
                                                        _selectedRoomIds.remove(rId);
                                                      });
                                                    }
                                                  },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 150),
                                                    width: 95,
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? AppColors.primaryLight : AppColors.surfaceSubtle,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: isSelected ? AppColors.primary : AppColors.border,
                                                        width: isSelected ? 1.5 : 1,
                                                      ),
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
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w700,
                                                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                                              ),
                                                            ),
                                                            Icon(
                                                              isSelected ? Icons.check_circle : Icons.bed_outlined,
                                                              size: 12,
                                                              color: isSelected ? AppColors.primary : AppColors.textMuted,
                                                            ),
                                                          ],
                                                        ),
                                                        Text(
                                                          rType,
                                                          style: AppTypography.bodySmall.copyWith(
                                                            fontSize: 9,
                                                            color: AppColors.textSecondary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
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
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error loading rooms: $e'),
                  ),
                  AppSpacing.gapV24,

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
                        text: 'Save Reservation',
                        variant: LuxuryButtonVariant.primary,
                        icon: Icons.check,
                        height: 38,
                        isLoading: _isSubmitting,
                        onPressed: _submitReservation,
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
