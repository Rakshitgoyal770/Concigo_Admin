import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _searchQuery = '';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Compact Operational Search Toolbar
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isCompact = headerConstraints.maxWidth < 650;

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Room Inventory & Status Matrix',
                      style: AppTypography.titleSmall.copyWith(
                        fontSize: isCompact ? 13.5 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: isCompact ? 130 : 200,
                    height: 30,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: AppTypography.caption.copyWith(color: AppColors.textPrimary, fontSize: 11),
                      decoration: InputDecoration(
                        hintText: 'Filter #...',
                        hintStyle: AppTypography.caption.copyWith(fontSize: 10.5),
                        prefixIcon: const Icon(Icons.search, size: 14, color: AppColors.textMuted),
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
          const SizedBox(height: 8),

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton('ALL', 'All Rooms'),
                const SizedBox(width: 6),
                _buildFilterButton('VACANT', 'Vacant', dotColor: AppColors.success),
                const SizedBox(width: 6),
                _buildFilterButton('OCCUPIED', 'Occupied', dotColor: AppColors.primary),
                const SizedBox(width: 6),
                _buildFilterButton('CLEANING', 'Cleaning', dotColor: AppColors.attention),
                const SizedBox(width: 6),
                _buildFilterButton('MAINTENANCE', 'Out of Order', dotColor: AppColors.departure),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // High-Density Room Matrix Grid
          roomsAsync.when(
            data: (rooms) {
              final filtered = rooms.where((r) {
                final roomNum = (r['room_number'] ?? r['room_no'] ?? '').toString();
                final status = (r['status'] as String? ?? 'vacant').toUpperCase();

                if (_searchQuery.isNotEmpty && !roomNum.toLowerCase().contains(_searchQuery.toLowerCase())) {
                  return false;
                }

                if (_statusFilter == 'ALL') return true;
                if (_statusFilter == 'VACANT' && (status == 'VACANT' || status == 'AVAILABLE')) return true;
                if (_statusFilter == 'OCCUPIED' && status == 'OCCUPIED') return true;
                if (_statusFilter == 'CLEANING' && (status == 'CLEANING' || status == 'NEEDS CLEANING')) return true;
                if (_statusFilter == 'MAINTENANCE' && status == 'MAINTENANCE') return true;

                return false;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Text('No rooms matching criteria', style: AppTypography.bodySmall),
                  ),
                );
              }

              return LayoutBuilder(
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
                child: Text('Unable to load rooms: $err', style: TextStyle(color: AppColors.departure)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String key, String label, {Color? dotColor}) {
    final isSelected = _statusFilter == key;

    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: AppSpacing.roundedSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceSubtle : Colors.transparent,
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(
            color: isSelected ? const Color(0xFF0A1628) : AppColors.border,
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
                color: isSelected ? const Color(0xFF0A1628) : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// High-Density Room Tile — uniform border, 4px left status bar, monospace room number, category tag, popup actions
  Widget _buildRoomTile(Map<String, dynamic> room) {
    final roomId = (room['room_id'] ?? room['id'] ?? '').toString();
    final roomNum = (room['room_number'] ?? room['room_no'] ?? '').toString();
    final category = (room['type'] ?? room['room_type'] ?? room['category'] ?? 'Standard').toString();
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

    // Abbreviate category
    String catAbbr = category.toUpperCase();
    if (catAbbr.contains('DELUXE')) {
      catAbbr = 'DLX';
    } else if (catAbbr.contains('SUITE')) {
      catAbbr = 'SUI';
    } else if (catAbbr.contains('KING')) {
      catAbbr = 'KNG';
    } else if (catAbbr.contains('SUPERIOR')) {
      catAbbr = 'SUP';
    } else if (catAbbr.contains('STANDARD')) {
      catAbbr = 'STD';
    } else if (catAbbr.length > 4) {
      catAbbr = catAbbr.substring(0, 4);
    }

    final guestName = (room['guest_name'] ?? room['user_name'] ?? '').toString().trim();
    // Fix duplicate category bug: When vacant, display operational status 'Ready' rather than repeating catAbbr
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
