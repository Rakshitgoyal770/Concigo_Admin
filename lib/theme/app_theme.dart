import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Concigo Brand Colors ───────────────────────────────────────────────────
  // Primary: Deep Navy — premium, trustworthy, hospitality-grade
  static const Color primary = Color(0xFF0A1628);
  static const Color primaryLight = Color(0xFF1E3A5F);
  static const Color primaryContainer = Color(0xFFE8EFF8);
  static const Color primaryMuted = Color(0xFF6B8BB5);

  // Brand Gold — taken directly from Concigo logo mark
  static const Color brandGold = Color(0xFFD4A017);
  static const Color brandGoldLight = Color(0xFFF5C842);
  static const Color brandGoldContainer = Color(0xFFFFF8E7);

  static const Color secondary = Color(0xFF1E293B);
  static const Color secondaryContainer = Color(0xFFF1F5F9);

  // ── Semantic Colors ────────────────────────────────────────────────────────
  static const Color success = Color(0xFF0D9488);
  static const Color successContainer = Color(0xFFCCFBF1);
  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color pending = Color(0xFFF59E0B);
  static const Color pendingContainer = Color(0xFFFFF7ED);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoContainer = Color(0xFFE0F2FE);

  // ── Surface & Background ───────────────────────────────────────────────────
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color surfaceElevated = Color(0xFFF1F5F9);
  static const Color background = Color(0xFFF5F7FA);
  static const Color outline = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFFF1F5F9);
  static const Color onSurface = Color(0xFF0A1628);
  static const Color onSurfaceMuted = Color(0xFF64748B);
  static const Color onSurfaceVariant = Color(0xFF94A3B8);

  // ── Role Colors ────────────────────────────────────────────────────────────
  static const Color superAdminColor = Color(0xFF6D28D9);
  static const Color superAdminContainer = Color(0xFFF5F3FF);
  static const Color receptionColor = Color(0xFF0369A1);
  static const Color receptionContainer = Color(0xFFE0F2FE);
  // Service Manager: Warm amber-gold — matches Concigo brand identity
  static const Color managerColor = Color(0xFFB45309);
  static const Color managerContainer = Color(0xFFFFF7ED);
  static const Color employeeColor = Color(0xFF0D9488);
  static const Color employeeContainer = Color(0xFFCCFBF1);
  static const Color spaColor = Color(0xFFBE185D);
  static const Color spaContainer = Color(0xFFFCE7F3);
  static const Color laundryColor = Color(0xFF4F46E5);
  static const Color laundryContainer = Color(0xFFEEF2FF);

  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        secondaryContainer: secondaryContainer,
        surface: surface,
        error: error,
        errorContainer: errorContainer,
        onPrimary: Colors.white,
        onPrimaryContainer: primary,
        onSecondary: Colors.white,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceMuted,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: onSurface, letterSpacing: -0.8),
        displayMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, color: onSurface, letterSpacing: -0.3),
        headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: onSurface),
        headlineSmall: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
        titleLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: onSurface),
        titleMedium: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
        titleSmall: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: onSurface),
        bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w400, color: onSurface),
        bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
        bodySmall: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400, color: onSurfaceMuted),
        labelLarge: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
        labelMedium: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: onSurface, letterSpacing: 0.2),
        labelSmall: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: onSurfaceMuted, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withAlpha(12),
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: outline, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: error, width: 1.5)),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: onSurfaceMuted),
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: onSurfaceVariant),
        errorStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400, color: error),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: outline, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outlineVariant, thickness: 1, space: 0),
      drawerTheme: const DrawerThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topRight: Radius.circular(0), bottomRight: Radius.circular(0)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: onSurface,
        contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primaryContainer,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD4A017),
        primaryContainer: Color(0xFF1A2744),
        secondary: Color(0xFFE2E8F0),
        secondaryContainer: Color(0xFF1E293B),
        surface: Color(0xFF0F1C2E),
        error: Color(0xFFF87171),
        onPrimary: Color(0xFF0A1628),
        onPrimaryContainer: Color(0xFFD4A017),
        onSecondary: Color(0xFF0A1628),
        onSurface: Color(0xFFF1F5F9),
        onSurfaceVariant: Color(0xFF94A3B8),
        outline: Color(0xFF1E3A5F),
        outlineVariant: Color(0xFF0F1C2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF060E1A),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Color(0xFF0F1C2E),
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
    );
  }
}
