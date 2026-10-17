import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../data/providers/supabase_providers.dart';

class LiveRoomMatrix extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic> room)? onRoomSelected;
  final Function(Map<String, dynamic> room)? onWalkInForRoom;

  const LiveRoomMatrix({
    super.key,
    this.onRoomSelected,
    this.onWalkInForRoom,
  });

  @override
  ConsumerState<LiveRoomMatrix> createState() => _LiveRoomMatrixState();
}

class _LiveRoomMatrixState extends ConsumerState<LiveRoomMatrix> {
  String _statusFilter = 'ALL';
  String _floorFilter = 'ALL';
  String _typeFilter = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getRoomFloor(Map<String, dynamic> r) {
    final explicitFloor = r['floor']?.toString().trim();
    if (explicitFloor != null && explicitFloor.isNotEmpty && explicitFloor != 'null') {
      final digits = explicitFloor.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) return 'Floor $digits';
      return explicitFloor;
    }
    final roomNum = (r['room_number'] ?? r['room_no'] ?? '').toString().trim();
    if (roomNum.length >= 3 && int.tryParse(roomNum) != null) {
      return 'Floor ${roomNum.substring(0, roomNum.length - 2)}';
    }
    return 'Floor 1';
  }

  String _getRoomType(Map<String, dynamic> r) {
    final t = (r['type'] ?? r['room_type'] ?? r['category'] ?? 'Standard').toString().trim();
    return t.isEmpty ? 'Standard' : t;
  }

  String _getCatAbbr(String category) {
    final catUpper = category.toUpperCase().trim();
    if (catUpper.contains('SINGLE')) return 'SGL';
    if (catUpper.contains('DOUBLE')) return 'DBL';
    if (catUpper.contains('TWIN')) return 'TWN';
    if (catUpper.contains('DELUXE')) return 'DLX';
    if (catUpper.contains('SUITE')) return 'SUI';
    if (catUpper.contains('KING')) return 'KNG';
    if (catUpper.contains('QUEEN')) return 'QUN';
    if (catUpper.contains('SUPERIOR')) return 'SUP';
    if (catUpper.contains('STANDARD')) return 'STD';
    if (catUpper.contains('EXECUTIVE')) return 'EXEC';
    if (catUpper.contains('FAMILY')) return 'FAM';
    if (catUpper.contains('VILLA')) return 'VIL';
    if (catUpper.contains('PENTHOUSE')) return 'PNT';
    return catUpper.length > 4 ? catUpper.substring(0, 4) : catUpper;
  }

  void _clearAllFilters() {
    setState(() {
      _statusFilter = 'ALL';
      _floorFilter = 'ALL';
      _typeFilter = 'ALL';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  bool get _hasActiveFilters =>
      _statusFilter != 'ALL' ||
      _floorFilter != 'ALL' ||
      _typeFilter != 'ALL' ||
      _searchQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(receptionRoomsProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: const [AppColors.shadowSm],
      ),
      child: roomsAsync.when(
        data: (rooms) {
          // Compute status counts
          final totalCount = rooms.length;
          final vacantCount = rooms.where((r) {
            final isBooked = r['is_booked'] == true;
            final st = (r['status'] as String? ?? (isBooked ? 'OCCUPIED' : 'VACANT')).toUpperCase();
            return !isBooked && (st == 'VACANT' || st == 'AVAILABLE');
          }).length;
          final occupiedCount = rooms.where((r) {
            final isBooked = r['is_booked'] == true;
            final st = (r['status'] as String? ?? (isBooked ? 'OCCUPIED' : 'VACANT')).toUpperCase();
            return isBooked || st == 'OCCUPIED';
          }).length;
          final cleaningCount = rooms.where((r) {
            final st = (r['status'] as String? ?? '').toUpperCase();
            return st == 'CLEANING' || st == 'NEEDS CLEANING';
          }).length;
          final maintCount = rooms.where((r) {
            final st = (r['status'] as String? ?? '').toUpperCase();
            return st == 'MAINTENANCE';
          }).length;

          // Extract distinct floors and room types
          final floorsSet = <String>{};
          final typesSet = <String>{};
          for (final r in rooms) {
            floorsSet.add(_getRoomFloor(r));
            typesSet.add(_getRoomType(r));
          }
          final sortedFloors = floorsSet.toList()..sort((a, b) {
            final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            return numA.compareTo(numB);
          });
          final sortedTypes = typesSet.toList()..sort();

          // Filter rooms
          final filtered = rooms.where((r) {
            final roomNum = (r['room_number'] ?? r['room_no'] ?? '').toString();
            final guestName = (r['guest_name'] ?? r['user_name'] ?? '').toString();
            final isBooked = r['is_booked'] == true;
            final rawStatus = (r['status'] as String? ?? (isBooked ? 'OCCUPIED' : 'VACANT')).toUpperCase();
            final status = isBooked ? 'OCCUPIED' : rawStatus;
            final floor = _getRoomFloor(r);
            final type = _getRoomType(r);

            // Search query (room # or guest name)
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              if (!roomNum.toLowerCase().contains(q) && !guestName.toLowerCase().contains(q)) {
                return false;
              }
            }

            // Status filter
            if (_statusFilter == 'VACANT' && status != 'VACANT' && status != 'AVAILABLE') return false;
            if (_statusFilter == 'OCCUPIED' && status != 'OCCUPIED') return false;
            if (_statusFilter == 'CLEANING' && status != 'CLEANING' && status != 'NEEDS CLEANING') return false;
            if (_statusFilter == 'MAINTENANCE' && status != 'MAINTENANCE') return false;

            // Floor filter
            if (_floorFilter != 'ALL' && floor != _floorFilter) return false;

            // Type filter
            if (_typeFilter != 'ALL' && type.toLowerCase() != _typeFilter.toLowerCase()) return false;

            return true;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header + Search Toolbar
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isCompact = headerConstraints.maxWidth < 650;

                  return Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Room Inventory & Status Matrix',
                            style: AppTypography.titleSmall.copyWith(
                              fontSize: isCompact ? 13 : 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalCount Rooms',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: isCompact ? 140 : 210,
                        height: 32,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontSize: 11),
                          decoration: InputDecoration(
                            hintText: 'Search room # or guest...',
                            hintStyle: AppTypography.caption.copyWith(fontSize: 10.5),
                            prefixIcon: const Icon(LucideIcons.search, size: 14, color: AppColors.textMuted),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(LucideIcons.x, size: 12),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.surfaceSubtle,
                            border: OutlineInputBorder(
                              borderRadius: AppSpacing.roundedSm,
                              borderSide: const BorderSide(color: AppColors.border, width: 0.8),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: AppSpacing.roundedSm,
                              borderSide: const BorderSide(color: AppColors.border, width: 0.8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),

              // 2. Primary Status Filter Pills (with Live Counts)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterButton('ALL', 'All Rooms', count: totalCount),
                    const SizedBox(width: 6),
                    _buildFilterButton('VACANT', 'Vacant', count: vacantCount, dotColor: AppColors.success),
                    const SizedBox(width: 6),
                    _buildFilterButton('OCCUPIED', 'Occupied', count: occupiedCount, dotColor: AppColors.primary),
                    const SizedBox(width: 6),
                    _buildFilterButton('CLEANING', 'Cleaning', count: cleaningCount, dotColor: AppColors.attention),
                    const SizedBox(width: 6),
                    _buildFilterButton('MAINTENANCE', 'Out of Order', count: maintCount, dotColor: AppColors.departure),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Secondary Multi-Filters: Floor + Room Type (Singles, Doubles, Suites) + Reset
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Floor Selector Dropdown
                  _buildDropdownFilter(
                    icon: LucideIcons.layers,
                    label: 'Floor',
                    value: _floorFilter,
                    items: ['ALL', ...sortedFloors],
                    itemLabel: (f) {
                      if (f == 'ALL') return 'All Floors';
                      final count = rooms.where((r) => _getRoomFloor(r) == f).length;
                      return '$f ($count)';
                    },
                    onChanged: (val) => setState(() => _floorFilter = val),
                  ),

                  // Room Type / Bed Category Selector Dropdown
                  _buildDropdownFilter(
                    icon: LucideIcons.bedDouble,
                    label: 'Bed / Type',
                    value: _typeFilter,
                    items: ['ALL', ...sortedTypes],
                    itemLabel: (t) {
                      if (t == 'ALL') return 'All Room Types';
                      final count = rooms.where((r) => _getRoomType(r).toLowerCase() == t.toLowerCase()).length;
                      return '$t ($count)';
                    },
                    onChanged: (val) => setState(() => _typeFilter = val),
                  ),

                  // Reset Filters Action Chip
                  if (_hasActiveFilters)
                    InkWell(
                      onTap: _clearAllFilters,
                      borderRadius: AppSpacing.roundedSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
                        decoration: BoxDecoration(
                          color: AppColors.departureLight,
                          borderRadius: AppSpacing.roundedSm,
                          border: Border.all(color: AppColors.departureBorder, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.x, size: 12, color: AppColors.departure),
                            const SizedBox(width: 4),
                            Text(
                              'Reset Filters',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.departure,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Active Filter Counter Summary
                  if (_hasActiveFilters)
                    Text(
                      'Showing ${filtered.length} of $totalCount rooms',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Room Matrix Grid
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.searchX, size: 36, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'No rooms match your filter criteria',
                          style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting floor, room category or status filters',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _clearAllFilters,
                          icon: const Icon(LucideIcons.rotateCcw, size: 14),
                          label: const Text('Clear All Filters'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobileWidth = constraints.maxWidth < 550;
                    final int crossAxisCount = isMobileWidth
                        ? (constraints.maxWidth / 90).floor().clamp(3, 4)
                        : (constraints.maxWidth / 110).floor().clamp(4, 10);
                    final double childAspectRatio = isMobileWidth ? 1.18 : 1.25;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final room = filtered[index];
                        return _buildRoomTile(room);
                      },
                    );
                  },
                ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text('Unable to load rooms: $err', style: const TextStyle(color: AppColors.departure)),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
    required IconData icon,
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) itemLabel,
    required ValueChanged<String> onChanged,
  }) {
    final isFiltered = value != 'ALL';

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isFiltered ? AppColors.primaryLight : AppColors.surfaceSubtle,
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(
          color: isFiltered ? AppColors.primary : AppColors.border,
          width: isFiltered ? 1.2 : 0.8,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : 'ALL',
          icon: Icon(
            LucideIcons.chevronDown,
            size: 13,
            color: isFiltered ? AppColors.primary : AppColors.textSecondary,
          ),
          isDense: true,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isFiltered ? FontWeight.w700 : FontWeight.w500,
            color: isFiltered ? AppColors.primary : AppColors.textSecondary,
          ),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 12, color: isFiltered ? AppColors.primary : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(itemLabel(item)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterButton(String key, String label, {int? count, Color? dotColor}) {
    final isSelected = _statusFilter == key;

    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: AppSpacing.roundedSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11.5,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// High-Density Room Tile — uniform border, 4px left status bar, monospace room number, category tag, popup actions
  Widget _buildRoomTile(Map<String, dynamic> room) {
    final roomId = (room['room_id'] ?? room['id'] ?? '').toString();
    final roomNum = (room['room_number'] ?? room['room_no'] ?? '').toString();
    final category = _getRoomType(room);
    final isBooked = room['is_booked'] == true;
    final rawStatus = (room['status'] as String? ?? (isBooked ? 'OCCUPIED' : 'VACANT')).toUpperCase();
    final status = isBooked ? 'OCCUPIED' : rawStatus;

    Color statusColor;
    String statusLabel;

    if (status == 'OCCUPIED') {
      statusColor = AppColors.primary;
      statusLabel = 'Occupied';
    } else if (status == 'CLEANING' || status == 'NEEDS CLEANING') {
      statusColor = AppColors.attention;
      statusLabel = 'Cleaning';
    } else if (status == 'MAINTENANCE') {
      statusColor = AppColors.departure;
      statusLabel = 'Maint.';
    } else {
      statusColor = AppColors.success;
      statusLabel = 'Vacant';
    }

    final isVacant = status == 'VACANT' || status == 'AVAILABLE';
    final catAbbr = _getCatAbbr(category);
    final guestName = (room['guest_name'] ?? room['user_name'] ?? '').toString().trim();
    final String subText = isVacant
        ? 'Ready'
        : (guestName.isNotEmpty ? guestName.split(' ').first : statusLabel);

    return ClipRRect(
      borderRadius: AppSpacing.roundedSm,
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: () {
            if (isVacant && widget.onWalkInForRoom != null) {
              widget.onWalkInForRoom!(room);
            } else if (widget.onRoomSelected != null) {
              widget.onRoomSelected!(room);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppSpacing.roundedSm,
              border: Border.all(color: AppColors.border, width: 0.8),
            ),
            child: Stack(
              children: [
                // Left 4px vertical status indicator bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: Container(color: statusColor),
                ),

                // Main content
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 5, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              roomNum,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              catAbbr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isVacant ? AppColors.success : statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    subText,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: isVacant ? FontWeight.w600 : FontWeight.w700,
                                      color: isVacant ? AppColors.success : statusColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: PopupMenuButton<String>(
                              tooltip: 'Update Status',
                              icon: const Icon(Icons.more_vert_rounded, size: 15, color: AppColors.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(maxWidth: 150),
                              onSelected: (newStatus) async {
                                await ref.read(roomServiceProvider).updateRoomStatus(roomId, newStatus);
                                ref.read(receptionRefreshSignalProvider.notifier).state++;
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'vacant', child: Text('Vacant')),
                                const PopupMenuItem(value: 'occupied', child: Text('Occupied')),
                                const PopupMenuItem(value: 'cleaning', child: Text('Cleaning')),
                                const PopupMenuItem(value: 'maintenance', child: Text('Maintenance')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
