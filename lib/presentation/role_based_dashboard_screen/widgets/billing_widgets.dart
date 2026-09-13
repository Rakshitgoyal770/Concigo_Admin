import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../services/supabase_service.dart';

/// Shared billing form widget used by Spa Manager and Laundry Manager
class BillingFormWidget extends StatefulWidget {
  final String propertyId;
  final String empId;
  final String serviceId;
  final Color accentColor;

  const BillingFormWidget({
    super.key,
    required this.propertyId,
    required this.empId,
    required this.serviceId,
    required this.accentColor,
  });

  @override
  State<BillingFormWidget> createState() => _BillingFormWidgetState();
}

class _BillingFormWidgetState extends State<BillingFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();

  bool _isLooking = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _resolvedStay;
  String? _lookupError;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _roomCtrl.dispose();
    _amtCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupStay() async {
    final mobile = _mobileCtrl.text.trim();
    final room = _roomCtrl.text.trim();
    if (mobile.isEmpty || room.isEmpty) {
      setState(
        () => _lookupError = 'Enter both mobile number and room number.',
      );
      return;
    }
    setState(() {
      _isLooking = true;
      _lookupError = null;
      _resolvedStay = null;
    });
    try {
      final stay = await SupabaseService.instance.lookupActiveStay(
        mobile: mobile,
        roomNumber: room,
        propertyId: widget.propertyId,
      );
      if (mounted) {
        setState(() {
          _isLooking = false;
          if (stay == null) {
            _lookupError =
                'No active stay found for this mobile number and room number.';
          } else {
            _resolvedStay = stay;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLooking = false;
          _lookupError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submitBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_resolvedStay == null) {
      setState(() => _lookupError = 'Please look up the guest stay first.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final billId = await SupabaseService.instance.createServiceBill(
        propertyId: widget.propertyId,
        stayId: _resolvedStay!['stay_id'] as String,
        userId: _resolvedStay!['user_id'] as String,
        roomNo: _roomCtrl.text.trim(),
        amt: double.parse(_amtCtrl.text.trim()),
        createdBy: widget.empId,
        serviceId: widget.serviceId,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog(billId);
        _mobileCtrl.clear();
        _roomCtrl.clear();
        _amtCtrl.clear();
        setState(() => _resolvedStay = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Fluttertoast.showToast(
          msg: e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: AppTheme.error,
          textColor: Colors.white,
        );
      }
    }
  }

  void _showSuccessDialog(String billId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.success,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Bill Created',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _receiptRow('Guest', _resolvedStay?['guest_name'] ?? '-'),
                  _receiptRow('Room', _roomCtrl.text),
                  _receiptRow('Amount', '₹${_amtCtrl.text}'),
                  _receiptRow(
                    'Bill ID',
                    '#${billId.substring(0, 8).toUpperCase()}',
                  ),
                  _receiptRow('Status', 'Unpaid'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Done',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guest Lookup',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mobileCtrl,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration('Mobile Number', Icons.phone_rounded),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            onChanged: (_) => setState(() => _resolvedStay = null),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _roomCtrl,
            decoration: _inputDecoration('Room Number', Icons.bed_rounded),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            onChanged: (_) => setState(() => _resolvedStay = null),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLooking ? null : _lookupStay,
              icon: _isLooking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded, size: 16),
              label: Text(
                _isLooking ? 'Looking up...' : 'Lookup Stay',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
          if (_lookupError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: AppTheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _lookupError!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_resolvedStay != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.successContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.success.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppTheme.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Stay Found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Guest: ${_resolvedStay!['guest_name'] ?? '-'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Status: ${_resolvedStay!['stay_status'] ?? '-'}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.outlineVariant),
          const SizedBox(height: 20),
          Text(
            'Bill Details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amtCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              'Amount (₹)',
              Icons.currency_rupee_rounded,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final n = double.tryParse(v.trim());
              if (n == null || n <= 0) return 'Enter a valid amount > 0';
              return null;
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isSubmitting || _resolvedStay == null)
                  ? null
                  : _submitBill,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.receipt_long_rounded, size: 16),
              label: Text(
                _isSubmitting ? 'Creating...' : 'Create Bill',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 24),
          BillsListWidget(
            propertyId: widget.propertyId,
            empId: widget.empId,
            accentColor: widget.accentColor,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: AppTheme.onSurfaceMuted,
      ),
      prefixIcon: Icon(icon, size: 18, color: AppTheme.onSurfaceMuted),
      filled: true,
      fillColor: AppTheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: widget.accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

/// Shared bills list widget used by Spa Manager and Laundry Manager
class BillsListWidget extends StatefulWidget {
  final String propertyId;
  final String empId;
  final Color accentColor;

  const BillsListWidget({
    super.key,
    required this.propertyId,
    required this.empId,
    required this.accentColor,
  });

  @override
  State<BillsListWidget> createState() => _BillsListWidgetState();
}

class _BillsListWidgetState extends State<BillsListWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _bills = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    try {
      final bills = await SupabaseService.instance.fetchServiceBills(
        propertyId: widget.propertyId,
        empId: widget.empId,
      );
      if (mounted) {
        setState(() {
          _bills = bills;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _bills;
    return _bills.where((b) => b['payment_status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bills',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              onPressed: _loadBills,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              color: AppTheme.onSurfaceMuted,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: ['all', 'unpaid', 'paid'].map((f) {
            final isActive = _filter == f;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isActive ? widget.accentColor : AppTheme.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isActive ? widget.accentColor : AppTheme.outline,
                  ),
                ),
                child: Text(
                  f[0].toUpperCase() + f.substring(1),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppTheme.onSurfaceMuted,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_filtered.isEmpty)
          EmptyStateWidget(
            icon: Icons.receipt_long_rounded,
            title: 'No bills',
            description: 'Bills you create will appear here.',
          )
        else
          ..._filtered.map((bill) => _buildBillCard(bill)),
      ],
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final billId = bill['bill_id'] as String? ?? '';
    final guestName = bill['guest_name'] as String? ?? 'Guest';
    final roomNo = bill['room_no'] as String? ?? '-';
    final amt = (bill['amt'] as num?)?.toDouble() ?? 0.0;
    final status = bill['payment_status'] as String? ?? 'unpaid';
    final createdAt = bill['created_at'] as String? ?? '';
    final timeStr = createdAt.length >= 10
        ? createdAt.substring(0, 10)
        : createdAt;
    final isPaid = status == 'paid';
    final paymentMethod = bill['payment_method'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaid ? AppTheme.successContainer : AppTheme.warningContainer,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guestName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Room $roomNo · $timeStr',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                  ),
                ),
                Text(
                  '#${billId.substring(0, billId.length.clamp(0, 8)).toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                if (isPaid && paymentMethod != null)
                  Text(
                    'Paid via $paymentMethod',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amt.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              if (!isPaid)
                GestureDetector(
                  onTap: () => _showMarkPaidDialog(bill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Mark Paid',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Paid',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMarkPaidDialog(Map<String, dynamic> bill) {
    String selectedMethod = 'cash';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppTheme.surface,
          title: Text(
            'Mark as Paid',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select payment method:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 12),
              ...['cash', 'card', 'upi'].map(
                (method) => RadioListTile<String>(
                  value: method,
                  groupValue: selectedMethod,
                  onChanged: (v) => setDialogState(() => selectedMethod = v!),
                  title: Text(
                    method.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  activeColor: widget.accentColor,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _markPaid(bill['bill_id'] as String, selectedMethod);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Confirm',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markPaid(String billId, String method) async {
    try {
      await SupabaseService.instance.markBillPaid(
        billId: billId,
        paymentMethod: method,
      );
      Fluttertoast.showToast(
        msg: 'Bill marked as paid',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
      );
      _loadBills();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed: $e',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
    }
  }
}
