import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class OtpInputWidget extends StatelessWidget {
  final List<TextEditingController> otpControllers;
  final List<FocusNode> otpFocusNodes;
  final String phoneNumber;
  final bool isVerifying;
  final bool canResend;
  final int resendTimer;
  final Color roleColor;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  const OtpInputWidget({
    super.key,
    required this.otpControllers,
    required this.otpFocusNodes,
    required this.phoneNumber,
    required this.isVerifying,
    required this.canResend,
    required this.resendTimer,
    required this.roleColor,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify OTP',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              text: 'Enter the 6-digit code sent to ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.onSurfaceMuted,
              ),
              children: [
                TextSpan(
                  text: phoneNumber,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return _OtpBox(
                controller: otpControllers[i],
                focusNode: otpFocusNodes[i],
                roleColor: roleColor,
                onChanged: (val) {
                  if (val.length == 1 && i < 5) {
                    otpFocusNodes[i + 1].requestFocus();
                  } else if (val.isEmpty && i > 0) {
                    otpFocusNodes[i - 1].requestFocus();
                  }
                  if (i == 5 && val.length == 1) {
                    FocusScope.of(context).unfocus();
                  }
                },
              );
            }),
          ),

          const SizedBox(height: 28),

          // Resend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Didn\'t receive the code? ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.onSurfaceMuted,
                ),
              ),
              GestureDetector(
                onTap: canResend ? onResend : null,
                child: Text(
                  canResend ? 'Resend OTP' : 'Resend in ${resendTimer}s',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: canResend ? roleColor : AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isVerifying ? null : onVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: roleColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: roleColor.withAlpha(100),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isVerifying
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
                          'Verifying...',
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
                          'Verify & Login',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.verified_rounded, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color roleColor;
  final Function(String) onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.roleColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.onSurface,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppTheme.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.outline, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: roleColor, width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
