import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_card.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../data/providers/reception_providers.dart';
import '../../../../data/providers/supabase_providers.dart';
import 'kyc_inspector_modal.dart';

class KycQueueTab extends ConsumerStatefulWidget {
  const KycQueueTab({super.key});

  @override
  ConsumerState<KycQueueTab> createState() => _KycQueueTabState();
}

class _KycQueueTabState extends ConsumerState<KycQueueTab> {
  @override
  Widget build(BuildContext context) {
    final kycRequestsAsync = ref.watch(checkinRequestsProvider);

    return LuxuryCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: const Icon(Icons.verified_user_outlined, size: 20, color: AppColors.primary),
                    ),
                    AppSpacing.gapH12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KYC Document Verification Queue', style: AppTypography.titleSmall),
                          Text(
                            'Guest government ID documents, companion records & digital check-in approvals',
                            style: AppTypography.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (kycRequestsAsync.asData?.value.isNotEmpty == true)
                LuxuryBadge(
                  label: '${kycRequestsAsync.asData!.value.length} Pending',
                  variant: LuxuryBadgeVariant.attention,
                ),
            ],
          ),
          AppSpacing.gapV16,

          // Requests List
          kycRequestsAsync.when(
            data: (requests) {
              final pendingRequests = requests.where((r) {
                final st = (r['status'] as String? ?? '').trim().toLowerCase();
                return st != 'approved' && st != 'rejected' && st != 'denied';
              }).toList();

              if (pendingRequests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppColors.successLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_outlined, size: 26, color: AppColors.success),
                        ),
                        AppSpacing.gapV12,
                        Text(
                          'All KYC Document Verifications Are Cleared',
                          style: AppTypography.titleSmall,
                        ),
                        AppSpacing.gapV4,
                        Text(
                          'When guests submit digital check-in and upload government ID proofs, they will appear here.',
                          style: AppTypography.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < pendingRequests.length; i++) ...[
                    if (i > 0) AppSpacing.gapV12,
                    _buildKycCard(context, pendingRequests[i]),
                  ],
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Text('Failed to load queue: $err', style: const TextStyle(color: AppColors.departure)),
          ),
        ],
      ),
    );
  }

  /// Dedicated KYC Document Verification Card
  Widget _buildKycCard(BuildContext context, Map<String, dynamic> req) {
    final guestName = (req['guest_name'] ?? req['user_name'] ?? 'Guest').toString();
    final phone = (req['phone_number'] ?? req['phone'] ?? '').toString();
    final roomNum = (req['room_number'] ?? req['room_no'] ?? 'Unassigned').toString();
    final docType = (req['doc_type'] ?? 'Government ID Proof').toString();
    final accountName = (req['account_user_name'] ?? '').toString();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: const [AppColors.shadowSm],
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.roundedMd,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(color: AppColors.attention),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md + 4, AppSpacing.md, AppSpacing.md, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top row: Room & Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.attentionLight,
                          borderRadius: AppSpacing.roundedSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hotel_rounded, size: 14, color: AppColors.attention),
                            const SizedBox(width: 4),
                            Text(
                              'Room: $roomNum',
                              style: AppTypography.monoRoom.copyWith(
                                fontSize: 12,
                                color: AppColors.attention,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const LuxuryBadge(
                        label: '🪪 KYC Review Required',
                        variant: LuxuryBadgeVariant.attention,
                        isSmall: true,
                      ),
                    ],
                  ),
                  AppSpacing.gapV12,

                  // Guest & Document Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.attentionLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.badge_outlined, size: 20, color: AppColors.attention),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(guestName, style: AppTypography.labelLarge),
                            AppSpacing.gapV4,
                            Text(
                              accountName.isNotEmpty && accountName != guestName
                                  ? '$phone • $docType (Booked by: $accountName)'
                                  : '$phone • $docType',
                              style: AppTypography.bodySmall,
                            ),
                            AppSpacing.gapV8,
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: AppSpacing.roundedSm,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.attention),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Guest uploaded identity documents for fast-track check-in. Verification unlocks 4-digit digital key.',
                                      style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapV12,

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildInspectButton(context, req),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInspectButton(BuildContext context, Map<String, dynamic> req) {
    return LuxuryButton(
      text: 'Inspect & Approve KYC',
      variant: LuxuryButtonVariant.primary,
      height: 36,
      icon: Icons.visibility_outlined,
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => KycInspectorModal(checkinRequest: req),
        );
      },
    );
  }
}
