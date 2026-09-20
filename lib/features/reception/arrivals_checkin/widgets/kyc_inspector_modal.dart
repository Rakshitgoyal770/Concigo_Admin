import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import '../../../../core/widgets/luxury_badge.dart';
import '../../../../data/providers/supabase_providers.dart';
import '../../../../data/providers/reception_providers.dart';

class _KycDocItem {
  final String name;
  final String rawLink;
  String? resolvedUrl;
  final bool isPdf;

  _KycDocItem({
    required this.name,
    required this.rawLink,
    required this.isPdf,
  });
}

class KycInspectorModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> checkinRequest;

  const KycInspectorModal({
    super.key,
    required this.checkinRequest,
  });

  @override
  ConsumerState<KycInspectorModal> createState() => _KycInspectorModalState();
}

class _KycInspectorModalState extends ConsumerState<KycInspectorModal> {
  bool _isProcessing = false;
  List<_KycDocItem> _docItems = [];
  int _selectedDocIndex = 0;
  bool _isLoadingDocs = true;
  bool _showRejectReason = false;
  final TextEditingController _reasonController =
      TextEditingController(text: 'Document unreadable or invalid');

  @override
  void initState() {
    super.initState();
    _loadDocumentUrls();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDocumentUrls() async {
    setState(() => _isLoadingDocs = true);
    final req = widget.checkinRequest;
    final List<_KycDocItem> items = [];

    final subList =
        (req['submitted_documents'] ?? req['submitted_req']) as List?;

    if (subList != null && subList.isNotEmpty) {
      for (final doc in subList) {
        if (doc is Map) {
          final name = (doc['name'] ?? 'Guest').toString();
          final rawLink = (doc['doc_link'] ?? doc['url'] ?? '').toString();
          if (rawLink.isNotEmpty) {
            final isPdf = rawLink.toLowerCase().endsWith('.pdf');
            items.add(_KycDocItem(name: name, rawLink: rawLink, isPdf: isPdf));
          }
        }
      }
    }

    if (items.isEmpty) {
      final singleLink = (req['doc_url'] ??
              req['document_url'] ??
              req['image_url'] ??
              '')
          .toString();
      if (singleLink.isNotEmpty) {
        final isPdf = singleLink.toLowerCase().endsWith('.pdf');
        items.add(_KycDocItem(
          name: (req['guest_name'] ?? 'Primary Guest').toString(),
          rawLink: singleLink,
          isPdf: isPdf,
        ));
      }
    }

    // Resolve URLs for all items
    for (final item in items) {
      if (item.rawLink.startsWith('http')) {
        item.resolvedUrl = item.rawLink;
      } else {
        try {
          final signedUrl = await ref
              .read(supabaseServiceProvider)
              .client
              .storage
              .from('user-documents')
              .createSignedUrl(item.rawLink, 3600);
          item.resolvedUrl = signedUrl;
        } catch (_) {
          final publicUrl = ref
              .read(supabaseServiceProvider)
              .client
              .storage
              .from('user-documents')
              .getPublicUrl(item.rawLink);
          item.resolvedUrl = publicUrl;
        }
      }
    }

    if (mounted) {
      setState(() {
        _docItems = items;
        _isLoadingDocs = false;
        _selectedDocIndex = 0;
      });
    }
  }

  Future<void> _handleDecision(String status, {String? reason}) async {
    setState(() => _isProcessing = true);
    final reqId = (widget.checkinRequest['request_id'] ?? widget.checkinRequest['id']).toString();

    try {
      await ref.read(guestServiceProvider).updateCheckinRequestStatus(
        requestId: reqId,
        status: status,
        rejectionReason: reason,
      );

      ref.read(receptionRefreshSignalProvider.notifier).state++;

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: status.toUpperCase() == 'APPROVED' ? AppColors.success : AppColors.departure,
            behavior: SnackBarBehavior.floating,
            content: Text(
              status.toUpperCase() == 'APPROVED'
                  ? 'KYC Approved! Guest can now view their 4-digit Fast-Pass code.'
                  : 'KYC Document Rejected.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.departure, content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openFullImageViewer(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: AppSpacing.roundedMd,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.checkinRequest;
    final guestName =
        (req['guest_name'] ?? req['user_name'] ?? 'Guest').toString();
    final phone = (req['phone_number'] ?? req['phone'] ?? 'N/A').toString();
    final roomNum =
        (req['room_number'] ?? req['room_no'] ?? 'Unassigned').toString();
    final docType =
        (req['doc_type'] ?? req['document_type'] ?? 'Government ID Proof')
            .toString();
    final status = (req['status'] as String? ?? 'pending').toLowerCase();
    final isApproved = status == 'approved';

    final currentDoc = (_docItems.isNotEmpty &&
            _selectedDocIndex < _docItems.length)
        ? _docItems[_selectedDocIndex]
        : null;

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          return Container(
            constraints: const BoxConstraints(maxWidth: 720),
            padding: EdgeInsets.all(isCompact ? AppSpacing.md : AppSpacing.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal Header
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isApproved
                              ? AppColors.successLight
                              : AppColors.attentionLight,
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: Icon(
                          isApproved
                              ? Icons.verified_rounded
                              : Icons.badge_outlined,
                          color: isApproved
                              ? AppColors.success
                              : AppColors.attention,
                          size: 20,
                        ),
                      ),
                      AppSpacing.gapH12,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KYC Document Inspector',
                              style: isCompact
                                  ? AppTypography.titleSmall
                                  : AppTypography.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Verification for Room $roomNum',
                              style: AppTypography.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Status Indicator Tag & Total IDs Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      LuxuryBadge(
                        label: isApproved
                            ? 'STATUS: APPROVED & VERIFIED'
                            : 'STATUS: PENDING RECEPTION REVIEW',
                        variant: isApproved
                            ? LuxuryBadgeVariant.success
                            : LuxuryBadgeVariant.attention,
                        isSmall: true,
                      ),
                      if (_docItems.isNotEmpty)
                        LuxuryBadge(
                          label: '${_docItems.length} of 3 ID(s) Attached',
                          variant: LuxuryBadgeVariant.neutral,
                          isSmall: true,
                        ),
                    ],
                  ),
                  AppSpacing.gapV12,

                  // Guest ID Selector Tabs (if more than 1 document uploaded)
                  if (_docItems.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: List.generate(_docItems.length, (idx) {
                          final doc = _docItems[idx];
                          final isSelected = _selectedDocIndex == idx;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _selectedDocIndex = idx),
                                borderRadius: AppSpacing.roundedSm,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 7, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: AppSpacing.roundedSm,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        doc.isPdf
                                            ? Icons.picture_as_pdf_rounded
                                            : Icons.badge_outlined,
                                        size: 14,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          '${idx + 1}. ${doc.name}',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    AppSpacing.gapV12,
                  ],

                  // Body Content: Responsive Stack or 2-Col
                  if (isCompact) ...[
                    _buildDetailsCard(guestName, phone, roomNum, docType, req),
                    AppSpacing.gapV12,
                    _buildPhotoCard(currentDoc),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _buildDetailsCard(
                              guestName, phone, roomNum, docType, req),
                        ),
                        AppSpacing.gapH16,
                        Expanded(
                          flex: 13,
                          child: _buildPhotoCard(currentDoc),
                        ),
                      ],
                    ),
                  ],

                  if (_showRejectReason) ...[
                    AppSpacing.gapV12,
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.departureLight,
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(
                            color: AppColors.departure.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reason for Rejection',
                              style: AppTypography.labelMedium
                                  .copyWith(color: AppColors.departure)),
                          AppSpacing.gapV8,
                          TextField(
                            controller: _reasonController,
                            style: AppTypography.bodySmall,
                            decoration: InputDecoration(
                              hintText:
                                  'e.g., ID is blurry, expired or does not match name',
                              isDense: true,
                              fillColor: AppColors.surface,
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: AppSpacing.roundedSm,
                                borderSide: BorderSide(
                                    color: AppColors.departure
                                        .withValues(alpha: 0.4)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  AppSpacing.gapV20,

                  // Action Footer with Non-Overflowing Wrap
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (!_showRejectReason) ...[
                        LuxuryButton(
                          text: 'Reject',
                          variant: LuxuryButtonVariant.outline,
                          icon: Icons.cancel_outlined,
                          isLoading: _isProcessing,
                          onPressed: () {
                            setState(() => _showRejectReason = true);
                          },
                        ),
                      ] else ...[
                        LuxuryButton(
                          text: 'Cancel Reject',
                          variant: LuxuryButtonVariant.secondary,
                          onPressed: () {
                            setState(() => _showRejectReason = false);
                          },
                        ),
                        LuxuryButton(
                          text: 'Confirm Reject',
                          variant: LuxuryButtonVariant.danger,
                          icon: Icons.cancel_outlined,
                          isLoading: _isProcessing,
                          onPressed: () {
                            _handleDecision('REJECTED',
                                reason: _reasonController.text.trim());
                          },
                        ),
                      ],
                      LuxuryButton(
                        text: isApproved
                            ? 'Re-Approve Document'
                            : 'Approve KYC Document',
                        variant: LuxuryButtonVariant.success,
                        icon: Icons.check_circle_rounded,
                        isLoading: _isProcessing,
                        onPressed: () => _handleDecision('APPROVED'),
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

  Widget _buildDetailsCard(String guestName, String phone, String roomNum,
      String docType, Map<String, dynamic> req) {
    final checkinCode = (req['checkin_code'] ?? '').toString();
    final specialReq = (req['special_req'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guest Information',
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.textPrimary)),
          const Divider(height: 16),
          _buildInfoRow('Primary Guest', guestName),
          if (req['account_user_name'] != null &&
              req['account_user_name'] != guestName)
            _buildInfoRow(
                'Account Holder', (req['account_user_name'] ?? '').toString()),
          _buildInfoRow('Phone', phone),
          _buildInfoRow('Assigned Room', 'Room $roomNum'),
          if (checkinCode.isNotEmpty)
            _buildInfoRow('Check-in Code', checkinCode),
          _buildInfoRow('Doc Type', docType),
          _buildInfoRow('Total Attached', '${_docItems.length} of 3 ID(s)'),

          // Special Request Callout Card
          if (specialReq.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD54F)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.room_service_outlined,
                          size: 15, color: Color(0xFFF57F17)),
                      const SizedBox(width: 5),
                      Text(
                        'Guest Special Request',
                        style: AppTypography.labelSmall.copyWith(
                          color: const Color(0xFFF57F17),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialReq,
                    style: AppTypography.bodySmall.copyWith(
                      color: const Color(0xFF424242),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoCard(_KycDocItem? docItem) {
    final docUrl = docItem?.resolvedUrl ?? '';
    final isPdf = docItem?.isPdf ?? false;
    final guestLabel = docItem?.name ?? 'Guest';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID Proof: $guestLabel',
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
              if (docUrl.isNotEmpty && !isPdf)
                InkWell(
                  onTap: () => _openFullImageViewer(docUrl),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fullscreen,
                          size: 16, color: AppColors.primary),
                      AppSpacing.gapH4,
                      Text('Enlarge',
                          style: AppTypography.labelSmall
                              .copyWith(color: AppColors.primary)),
                    ],
                  ),
                ),
            ],
          ),
          const Divider(height: 16),
          _buildDocumentPreview(docItem),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview(_KycDocItem? docItem, {double height = 180}) {
    if (_isLoadingDocs) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final docUrl = docItem?.resolvedUrl ?? '';
    final isPdf = docItem?.isPdf ?? false;

    if (docUrl.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined, size: 36, color: AppColors.textMuted),
              SizedBox(height: 6),
              Text('No document image uploaded',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    // PDF Document Handling
    if (isPdf) {
      return Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBE9E7),
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(color: const Color(0xFFFFCCBC)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                size: 40, color: Color(0xFFD84315)),
            const SizedBox(height: 8),
            Text(
              'PDF Identity Document',
              style: AppTypography.labelMedium
                  .copyWith(color: const Color(0xFFD84315)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                html.window.open(docUrl, '_blank');
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open PDF in New Tab'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD84315),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
    }

    // Image Document Handling
    return GestureDetector(
      onTap: () => _openFullImageViewer(docUrl),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          docUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined,
                      size: 36, color: AppColors.textMuted),
                  AppSpacing.gapV8,
                  Text('Unable to render image',
                      style: AppTypography.bodySmall),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style:
                  AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
