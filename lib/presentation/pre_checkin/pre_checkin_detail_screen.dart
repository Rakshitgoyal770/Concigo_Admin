import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/loading_skeleton_widget.dart';
import '../role_based_dashboard_screen/widgets/checkin_request_widgets.dart';

class PreCheckinDetailScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  final String propertyId;
  final String propertyName;

  const PreCheckinDetailScreen({
    super.key,
    required this.request,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<PreCheckinDetailScreen> createState() => _PreCheckinDetailScreenState();
}

class _PreCheckinDetailScreenState extends State<PreCheckinDetailScreen> {
  final _repo = ReceptionCheckinRepository();
  bool _isActioning = false;

  // Signed URL cache: storagePath → signedUrl
  final Map<String, String?> _signedUrlCache = {};
  bool _loadingUrls = false;

  @override
  void initState() {
    super.initState();
    _preloadSignedUrls();
  }

  /// Pre-generate signed URLs for all doc_link entries in submitted_req.
  Future<void> _preloadSignedUrls() async {
    final submittedReq = widget.request['submitted_req'];
    if (submittedReq is! List || submittedReq.isEmpty) return;

    setState(() => _loadingUrls = true);
    for (final guest in submittedReq) {
      if (guest is Map) {
        final docLink = guest['doc_link'] as String?;
        if (docLink != null && docLink.isNotEmpty) {
          if (!_signedUrlCache.containsKey(docLink)) {
            final url = await _repo.getSignedUrl(docLink);
            _signedUrlCache[docLink] = url;
          }
        }
      }
    }
    if (mounted) setState(() => _loadingUrls = false);
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  String get _guestMobile {
    final userMap = widget.request['users'] as Map<String, dynamic>?;
    return userMap?['mobile_no'] as String? ?? 'Unknown';
  }

  String get _guestName {
    final userMap = widget.request['users'] as Map<String, dynamic>?;
    return userMap?['name'] as String? ?? 'Guest';
  }

  // ── Approve ──────────────────────────────────────────────────────────────

  Future<void> _showApproveConfirmation() async {
    final stayId = widget.request['stay_id'] as String?;
    if (stayId == null) {
      Fluttertoast.showToast(
        msg: 'No stay linked to this request',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.receptionContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppTheme.receptionColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Confirm Approval',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve this check-in request and activate the stay?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 16),
            _buildConfirmRow('Guest', _guestMobile),
            _buildConfirmRow('Action', 'Approve + Set Stay Active'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.receptionColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Approve',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _doApprove(stayId);
    }
  }

  Future<void> _doApprove(String stayId) async {
    setState(() => _isActioning = true);
    try {
      // Uses ReceptionCheckinRepository.approveCheckinRequest
      // PK field on checkin_requests is 'id'
      await _repo.approveCheckinRequest(
        checkinRequestId: widget.request['id'] as String,
        stayId: stayId,
      );
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Check-in Approved & Stay Activated',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActioning = false);
        Fluttertoast.showToast(
          msg: e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: AppTheme.error,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  // ── Deny ─────────────────────────────────────────────────────────────────

  Future<void> _showDenySheet() async {
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isDenying = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.cancel_rounded,
                          size: 20,
                          color: AppTheme.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Deny Request',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reason for denial',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: remarkController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reason…',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.onSurfaceMuted,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isDenying
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => isDenying = true);
                              try {
                                await _repo.denyCheckinRequest(
                                  checkinRequestId:
                                      widget.request['id'] as String,
                                  remark: remarkController.text.trim(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  Fluttertoast.showToast(
                                    msg: 'Request Denied',
                                    backgroundColor: AppTheme.error,
                                    textColor: Colors.white,
                                  );
                                  Navigator.pop(context, true);
                                }
                              } catch (e) {
                                setSheetState(() => isDenying = false);
                                Fluttertoast.showToast(
                                  msg: e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  ),
                                  backgroundColor: AppTheme.error,
                                  textColor: Colors.white,
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isDenying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Confirm Denial',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Column mapping: checkin_requests ──────────────────────────────────
    // PK:          id            (was request_id on precheckin_request)
    // Timestamps:  created_at    (was req_createdat)
    // JSONB:       submitted_req (array of {name, doc_link})
    // Status:      'pending'/'approved'/'denied'
    final requestId = widget.request['id'] as String? ?? '';
    final stayId = widget.request['stay_id'] as String?;
    final createdAt = widget.request['created_at'] as String? ?? '';
    final status = widget.request['status'] as String? ?? 'pending';
    final remark = widget.request['remark'] as String?;

    final submittedReq = widget.request['submitted_req'];
    final guestList = submittedReq is List
        ? submittedReq.whereType<Map>().toList()
        : <Map>[];

    final shortId = requestId.length >= 8
        ? requestId.substring(0, 8).toUpperCase()
        : requestId.toUpperCase();

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(createdAt).toLocal();
    } catch (_) {}
    final timeLabel = parsedDate != null
        ? '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} at ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}'
        : createdAt;

    final isPending = status == 'pending';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request #$shortId',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Guest Info Card ──────────────────────────────────────────
            _buildSectionHeader('Guest Information', Icons.person_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _buildDetailRow(Icons.phone_rounded, 'Mobile', _guestMobile),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.badge_rounded, 'Name', _guestName),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    Icons.hotel_rounded,
                    'Property',
                    widget.propertyName,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Request Info Card ────────────────────────────────────────
            _buildSectionHeader(
              'Request Details',
              Icons.pending_actions_rounded,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _buildDetailRow(Icons.tag_rounded, 'Request ID', '#$shortId'),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    Icons.access_time_rounded,
                    'Requested At',
                    timeLabel,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    Icons.confirmation_number_rounded,
                    'Stay ID',
                    stayId != null
                        ? '#${stayId.substring(0, 8).toUpperCase()}'
                        : 'Not Created Yet',
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    Icons.info_outline_rounded,
                    'Status',
                    status.toUpperCase(),
                  ),
                ],
              ),
            ),

            // ── Remark (shown when denied) ───────────────────────────────
            if (status == 'denied' && remark != null && remark.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionHeader('Denial Reason', Icons.cancel_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.error.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        remark,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Co-Guests / Submitted Documents ─────────────────────────
            _buildSectionHeader(
              'Co-Guests & Documents (${guestList.length})',
              Icons.group_rounded,
            ),
            const SizedBox(height: 10),

            if (_loadingUrls)
              const ListSkeletonWidget(itemCount: 2)
            else if (guestList.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_off_rounded,
                      size: 18,
                      color: AppTheme.onSurfaceMuted,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'No co-guest documents submitted',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...guestList.asMap().entries.map((entry) {
                final idx = entry.key;
                final guest = entry.value;
                final guestName =
                    guest['name'] as String? ?? 'Guest ${idx + 1}';
                final docLink = guest['doc_link'] as String?;
                final signedUrl = docLink != null
                    ? _signedUrlCache[docLink]
                    : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.receptionContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.receptionColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              guestName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (docLink != null && docLink.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        if (signedUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              signedUrl,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    color: AppTheme.onSurfaceMuted,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.description_rounded,
                                  size: 16,
                                  color: AppTheme.onSurfaceMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Document unavailable',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppTheme.onSurfaceMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'No document uploaded',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),

            const SizedBox(height: 32),

            // ── Action Buttons (only for pending requests) ───────────────
            if (isPending) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isActioning ? null : _showApproveConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.receptionColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.outline,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isActioning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Approve Check-in',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isActioning ? null : _showDenySheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withAlpha(120)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Deny Request',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isActioning ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.onSurfaceMuted,
                  side: const BorderSide(color: AppTheme.outline),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.outline),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(6),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.receptionColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.onSurfaceMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
