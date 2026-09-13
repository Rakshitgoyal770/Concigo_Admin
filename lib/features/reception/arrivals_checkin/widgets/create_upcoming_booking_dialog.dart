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
  String? _selectedRoomId;
  bool _isSearchingPhone = false;
  bool _isSubmitting = false;
  String? _errorMessage;

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
      });
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
        roomId: _selectedRoomId,
      );

      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Reservation created for $fullName! Added to Upcoming Arrivals queue.'),
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
            width: 540,
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
                              'Schedule guest booking & pre-reserve rooms',
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
                  Text('2. Stay Schedule & Room', style: AppTypography.labelLarge),
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
                  AppSpacing.gapV12,

                  roomsAsync.when(
                    data: (rooms) {
                      return DropdownButtonFormField<String?>(
                        value: _selectedRoomId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pre-Assign Room (Optional)',
                          prefixIcon: Icon(Icons.meeting_room_outlined, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Assign room at check-in (Recommended)'),
                          ),
                          ...rooms.map((r) {
                            final rId = (r['room_id'] ?? r['id']).toString();
                            final rNum = (r['room_number'] ?? r['room_no']).toString();
                            final rType = (r['type'] ?? r['room_type'] ?? r['category'] ?? 'Standard').toString();
                            return DropdownMenuItem<String?>(
                              value: rId,
                              child: Text('Room $rNum ($rType)', overflow: TextOverflow.ellipsis),
                            );
                          }),
                        ],
                        onChanged: (val) async {
                          if (val != null) {
                            final isAvail = await ref.read(stayServiceProvider).checkRoomAvailable(
                              roomId: val,
                              checkInDate: _checkInDate,
                              checkOutDate: _checkOutDate,
                            );
                            if (!isAvail && mounted) {
                              setState(() {
                                _errorMessage = 'Selected room is already booked for these dates. Please choose another room or assign at check-in.';
                                _selectedRoomId = null;
                              });
                              return;
                            }
                          }
                          setState(() {
                            _errorMessage = null;
                            _selectedRoomId = val;
                          });
                        },
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
