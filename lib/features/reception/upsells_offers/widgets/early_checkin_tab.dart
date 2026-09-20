import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../services/supabase_service.dart';
import 'create_early_checkin_dialog.dart';

class EarlyCheckinTab extends ConsumerStatefulWidget {
  const EarlyCheckinTab({super.key});

  @override
  ConsumerState<EarlyCheckinTab> createState() => _EarlyCheckinTabState();
}

class _EarlyCheckinTabState extends ConsumerState<EarlyCheckinTab> {
  // Local cache for optimistic switch updates without flicker
  final Map<String, bool> _localActiveStatus = {};

  void _showEditOfferDialog(
    BuildContext context,
    String propId,
    String category,
    double currentPrice,
    int? currentLimit,
    int totalRooms,
    bool isActive,
  ) {
    final priceController = TextEditingController(text: currentPrice.toStringAsFixed(0));
    final limitController = TextEditingController(text: currentLimit != null ? '$currentLimit' : '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Early Check-In Offer', style: AppTypography.titleMedium),
                        Text('Configure rate & maximum pass capacity for $category', style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Price per Room / Hour (₹)', style: AppTypography.labelMedium),
              const SizedBox(height: 6),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '500',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                ),
              ),
              const SizedBox(height: 16),
              Text('Maximum Quantity of Offers (Pass Limit)', style: AppTypography.labelMedium),
              const SizedBox(height: 6),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'e.g. 4 (Leave blank for unlimited)',
                  helperText: 'Max early arrival passes guests can book for $category. e.g. set 4 so no more than 4 passes can be booked.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: AppColors.surfaceSubtle,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                      onPressed: () async {
                        final newPrice = double.tryParse(priceController.text.trim()) ?? currentPrice;
                        final limitText = limitController.text.trim();
                        final newLimit = limitText.isNotEmpty ? int.tryParse(limitText) : null;

