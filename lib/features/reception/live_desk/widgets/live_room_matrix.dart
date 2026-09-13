import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_badge.dart';
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: const [AppColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Operational Filter Toolbar
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final isCompact = headerConstraints.maxWidth < 650;

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room Inventory & Status Matrix', style: AppTypography.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Live room allocation, housekeeping and availability',
                      style: AppTypography.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapV12,
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Filter room #...',
                          hintStyle: AppTypography.caption,
                          prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Room Inventory & Status Matrix', style: AppTypography.titleSmall),
                        const SizedBox(height: 2),
                        Text('Live room allocation, housekeeping and availability', style: AppTypography.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 220,
                    height: 36,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Filter room #...',
                        hintStyle: AppTypography.caption,
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          AppSpacing.gapV16,

          // Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton('ALL', 'All Rooms'),
                AppSpacing.gapH8,
                _buildFilterButton('VACANT', 'Vacant', dotColor: AppColors.success),
                AppSpacing.gapH8,
                _buildFilterButton('OCCUPIED', 'Occupied', dotColor: AppColors.primary),
                AppSpacing.gapH8,
                _buildFilterButton('CLEANING', 'Cleaning Required', dotColor: AppColors.attention),
                AppSpacing.gapH8,
                _buildFilterButton('MAINTENANCE', 'Out of Order', dotColor: AppColors.departure),
              ],
            ),
          ),
          AppSpacing.gapV20,

          // Room Matrix Grid
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
                  final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(2, 8);
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.15,
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
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceSubtle : Colors.transparent,
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.0 : 0.8,
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
              style: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final roomId = (room['room_id'] ?? room['id'] ?? '').toString();
    final roomNum = (room['room_number'] ?? room['room_no'] ?? '').toString();
    final category = (room['type'] ?? room['room_type'] ?? room['category'] ?? 'Standard').toString();
    final isBooked = room['is_booked'] == true;
    final rawStatus = (room['status'] as String? ?? (isBooked ? 'OCCUPIED' : 'VACANT')).toUpperCase();
    final status = isBooked ? 'OCCUPIED' : rawStatus;

    LuxuryBadgeVariant badgeVariant;
    String statusLabel;

    if (status == 'OCCUPIED') {
      badgeVariant = LuxuryBadgeVariant.primary;
      statusLabel = 'Occupied';
    } else if (status == 'CLEANING' || status == 'NEEDS CLEANING') {
      badgeVariant = LuxuryBadgeVariant.attention;
      statusLabel = 'Cleaning';
    } else if (status == 'MAINTENANCE') {
      badgeVariant = LuxuryBadgeVariant.departure;
      statusLabel = 'Maint.';
    } else {
      badgeVariant = LuxuryBadgeVariant.success;
      statusLabel = 'Vacant';
    }

    final isVacant = status == 'VACANT' || status == 'AVAILABLE';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(
          color: AppColors.border,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                roomNum,
                style: AppTypography.monoRoom.copyWith(fontSize: 15),
              ),
              LuxuryBadge(
                label: statusLabel,
                variant: badgeVariant,
                isSmall: true,
              ),
            ],
          ),
          Text(
            category,
            style: AppTypography.caption.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Set Status',
                icon: const Icon(Icons.more_horiz, size: 16, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(maxWidth: 160),
                onSelected: (newStatus) async {
                  await ref.read(roomServiceProvider).updateRoomStatus(roomId, newStatus);
                  ref.read(receptionRefreshSignalProvider.notifier).state++;
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'vacant', child: Text('Set Vacant')),
                  const PopupMenuItem(value: 'occupied', child: Text('Set Occupied')),
                  const PopupMenuItem(value: 'cleaning', child: Text('Set Cleaning')),
                  const PopupMenuItem(value: 'maintenance', child: Text('Set Maintenance')),
                ],
              ),
              if (isVacant)
                InkWell(
                  onTap: () {
                    if (widget.onWalkInForRoom != null) {
                      widget.onWalkInForRoom!(room);
                    }
                  },
                  borderRadius: AppSpacing.roundedSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: Text(
                      '+ Walk-In',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
