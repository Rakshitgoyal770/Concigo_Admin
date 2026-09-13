import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Editorial Luxury Hospitality Typography Scale
/// Uses Plus Jakarta Sans for refined UI hierarchy and JetBrains Mono for rooms & financials.
class AppTypography {
  AppTypography._();

  // Primary Operational Display Numbers (KPI counts: 18 Available, 05 Arrivals)
  static TextStyle displayNumber = GoogleFonts.plusJakartaSans(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static TextStyle display = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle titleLarge = GoogleFonts.plusJakartaSans(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle titleMedium = GoogleFonts.plusJakartaSans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static TextStyle titleSmall = GoogleFonts.plusJakartaSans(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle bodyLarge = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.45,
  );

  static TextStyle bodyMedium = GoogleFonts.plusJakartaSans(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle bodySmall = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  static TextStyle labelLarge = GoogleFonts.plusJakartaSans(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle labelMedium = GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle labelSmall = GoogleFonts.plusJakartaSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.3,
  );

  // Monospace for Room Numbers & Financial Figures
  static TextStyle monoRoom = GoogleFonts.jetBrainsMono(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static TextStyle monoAmount = GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle monoMetric = GoogleFonts.jetBrainsMono(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle monoSmall = GoogleFonts.jetBrainsMono(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
