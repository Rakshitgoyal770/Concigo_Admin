import 'package:flutter/material.dart';

/// Five-Star Luxury Hospitality Workstation Color System for Concigo
class AppColors {
  AppColors._();

  // Backgrounds & Surfaces (Warm Ivory / Pearl & Crisp White)
  static const Color background = Color(0xFFF7F5F1); // Warm Ivory / Pearl
  static const Color surface = Color(0xFFFFFFFF);    // Pure Crisp White
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFEFECE6); // Warm Pearl fill
  static const Color surfaceHover = Color(0xFFF2EFE9);

  // Primary Brand Accent (Deep Sophisticated Teal)
  static const Color primary = Color(0xFF174A4A);       // Deep Luxury Teal
  static const Color primaryLight = Color(0xFFEBF2F2);  // Soft Teal Wash
  static const Color primaryDark = Color(0xFF0F3434);
  static const Color primaryAccent = Color(0xFF1F5E5E);

  // Secondary Accent (Muted Champagne / Warm Brass)
  static const Color brass = Color(0xFFB79A68);         // Warm Brass
  static const Color brassLight = Color(0xFFF7F3EB);
  static const Color brassBorder = Color(0xFFE5D7C0);

  // Semantic Status Colors (Muted, Sophisticated & Non-Jarring)
  static const Color success = Color(0xFF5D8A72);       // Muted Sage (Checked In, Paid, Ready)
  static const Color successLight = Color(0xFFEEF5F1);
  static const Color successBorder = Color(0xFFC8E0D2);

  static const Color attention = Color(0xFFB88746);     // Muted Amber (KYC Review, Cleaning)
  static const Color attentionLight = Color(0xFFFDF7EE);
  static const Color attentionBorder = Color(0xFFEED8B8);

  static const Color departure = Color(0xFF9B4B52);     // Muted Burgundy (Checkout, Folio Pending, Urgent)
  static const Color departureLight = Color(0xFFFBF1F2);
  static const Color departureBorder = Color(0xFFE8C5C8);

  static const Color info = Color(0xFF3F6E7A);          // Muted Ocean / Slate
  static const Color infoLight = Color(0xFFEDF4F6);
  static const Color infoBorder = Color(0xFFC4DCE2);

  static const Color purple = Color(0xFF6B5B95);        // Upgrades & Privilege
  static const Color purpleLight = Color(0xFFF4F2F8);
  static const Color purpleBorder = Color(0xFFD8D2E8);

  // Typography & Content (Deep Charcoal & Refined Warm Grays)
  static const Color textPrimary = Color(0xFF202522);   // Deep Charcoal
  static const Color textSecondary = Color(0xFF66706A); // Refined Slate Gray
  static const Color textMuted = Color(0xFF919B95);     // Muted Gray
  static const Color textInverted = Color(0xFFFFFFFF);

  // Borders & Hairline Dividers
  static const Color border = Color(0xFFE6E2DC);        // Warm Subtle Hairline Border
  static const Color borderSubtle = Color(0xFFEFECE7);  // Micro Divider
  static const Color borderFocus = Color(0xFF174A4A);

  // Shadows (Soft, Natural Diffusion)
  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0x08202522),
    blurRadius: 4,
    offset: Offset(0, 1),
  );

  static const BoxShadow shadowMd = BoxShadow(
    color: Color(0x0C202522),
    blurRadius: 10,
    offset: Offset(0, 3),
  );

  static const BoxShadow shadowLg = BoxShadow(
    color: Color(0x10202522),
    blurRadius: 20,
    offset: Offset(0, 6),
  );
}
