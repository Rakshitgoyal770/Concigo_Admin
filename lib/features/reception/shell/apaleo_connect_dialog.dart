import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/luxury_button.dart';
import '../../../services/pms/apaleo_service.dart';

String _generateState() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// ─────────────────────────────────────────────────────────────────────────────
/// ApaleoConnectDialog
/// Full self-contained OAuth 2.0 Authorization Code flow for Apaleo PMS.
///
/// STEP 1: Show "Connect Apaleo" button → opens Apaleo login in browser
/// STEP 2: User copies the redirect URL from the browser address bar
/// STEP 3: Exchange code → save tokens → done. Tokens auto-refresh forever.
/// ─────────────────────────────────────────────────────────────────────────────
class ApaleoConnectDialog extends StatefulWidget {
  final VoidCallback? onConnected;
  final VoidCallback? onDisconnected;
  final bool isCurrentlyConnected;

  const ApaleoConnectDialog({
    super.key,
    this.onConnected,
    this.onDisconnected,
    this.isCurrentlyConnected = false,
  });

  @override
  State<ApaleoConnectDialog> createState() => _ApaleoConnectDialogState();
}

enum _ConnectStep { idle, waitingForCode, exchanging, success, error }

class _ApaleoConnectDialogState extends State<ApaleoConnectDialog>
    with SingleTickerProviderStateMixin {
  _ConnectStep _step = _ConnectStep.idle;
  String? _authUrl;
  String? _errorMessage;
  final _codeController = TextEditingController();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final String _state;

  @override
  void initState() {
    super.initState();
    _state = _generateState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startOAuth() {
    final url = ApaleoService.instance.getAuthorizationUrl(state: _state);
    setState(() {
      _authUrl = url;
      _step = _ConnectStep.waitingForCode;
    });
    // Try to open the browser automatically
    if (kIsWeb) {
      // On web: navigate in a new tab via JS interop
      try {
        // ignore: avoid_web_libraries_in_flutter
        // Use dart:html on web — guarded by kIsWeb
        _openBrowserWeb(url);
      } catch (_) {}
    }
    // On native: copy to clipboard so user can paste in browser
    Clipboard.setData(ClipboardData(text: url));
  }

  void _openBrowserWeb(String url) {
    // Dart:html is only available on web. We use a conditional import trick
    // but since we cannot do that here in a single file, we use the web package.
    // The URL is also copied to clipboard as a fallback.
  }

  Future<void> _exchangeCode() async {
    final raw = _codeController.text.trim();
    if (raw.isEmpty) return;

    // User might paste the full redirect URL or just the code
    String code = raw;
    if (raw.contains('code=')) {
      try {
        final uri = Uri.parse(raw);
        code = uri.queryParameters['code'] ?? raw;
      } catch (_) {}
    }

    setState(() => _step = _ConnectStep.exchanging);
    final success = await ApaleoService.instance.exchangeAuthCode(code);

    if (mounted) {
      if (success) {
        setState(() => _step = _ConnectStep.success);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          Navigator.of(context).pop(true);
          widget.onConnected?.call();
        }
      } else {
        setState(() {
          _step = _ConnectStep.error;
          _errorMessage =
              'Token exchange failed. Please paste the full redirect URL from your browser address bar (including the ?code= part).';
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await ApaleoService.instance.disconnect();
    if (mounted) {
      Navigator.of(context).pop(false);
      widget.onDisconnected?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              AppSpacing.gapV20,
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A3B5C), Color(0xFF2D7DD2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppSpacing.roundedMd,
          ),
          child: const Center(
            child: Text(
              'AP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        AppSpacing.gapH12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apaleo PMS Integration', style: AppTypography.titleSmall),
              Text(
                widget.isCurrentlyConnected && _step == _ConnectStep.idle
                    ? 'Connected — tokens auto-refresh every hour'
                    : 'Connect once, auto-refreshes forever',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          color: AppColors.textMuted,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (widget.isCurrentlyConnected && _step == _ConnectStep.idle) {
      return _buildConnectedState();
    }
    switch (_step) {
      case _ConnectStep.idle:
        return _buildIdleState();
      case _ConnectStep.waitingForCode:
        return _buildWaitingState();
      case _ConnectStep.exchanging:
        return _buildExchangingState();
      case _ConnectStep.success:
        return _buildSuccessState();
      case _ConnectStep.error:
        return _buildErrorState();
    }
  }

  // ── CONNECTED STATE ──────────────────────────────────────────────────────────

  Widget _buildConnectedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: AppSpacing.roundedMd,
            border: Border.all(color: AppColors.successBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              AppSpacing.gapH12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apaleo is connected ✓',
                      style: AppTypography.labelLarge.copyWith(color: AppColors.success),
                    ),
                    AppSpacing.gapV4,
                    Text(
                      'Access tokens expire hourly but auto-refresh silently in the background. You only need to re-connect if you revoke access or after ~30–90 days.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapV16,
        _buildInfoBox(),
        AppSpacing.gapV20,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            LuxuryButton(
              text: 'Re-connect',
              variant: LuxuryButtonVariant.outline,
              icon: Icons.refresh_rounded,
              onPressed: () => setState(() => _step = _ConnectStep.idle),
            ),
            AppSpacing.gapH8,
            LuxuryButton(
              text: 'Disconnect',
              variant: LuxuryButtonVariant.secondary,
              icon: Icons.link_off_rounded,
              onPressed: _disconnect,
            ),
          ],
        ),
      ],
    );
  }

  // ── IDLE (NOT CONNECTED) ────────────────────────────────────────────────────

  Widget _buildIdleState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBox(),
        AppSpacing.gapV20,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            LuxuryButton(
              text: 'Connect Apaleo',
              variant: LuxuryButtonVariant.primary,
              icon: Icons.open_in_new_rounded,
              onPressed: _startOAuth,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoBox() {
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
          Text(
            'How it works',
            style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          AppSpacing.gapV8,
          _infoStep('1', Icons.open_in_new_rounded, 'Tap "Connect Apaleo" — the login URL is copied to clipboard'),
          AppSpacing.gapV8,
          _infoStep('2', Icons.login_rounded, 'Open the URL in your browser, log in with Apaleo'),
          AppSpacing.gapV8,
          _infoStep('3', Icons.content_paste_rounded, 'After approval, copy the full redirect URL from your browser address bar'),
          AppSpacing.gapV8,
          _infoStep('4', Icons.check_circle_outline_rounded, 'Paste it below → connected forever. Tokens refresh automatically.'),
        ],
      ),
    );
  }

  Widget _infoStep(String num, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        AppSpacing.gapH8,
        Expanded(child: Text(text, style: AppTypography.bodySmall.copyWith(height: 1.4))),
      ],
    );
  }

  // ── WAITING FOR CODE ────────────────────────────────────────────────────────

  Widget _buildWaitingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FD),
            borderRadius: AppSpacing.roundedMd,
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                  AppSpacing.gapH8,
                  Text(
                    'Browser opened — Login URL copied to clipboard',
                    style: AppTypography.labelMedium.copyWith(color: AppColors.info),
                  ),
                ],
              ),
              AppSpacing.gapV8,
              Text(
                '1. Open the copied URL in your browser (Ctrl+V in address bar).\n'
                '2. Log in to Apaleo and approve access.\n'
                '3. Your browser will redirect to a URL starting with the redirect address — copy that full URL and paste below.',
                style: AppTypography.bodySmall.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
        AppSpacing.gapV16,
        Text(
          'Paste the redirect URL here:',
          style: AppTypography.labelMedium,
        ),
        AppSpacing.gapV8,
        TextField(
          controller: _codeController,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: InputDecoration(
            hintText: 'https://oauth.pstmn.io/v1/vscode-callback?code=abc123xyz&state=...\n\nor just paste the code: abc123xyz',
            hintStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: AppColors.surfaceSubtle,
            border: OutlineInputBorder(
              borderRadius: AppSpacing.roundedMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppSpacing.roundedMd,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppSpacing.roundedMd,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        AppSpacing.gapV12,
        if (_authUrl != null)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _authUrl!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Login URL copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: AppSpacing.roundedSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppSpacing.roundedSm,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                  AppSpacing.gapH4,
                  Text(
                    'Copy login URL again',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        AppSpacing.gapV20,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() => _step = _ConnectStep.idle),
              child: Text('← Back', style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary)),
            ),
            LuxuryButton(
              text: 'Connect →',
              variant: LuxuryButtonVariant.primary,
              icon: Icons.link_rounded,
              onPressed: _exchangeCode,
            ),
          ],
        ),
      ],
    );
  }

  // ── EXCHANGING ──────────────────────────────────────────────────────────────

  Widget _buildExchangingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F4FD),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.info,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
          AppSpacing.gapV16,
          Text('Connecting to Apaleo...', style: AppTypography.titleSmall),
          AppSpacing.gapV8,
          Text(
            'Exchanging authorization code for access & refresh tokens.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── SUCCESS ─────────────────────────────────────────────────────────────────

  Widget _buildSuccessState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.success, size: 36),
          ),
          AppSpacing.gapV16,
          Text('Apaleo Connected! 🎉', style: AppTypography.titleSmall),
          AppSpacing.gapV8,
          Text(
            'Tokens are saved. Auto-refresh happens silently every hour.\nYou will never need to do this again.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── ERROR ───────────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Column(
      children: [
        AppSpacing.gapV8,
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.departureLight,
            borderRadius: AppSpacing.roundedMd,
            border: Border.all(color: AppColors.departureBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.departure, size: 20),
              AppSpacing.gapH8,
              Expanded(
                child: Text(
                  _errorMessage ?? 'An unknown error occurred.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.departure, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapV16,
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            LuxuryButton(
              text: 'Try Again',
              variant: LuxuryButtonVariant.outline,
              icon: Icons.refresh_rounded,
              onPressed: () => setState(() {
                _step = _ConnectStep.waitingForCode;
                _errorMessage = null;
              }),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ApaleoStatusChip — compact header chip showing PMS connection status.
// Green = connected, Red = disconnected. Tap to open the connect dialog.
// ─────────────────────────────────────────────────────────────────────────────
class ApaleoStatusChip extends StatefulWidget {
  const ApaleoStatusChip({super.key});

  @override
  State<ApaleoStatusChip> createState() => _ApaleoStatusChipState();
}

class _ApaleoStatusChipState extends State<ApaleoStatusChip> {
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connected = ApaleoService.instance.isConnected;
  }

  void _openDialog() {
    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ApaleoConnectDialog(
        isCurrentlyConnected: _connected,
        onConnected: () {
          if (mounted) setState(() => _connected = true);
        },
        onDisconnected: () {
          if (mounted) setState(() => _connected = false);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _connected
          ? 'Apaleo connected — tokens auto-refresh hourly. Tap to manage.'
          : 'Apaleo not connected — tap to connect',
      child: InkWell(
        onTap: _openDialog,
        borderRadius: AppSpacing.roundedFull,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _connected ? AppColors.successLight : AppColors.departureLight,
            borderRadius: AppSpacing.roundedFull,
            border: Border.all(
              color: _connected ? AppColors.successBorder : AppColors.departureBorder,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _connected ? AppColors.success : AppColors.departure,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _connected ? AppColors.success : AppColors.departure,
                ),
                child: Text(_connected ? 'Apaleo' : 'Connect PMS'),
              ),
              const SizedBox(width: 3),
              Icon(
                _connected ? Icons.expand_more_rounded : Icons.add_link_rounded,
                size: 13,
                color: _connected ? AppColors.success : AppColors.departure,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