                        Navigator.of(ctx).pop();
                        try {
                          await SupabaseService.instance.upsertCategoryEarlyLateOffer(
                            propertyId: propId,
                            type: 'early_in',
                            category: category,
                            price: newPrice,
                            limit: newLimit,
                            isActive: isActive,
                          );
                          ref.invalidate(earlyCheckinOffersProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.primary,
                                content: Text('Updated $category Early Check-In: ₹${newPrice.toStringAsFixed(0)}/room${newLimit != null ? ' (Max $newLimit)' : ' (Unlimited)'}'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.departure,
                                content: Text('Error updating offer: $e'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResetOfferClaims(
    BuildContext context,
    String propId,
    String category,
    String? offerId,
    int? limit,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restart_alt_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            Text('Reset Offer Claims', style: AppTypography.titleMedium),
          ],
        ),
        content: Text(
          'Are you sure you want to reset the claimed passes quota for "$category"?\n\nThis starts a fresh quota batch (0 / ${limit != null ? limit.toString() : 'Unlimited'} claimed) so upcoming guests can purchase early check-in passes again without deleting any past guest billing records.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (offerId != null && offerId.isNotEmpty) {
                await SupabaseService.instance.resetEarlyLateOfferClaims(offerId);
              } else {
                await SupabaseService.instance.upsertCategoryEarlyLateOffer(
                  propertyId: propId,
                  type: 'early_in',
                  category: category,
                  price: 500,
                  limit: limit,
                  isActive: true,
                );
              }
              ref.invalidate(earlyCheckinOffersProvider);
              ref.invalidate(earlyLateAcceptsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text('Claimed passes for "$category" reset to 0.'),
                  ),
                );
              }
            },
            child: const Text('Reset Quota', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOffer(
    BuildContext context,
    String propId,
    String category,
    String? offerId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.departure, size: 22),
            const SizedBox(width: 8),
            Text('Delete Offer', style: AppTypography.titleMedium),
          ],
        ),
        content: Text(
          'Are you sure you want to delete the Early Check-In offer for "$category"?\n\nGuests with this room type will no longer receive early arrival offers until re-enabled.',
          style: AppTypography.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.departure),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() {
                _localActiveStatus[category] = false;
              });
              if (offerId != null && offerId.isNotEmpty) {
                await SupabaseService.instance.deleteEarlyLateOffer(offerId);
              } else {
                await SupabaseService.instance.deleteCategoryEarlyLateOffer(
                  propertyId: propId,
                  type: 'early_in',
                  category: category,
                );
              }
              ref.invalidate(earlyCheckinOffersProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.departure,
                    content: Text('Early Check-In offer for "$category" deleted.'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final propertyIdAsync = ref.watch(resolvedPropertyIdProvider);
    final roomsAsync = ref.watch(receptionRoomsProvider);
    final offersAsync = ref.watch(earlyCheckinOffersProvider);
    final acceptsAsync = ref.watch(earlyLateAcceptsProvider);

    return propertyIdAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: AppTypography.bodySmall)),
      data: (propId) {
        final rooms = roomsAsync.valueOrNull ?? [];
        final offers = offersAsync.valueOrNull ?? [];
        final accepts = (acceptsAsync.valueOrNull ?? [])
            .where((a) => (a['type']?.toString().toLowerCase().contains('early') ?? false) || a['type'] == 'early_in')
            .toList();

        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 768;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Room Type Early Check-In Rates & Toggles', style: AppTypography.titleMedium),
                            AppSpacing.gapV4,
                            Text(
                              'Enable early arrival pass and set pricing per room category',
                              style: AppTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 16),
                        LuxuryButton(
                          text: '+ Create Offer',
                          variant: LuxuryButtonVariant.outline,
                          height: 36,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const CreateEarlyCheckinDialog(),
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
              AppSpacing.gapV16,

              // Room Type Tiered Cards
              if (roomsAsync.isLoading && rooms.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No room categories found for this property.'),
                )
              else
                Builder(
                  builder: (context) {
                    final distinctCategories = rooms
                        .map((r) => (r['type'] ?? r['room_type'] ?? r['category'] ?? 'Standard').toString())
                        .toSet()
                        .toList();

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: distinctCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final cat = distinctCategories[index];
                        final catRooms = rooms
                            .where((r) => (r['type'] ?? r['room_type'] ?? r['category'] ?? 'Standard').toString() == cat)
                            .toList();

                        final catLower = cat.toLowerCase().trim();
                        final matchingOffer = offers.firstWhere(
                          (o) {
                            final name = (o['offer_name'] ?? '').toString().trim();
                            final match = RegExp(r'^\[(.*?)\]').firstMatch(name);
                            if (match != null) {
                              return match.group(1)?.trim().toLowerCase() == catLower;
                            }
                            return name.toLowerCase() == catLower;
                          },
                          orElse: () => <String, dynamic>{},
                        );

                        final offerId = matchingOffer['offer_id']?.toString() ?? matchingOffer['id']?.toString();
                        final dbActive = matchingOffer.isNotEmpty && (matchingOffer['status'] == 'active');
                        final isActive = _localActiveStatus[cat] ?? dbActive;

                        final price = matchingOffer.isNotEmpty
                            ? (double.tryParse(matchingOffer['price_per_hour']?.toString() ?? '500') ?? 500.0)
                            : 500.0;

                        final limit = (matchingOffer['limit'] as num?)?.toInt();

                        // Count claimed passes for this category (only accepts within the current cycle)
                        final offerUpdatedAtStr = matchingOffer['updated_at']?.toString() ?? matchingOffer['created_at']?.toString();
                        final offerCycleStart = offerUpdatedAtStr != null ? DateTime.tryParse(offerUpdatedAtStr)?.toUtc() : null;

                        int claimedPasses = 0;
                        if (offerId != null && offerId.isNotEmpty) {
                          for (final a in accepts) {
                            if (a['offer_id'] == offerId) {
                              if (offerCycleStart != null) {
                                final acceptCreatedAtStr = a['created_at']?.toString();
                                final acceptCreatedAt = acceptCreatedAtStr != null ? DateTime.tryParse(acceptCreatedAtStr)?.toUtc() : null;
                                if (acceptCreatedAt != null && acceptCreatedAt.isBefore(offerCycleStart)) {
                                  continue; // Ignore accepts from prior cycles
                                }
                              }
                              claimedPasses += 1;
                            }
                          }
                        }
                        final bool isSoldOut = limit != null && claimedPasses >= limit;
                        final int remaining = limit != null ? (limit - claimedPasses).clamp(0, 9999) : 0;

                        return LuxuryCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.primaryLight : AppColors.surfaceSubtle,
                                  borderRadius: AppSpacing.roundedMd,
                                  border: Border.all(
                                    color: isActive ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                                  ),
                                ),
                                child: Icon(
                                  Icons.king_bed_outlined,
                                  color: isActive ? AppColors.primary : AppColors.textMuted,
                                  size: 20,
                                ),
                              ),
                              AppSpacing.gapH12,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(cat, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 8),
                                        LuxuryBadge(
                                          label: isActive ? 'Enabled' : 'Disabled',
                                          variant: isActive ? LuxuryBadgeVariant.success : LuxuryBadgeVariant.neutral,
                                          isSmall: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${catRooms.length} rooms total',
                                          style: AppTypography.bodySmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        const Text('·', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSoldOut
                                                ? AppColors.departureLight
                                                : (limit != null ? AppColors.primaryLight : AppColors.surfaceSubtle),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: isSoldOut
                                                  ? AppColors.departure.withValues(alpha: 0.3)
                                                  : (limit != null ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border),
                                            ),
                                          ),
                                          child: Text(
                                            limit != null
                                                ? (isSoldOut
                                                    ? '$claimedPasses / $limit Claimed (Sold Out)'
                                                    : '$claimedPasses / $limit Claimed ($remaining left)')
                                                : 'Unlimited ($claimedPasses Claimed)',
                                            style: AppTypography.bodySmall.copyWith(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isSoldOut
                                                  ? AppColors.departure
                                                  : (limit != null ? AppColors.primary : AppColors.textSecondary),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _showEditOfferDialog(
                                  context,
                                  propId,
                                  cat,
                                  price,
                                  limit,
                                  catRooms.length,
                                  isActive,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '₹${price.toStringAsFixed(0)} / room',
                                            style: AppTypography.labelMedium.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: isActive ? AppColors.primary : AppColors.textSecondary,
                                            ),
                                          ),
                                          Text(
                                            limit != null ? 'Max $limit offers' : 'Unlimited offers',
                                            style: AppTypography.bodySmall.copyWith(
                                              fontSize: 9.5,
                                              color: limit != null ? AppColors.primary : AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 5),
                                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Switch.adaptive(
                                value: isActive,
                                activeThumbColor: AppColors.primary,
                                onChanged: (val) async {
                                  setState(() {
                                    _localActiveStatus[cat] = val;
                                  });
                                  await SupabaseService.instance.upsertCategoryEarlyLateOffer(
                                    propertyId: propId,
                                    type: 'early_in',
                                    category: cat,
                                    price: price,
                                    limit: limit,
                                    isActive: val,
                                  );
                                  ref.invalidate(earlyCheckinOffersProvider);
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.restart_alt_rounded, size: 19, color: AppColors.primary),
                                tooltip: 'Reset Claimed Passes Quota (Start Fresh Batch)',
                                onPressed: () => _confirmResetOfferClaims(context, propId, cat, offerId, limit),
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.departure),
                                tooltip: 'Delete Category Offer',
                                onPressed: () => _confirmDeleteOffer(context, propId, cat, offerId),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
            ),

          AppSpacing.gapV24,

          // Accepted Early Check-In Claims Section
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppSpacing.roundedSm,
                ),
                child: const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
              ),
              AppSpacing.gapH8,
              Text('Guest Early Check-In Claims & Payments', style: AppTypography.titleSmall),
            ],
          ),
          AppSpacing.gapV12,

          acceptsAsync.when(
            data: (allAccepts) {
              final earlyAccepts = allAccepts.where((a) => a['type'] == 'early_in').toList();
              if (earlyAccepts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text('No early check-in requests claimed yet', style: AppTypography.bodySmall),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: earlyAccepts.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final accept = earlyAccepts[index];
                  final user = accept['users'] as Map<String, dynamic>?;
                  final guestName = user?['name'] ?? accept['guest_name'] ?? 'Guest';
                  final phone = user?['mobile_no'] ?? accept['mobile_no'] ?? '';
                  final amount = accept['amount_paid'] ?? 0;
                  final timeSelectedStr = accept['time_selected']?.toString();
                  final timeSelected = timeSelectedStr != null ? DateTime.tryParse(timeSelectedStr) : null;
                  final roomNums = (accept['room_numbers'] ?? accept['room_number'] ?? '').toString().trim();
                  final roomCount = int.tryParse(accept['room_count']?.toString() ?? '1') ??
                      (roomNums.contains(',') ? roomNums.split(',').length : 1);

                  return LuxuryCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                        AppSpacing.gapH8,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    phone.isNotEmpty ? '$guestName ($phone)' : '$guestName',
                                    style: AppTypography.labelMedium,
                                  ),
                                  if (roomNums.isNotEmpty && roomNums != '—' && roomNums != 'N/A')
                                    LuxuryBadge(
                                      label: roomNums.contains(',')
                                          ? 'Rooms $roomNums ($roomCount)'
                                          : 'Room $roomNums',
                                      variant: LuxuryBadgeVariant.neutral,
                                      isSmall: true,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              if (timeSelected != null)
                                Text(
                                  'Requested Arrival: ${DateFormat('dd MMM, hh:mm a').format(timeSelected.toLocal())}',
                                  style: AppTypography.bodySmall,
                                )
                              else if (timeSelectedStr != null && timeSelectedStr.isNotEmpty)
                                Text(
                                  'Requested Arrival: $timeSelectedStr',
                                  style: AppTypography.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Paid: ₹$amount',
                          style: AppTypography.monoSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
      },
    );
  }
}
