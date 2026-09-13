import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import './widgets/otp_input_widget.dart';
import './widgets/step_indicator_widget.dart';

class LoginVerificationScreen extends StatefulWidget {
  const LoginVerificationScreen({super.key});

  @override
  State<LoginVerificationScreen> createState() =>
      _LoginVerificationScreenState();
}

class _LoginVerificationScreenState extends State<LoginVerificationScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0; // 0=phone, 1=otp

  // Step 0 — Phone
  final TextEditingController _phoneController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  String _countryCode = '+91';
  bool _isSendingOtp = false;

  // Step 1 — OTP
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  int _resendTimer = 0;
  bool _canResend = false;

  late AnimationController _stepTransitionController;
  late Animation<double> _stepFade;
  late Animation<Offset> _stepSlide;

  static const Color _brandColor = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _stepTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _stepFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stepTransitionController, curve: Curves.easeOut),
    );
    _stepSlide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _stepTransitionController,
            curve: Curves.easeOutCubic,
          ),
        );
    _stepTransitionController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _stepTransitionController.dispose();
    if (!kIsWeb) {
      try {
        SmsAutoFill().unregisterListener();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _goToStep(int step) async {
    _stepTransitionController.reset();
    setState(() => _currentStep = step);
    _stepTransitionController.forward();
    if (step == 1 && !kIsWeb) {
      _startSmsListening();
    }
  }

  Future<void> _startSmsListening() async {
    try {
      final appSignature = await SmsAutoFill().getAppSignature;
      debugPrint('📱 [Admin App] SMS App Signature: $appSignature');
      await SmsAutoFill().listenForCode();
      SmsAutoFill().code.listen((code) {
        if (mounted && code != null && code.length == 6) {
          _fillOtp(code);
        }
      });
    } catch (e) {
      debugPrint('❌ [Admin App] SMS Auto-Fill init failed: $e');
    }
  }

  void _fillOtp(String otp) {
    for (int i = 0; i < 6 && i < otp.length; i++) {
      _otpControllers[i].text = otp[i];
    }
    setState(() {});
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _otpControllers.every((c) => c.text.trim().isNotEmpty)) {
        _verifyOtp();
      }
    });
  }

  String get _e164Phone {
    final digits = _phoneController.text.trim();
    return '$_countryCode$digits';
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    setState(() => _isSendingOtp = true);
    try {
      await SupabaseService.instance.sendOtp(_e164Phone);
      if (mounted) {
        setState(() {
          _isSendingOtp = false;
          _resendTimer = 30;
          _canResend = false;
        });
        _startResendTimer();
        _goToStep(1);
        Fluttertoast.showToast(
          msg: 'OTP sent to $_countryCode ${_phoneController.text}',
          backgroundColor: AppTheme.success,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingOtp = false);
        Fluttertoast.showToast(
          msg: e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: AppTheme.error,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          _canResend = true;
        }
      });
      return _resendTimer > 0;
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      Fluttertoast.showToast(
        msg: 'Please enter the complete 6-digit OTP',
        backgroundColor: AppTheme.error,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Step 1: Verify OTP via edge function
      final otpValid = await SupabaseService.instance.verifyOtp(
        _e164Phone,
        otp,
      );

      if (!otpValid) {
        if (mounted) {
          setState(() => _isVerifying = false);
          Fluttertoast.showToast(
            msg: 'Invalid OTP. Please check and try again.',
            backgroundColor: AppTheme.error,
            textColor: Colors.white,
          );
        }
        return;
      }

      // Step 2: Auto-lookup employee by phone number (no role filter)
      final employee = await SupabaseService.instance.verifyEmployeeByPhone(
        _e164Phone,
      );

      if (!mounted) return;

      if (employee == null) {
        setState(() => _isVerifying = false);
        Fluttertoast.showToast(
          msg:
              'No active employee found with this number. Please contact your administrator.',
          backgroundColor: AppTheme.error,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }

      // Step 3: Extract property name from joined data
      final propertyData = employee['hotel_property'] as Map<String, dynamic>?;
      final propertyName = propertyData?['name'] as String? ?? '';

      // Step 4: Build session
      SupabaseService.instance.buildSession(
        employee: employee,
        propertyName: propertyName,
      );

      final session = SupabaseService.instance.currentSession!;

      setState(() => _isVerifying = false);
      Fluttertoast.showToast(
        msg: 'Welcome back, ${session.fullName}!',
        backgroundColor: AppTheme.success,
        textColor: Colors.white,
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.roleBasedDashboardScreen,
        (route) => false,
        arguments: {
          'role': session.role,
          'employeeName': session.fullName,
          'propertyName': session.propertyName,
          'propertyId': session.propertyId,
          'serviceId': session.serviceDept,
          'empId': session.empId,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        Fluttertoast.showToast(
          msg: e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: AppTheme.error,
          textColor: Colors.white,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                color: AppTheme.onSurface,
                onPressed: () => _goToStep(0),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Container(
            //   width: 32,
            //   height: 32,
            //   decoration: BoxDecoration(
            //     gradient: const LinearGradient(
            //       colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
            //       begin: Alignment.topLeft,
            //       end: Alignment.bottomRight,
            //     ),
            //     borderRadius: BorderRadius.circular(9),
            //   ),
            //   child: Center(
            //     child: Text(
            //       'Z',
            //       style: GoogleFonts.plusJakartaSans(
            //         fontSize: 16,
            //         fontWeight: FontWeight.w800,
            //         color: Colors.white,
            //       ),
            //     ),
            //   ),
            // ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  'assets/images/icon-removebg-preview-1782753555857.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Concigo Desk',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 520 : double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  StepIndicatorWidget(
                    currentStep: _currentStep,
                    totalSteps: 2,
                    labels: const ['Phone', 'Verify'],
                    activeColor: _brandColor,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _stepTransitionController,
                      builder: (context, child) {
                        return SlideTransition(
                          position: _stepSlide,
                          child: FadeTransition(
                            opacity: _stepFade,
                            child: child,
                          ),
                        );
                      },
                      child: _buildCurrentStep(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _PhoneStep(
          controller: _phoneController,
          formKey: _phoneFormKey,
          countryCode: _countryCode,
          isSending: _isSendingOtp,
          brandColor: _brandColor,
          onCountryCodeChanged: (code) => setState(() => _countryCode = code),
          onSendOtp: _sendOtp,
        );
      case 1:
        return OtpInputWidget(
          otpControllers: _otpControllers,
          otpFocusNodes: _otpFocusNodes,
          phoneNumber: '$_countryCode ${_phoneController.text}',
          isVerifying: _isVerifying,
          canResend: _canResend,
          resendTimer: _resendTimer,
          roleColor: _brandColor,
          onVerify: _verifyOtp,
          onResend: () {
            if (_canResend) {
              for (final c in _otpControllers) {
                c.clear();
              }
              _goToStep(0);
            }
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline Phone Step Widget (replaces PhoneInputWidget — no propertyName needed)
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneStep extends StatelessWidget {
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;
  final String countryCode;
  final bool isSending;
  final Color brandColor;
  final Function(String) onCountryCodeChanged;
  final VoidCallback onSendOtp;

  const _PhoneStep({
    required this.controller,
    required this.formKey,
    required this.countryCode,
    required this.isSending,
    required this.brandColor,
    required this.onCountryCodeChanged,
    required this.onSendOtp,
  });

  static const List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'country': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'country': 'USA', 'flag': '🇺🇸'},
    {'code': '+44', 'country': 'UK', 'flag': '🇬🇧'},
    {'code': '+971', 'country': 'UAE', 'flag': '🇦🇪'},
    {'code': '+65', 'country': 'Singapore', 'flag': '🇸🇬'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Mobile Number',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll send a one-time password to verify your identity',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 32),
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile Number',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.outline, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: countryCode,
                          onChanged: (v) => onCountryCodeChanged(v!),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          borderRadius: BorderRadius.circular(12),
                          items: _countryCodes.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['code'],
                              child: Text(
                                '${c['flag']} ${c['code']}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: '10-digit number',
                          filled: true,
                          fillColor: AppTheme.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.outline,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: brandColor, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.error,
                              width: 1,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Phone number is required';
                          }
                          if (val.length < 10) {
                            return 'Enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSending ? null : onSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: brandColor.withAlpha(100),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isSending
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withAlpha(200),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sending OTP...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Send OTP',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.send_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
