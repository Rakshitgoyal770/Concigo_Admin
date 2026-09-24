import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import 'activate_upcoming_stay_modal.dart';
import 'create_upcoming_booking_dialog.dart';

enum ArrivalDateFilter {
  all,
  today,
  tomorrow,
  next7Days,
  custom,
}

class UpcomingArrivalsList extends ConsumerStatefulWidget {
  const UpcomingArrivalsList({super.key});

  @override
  ConsumerState<UpcomingArrivalsList> createState() => _UpcomingArrivalsListState();
}

class _UpcomingArrivalsListState extends ConsumerState<UpcomingArrivalsList> {
  ArrivalDateFilter _selectedFilter = ArrivalDateFilter.all;
  DateTime? _customDate;

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    final str = val.toString().trim();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickCustomDate(BuildContext context, DateTime initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? initialDate,
      firstDate: initialDate.subtract(const Duration(days: 30)),
      lastDate: initialDate.add(const Duration(days: 365)),
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
        _customDate = picked;
        _selectedFilter = ArrivalDateFilter.custom;
      });
    }
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.roundedSm,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
          boxShadow: isSelected ? const [AppColors.shadowSm] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
            if (count >= 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingAsync = ref.watch(upcomingStaysProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final next7DaysEnd = today.add(const Duration(days: 7));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return LuxuryCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: AppSpacing.roundedMd,
                    ),
                    child: const Icon(Icons.flight_land_rounded, size: 18, color: AppColors.info),
                  ),
                  AppSpacing.gapH12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upcoming Arrivals & Bookings', style: AppTypography.titleSmall),
                        Text('Scheduled arrivals with pre-bookings & app check-ins', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  if (!isMobile)
                    LuxuryButton(
                      text: '+ New Booking',
                      variant: LuxuryButtonVariant.outline,
                      icon: Icons.add_circle_outline_rounded,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CreateUpcomingBookingDialog(),
                        );
                      },
                    ),
                ],
              ),
              if (isMobile) ...[
                AppSpacing.gapV12,
                LuxuryButton(
                  text: '+ New Booking',
                  variant: LuxuryButtonVariant.outline,
                  icon: Icons.add_circle_outline_rounded,
                  isExpanded: true,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const CreateUpcomingBookingDialog(),
                    );
                  },
                ),
              ],
              AppSpacing.gapV16,

              upcomingAsync.when(
                data: (allStays) {
                  if (allStays.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.event_available_outlined, size: 40, color: AppColors.textMuted),
                            AppSpacing.gapV8,
                            Text('No pending scheduled arrivals', style: AppTypography.titleSmall),
                            AppSpacing.gapV4,
                            Text('Create a scheduled reservation or walk-in above.', style: AppTypography.bodySmall),
                            AppSpacing.gapV12,
                            LuxuryButton(
                              text: '+ Create Upcoming Reservation',
                              variant: LuxuryButtonVariant.secondary,
                              icon: Icons.calendar_month_rounded,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const CreateUpcomingBookingDialog(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Compute category counts
                  int todayCount = 0;
                  int tomorrowCount = 0;
                  int next7DaysCount = 0;

                  for (final s in allStays) {
                    final d = _parseDate(s['check_in_date']);
                    if (d == null) continue;
                    final day = DateTime(d.year, d.month, d.day);
                    if (_isSameDay(day, today) || day.isBefore(today)) {
                      todayCount++;
                    }
                    if (_isSameDay(day, tomorrow)) {
                      tomorrowCount++;
                    }
                    if (!day.isBefore(today) && day.isBefore(next7DaysEnd)) {
                      next7DaysCount++;
                    }
                  }

                  // Filter stays based on selected filter
                  final filteredStays = allStays.where((s) {
                    final d = _parseDate(s['check_in_date']);
                    if (d == null) return _selectedFilter == ArrivalDateFilter.all;
                    final day = DateTime(d.year, d.month, d.day);

                    switch (_selectedFilter) {
                      case ArrivalDateFilter.today:
                        return _isSameDay(day, today) || day.isBefore(today);
                      case ArrivalDateFilter.tomorrow:
                        return _isSameDay(day, tomorrow);
                      case ArrivalDateFilter.next7Days:
                        return !day.isBefore(today) && day.isBefore(next7DaysEnd);
                      case ArrivalDateFilter.custom:
                        if (_customDate == null) return true;
                        return _isSameDay(day, _customDate!);
                      case ArrivalDateFilter.all:
                        return true;
                    }
                  }).toList();

                  final customDateLabel = _customDate != null
                      ? DateFormat('d MMM yyyy').format(_customDate!)
                      : 'Pick Date';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── DATE FILTER BAR ──────────────────────────────────────
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'All Arrivals',
                              count: allStays.length,
                              isSelected: _selectedFilter == ArrivalDateFilter.all,
                              onTap: () => setState(() => _selectedFilter = ArrivalDateFilter.all),
                            ),
                            AppSpacing.gapH8,
                            _buildFilterChip(
                              label: 'Today',
                              count: todayCount,
                              icon: Icons.today_rounded,
                              isSelected: _selectedFilter == ArrivalDateFilter.today,
                              onTap: () => setState(() => _selectedFilter = ArrivalDateFilter.today),
                            ),
                            AppSpacing.gapH8,
                            _buildFilterChip(
                              label: 'Tomorrow',
                              count: tomorrowCount,
                              icon: Icons.event_rounded,
                              isSelected: _selectedFilter == ArrivalDateFilter.tomorrow,
                              onTap: () => setState(() => _selectedFilter = ArrivalDateFilter.tomorrow),
                            ),
                            AppSpacing.gapH8,
                            _buildFilterChip(
                              label: 'Next 7 Days',
                              count: next7DaysCount,
                              icon: Icons.date_range_rounded,
                              isSelected: _selectedFilter == ArrivalDateFilter.next7Days,
                              onTap: () => setState(() => _selectedFilter = ArrivalDateFilter.next7Days),
                            ),
                            AppSpacing.gapH8,
                            _buildFilterChip(
                              label: customDateLabel,
                              count: -1,
                              icon: Icons.calendar_month_rounded,
                              isSelected: _selectedFilter == ArrivalDateFilter.custom,
                              onTap: () => _pickCustomDate(context, today),
                            ),
                            if (_selectedFilter == ArrivalDateFilter.custom && _customDate != null) ...[
                              AppSpacing.gapH4,
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                tooltip: 'Clear custom date',
                                onPressed: () {
                                  setState(() {
                                    _customDate = null;
                                    _selectedFilter = ArrivalDateFilter.all;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      AppSpacing.gapV16,

                      // Empty state for current filter
                      if (filteredStays.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.event_busy_outlined, size: 36, color: AppColors.textMuted),
                                AppSpacing.gapV8,
                                Text(
                                  _selectedFilter == ArrivalDateFilter.today
                                      ? 'No arrivals scheduled for today'
                                      : (_selectedFilter == ArrivalDateFilter.tomorrow
                                          ? 'No arrivals scheduled for tomorrow'
                                          : (_selectedFilter == ArrivalDateFilter.next7Days
                                              ? 'No arrivals scheduled in the next 7 days'
                                              : 'No arrivals match the selected date')),
                                  style: AppTypography.titleSmall,
                                ),
                                AppSpacing.gapV4,
                                Text('Switch to "All Arrivals" to see future bookings.', style: AppTypography.bodySmall),
                                AppSpacing.gapV12,
                                LuxuryButton(
                                  text: 'View All Arrivals (${allStays.length})',
                                  variant: LuxuryButtonVariant.secondary,
                                  onPressed: () => setState(() => _selectedFilter = ArrivalDateFilter.all),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        // Stays List
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredStays.length,
                          separatorBuilder: (_, __) => AppSpacing.gapV12,
                          itemBuilder: (context, index) {
                            final stay = filteredStays[index];
                            final guestName = (stay['guest_name'] ?? stay['user_name'] ?? 'Guest').toString();
                            final phone = (stay['phone_number'] ?? stay['phone'] ?? stay['mobile_no'] ?? '').toString();
                            final roomNum = (stay['room_number'] ?? stay['room_no'] ?? 'Unassigned').toString();
                            final roomLabel = roomNum.contains(',')
                                ? 'Rooms $roomNum'
                                : (roomNum.toLowerCase().startsWith('room') || roomNum.toLowerCase() == 'unassigned'
                                    ? roomNum
                                    : 'Room $roomNum');
                            final isKycDone = stay['is_kyc_verified'] == true || stay['kyc_status'] == 'APPROVED';

                            // ── ARRIVAL DATE BADGE CALCULATION ────────────────
                            final checkIn = _parseDate(stay['check_in_date']);
                            final checkOut = _parseDate(stay['check_out_date']);

                            String arrivalBadgeLabel = 'Date: —';
                            LuxuryBadgeVariant arrivalVariant = LuxuryBadgeVariant.neutral;
                            IconData arrivalIcon = Icons.calendar_today_rounded;

                            if (checkIn != null) {
                              final day = DateTime(checkIn.year, checkIn.month, checkIn.day);
                              final isTodayArrival = _isSameDay(day, today) || day.isBefore(today);
                              final isTomorrowArrival = _isSameDay(day, tomorrow);
                              final dateFormatted = DateFormat('d MMM yyyy').format(checkIn);

                              if (isTodayArrival) {
                                arrivalBadgeLabel = 'Today, $dateFormatted';
                                arrivalVariant = LuxuryBadgeVariant.attention;
                                arrivalIcon = Icons.today_rounded;
                              } else if (isTomorrowArrival) {
                                arrivalBadgeLabel = 'Tomorrow, $dateFormatted';
                                arrivalVariant = LuxuryBadgeVariant.info;
                                arrivalIcon = Icons.event_rounded;
                              } else {
                                arrivalBadgeLabel = dateFormatted;
                                arrivalVariant = LuxuryBadgeVariant.neutral;
                                arrivalIcon = Icons.calendar_month_outlined;
                              }
                            }

                            // Stay duration text
                            String durationText = '';
                            if (checkIn != null && checkOut != null) {
                              final nights = checkOut.difference(checkIn).inDays;
                              final inFmt = DateFormat('d MMM').format(checkIn);
                              final outFmt = DateFormat('d MMM').format(checkOut);
                              durationText = '$inFmt – $outFmt (${nights > 0 ? "$nights ${nights == 1 ? 'night' : 'nights'}" : "1 night"})';
                            }

                            final subtitleParts = [
                              if (phone.isNotEmpty && phone != '—') phone,
                              if (durationText.isNotEmpty) durationText,
                              'Online Booking',
                            ];

                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppSpacing.roundedMd,
                                border: Border.all(
                                  color: isKycDone
                                      ? AppColors.successBorder.withValues(alpha: 0.4)
                                      : AppColors.border,
                                ),
                                boxShadow: const [AppColors.shadowSm],
                              ),
                              child: LayoutBuilder(
                                builder: (context, rowConstraints) {
                                  final isRowNarrow = rowConstraints.maxWidth < 640;

                                  if (isRowNarrow) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceSubtle,
                                                borderRadius: AppSpacing.roundedSm,
                                                border: Border.all(color: AppColors.border),
                                              ),
                                              child: Text(
                                                roomLabel,
                                                style: AppTypography.monoRoom.copyWith(fontSize: 12),
                                              ),
                                            ),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              alignment: WrapAlignment.end,
                                              children: [
                                                LuxuryBadge(
                                                  label: arrivalBadgeLabel,
                                                  variant: arrivalVariant,
                                                  icon: arrivalIcon,
                                                  isSmall: true,
                                                ),
                                                LuxuryBadge(
                                                  label: isKycDone ? 'KYC Done' : 'KYC Pending',
                                                  variant: isKycDone
                                                      ? LuxuryBadgeVariant.success
                                                      : LuxuryBadgeVariant.attention,
                                                  isSmall: true,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        AppSpacing.gapV8,
                                        Text(
                                          guestName,
                                          style: AppTypography.labelLarge,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        AppSpacing.gapV4,
                                        Text(
                                          subtitleParts.join(' • '),
                                          style: AppTypography.bodySmall,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        AppSpacing.gapV12,
                                        LuxuryButton(
                                          text: 'Activate Check-In',
                                          variant: LuxuryButtonVariant.primary,
                                          isExpanded: true,
                                          height: 34,
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => ActivateUpcomingStayModal(stay: stay),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceSubtle,
                                          borderRadius: AppSpacing.roundedSm,
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text(
                                          roomLabel,
                                          style: AppTypography.monoRoom.copyWith(fontSize: 13),
                                        ),
                                      ),
                                      AppSpacing.gapH12,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              guestName,
                                              style: AppTypography.labelLarge,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            AppSpacing.gapV4,
                                            Text(
                                              subtitleParts.join(' • '),
                                              style: AppTypography.bodySmall,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      AppSpacing.gapH12,
                                      LuxuryBadge(
                                        label: arrivalBadgeLabel,
                                        variant: arrivalVariant,
                                        icon: arrivalIcon,
                                        isSmall: false,
                                      ),
                                      AppSpacing.gapH8,
                                      LuxuryBadge(
                                        label: isKycDone ? 'KYC Verified' : 'KYC Pending',
                                        variant: isKycDone
                                            ? LuxuryBadgeVariant.success
                                            : LuxuryBadgeVariant.attention,
                                        isSmall: false,
                                      ),
                                      AppSpacing.gapH12,
                                      LuxuryButton(
                                        text: 'Activate Check-In',
                                        variant: LuxuryButtonVariant.primary,
                                        height: 34,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => ActivateUpcomingStayModal(stay: stay),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Text(
                  'Failed to load arrivals: $err',
                  style: const TextStyle(color: AppColors.departure),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
