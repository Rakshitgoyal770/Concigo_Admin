import 'package:flutter/material.dart';

/// Five-Star Modern Hospitality Workstation Color System for Concigo
/// Theme: Modern Sapphire & Champagne Gold (Vibrant, Light, High-Clarity)
class AppColors {
  AppColors._();

  // Backgrounds & Surfaces (Airy Slate-Blue & Pure White Floating Cards)
  static const Color background = Color(0xFFF1F5F9);      // Soft Airy Slate-Blue (replaces stark white/gray)
  static const Color surface = Color(0xFFFFFFFF);         // Pure Crisp Floating White
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFE2E8F0);   // Crisp Clean Slate Fill
  static const Color surfaceHover = Color(0xFFEDF2F7);

  // Primary Brand Accent (Vibrant Royal Sapphire)
  static const Color primary = Color(0xFF1D4ED8);         // Vibrant Royal Sapphire Blue
  static const Color primaryLight = Color(0xFFEFF6FF);    // Soft Periwinkle Wash (glowing interactive state)
  static const Color primaryDark = Color(0xFF1E3A8A);     // Deep Sapphire
  static const Color primaryAccent = Color(0xFF2563EB);   // Active Sapphire Blue

  // Secondary Accent (Signature Champagne Gold / Warm Brass)
  static const Color brass = Color(0xFFD97706);           // Warm Radiant Gold
  static const Color brassLight = Color(0xFFFFFBEB);      // Soft Golden Cream Wash
  static const Color brassBorder = Color(0xFFFDE68A);     // Delicate Gold Border

  // Semantic Status Colors (Vibrant, Fresh & High-Clarity)
  static const Color success = Color(0xFF059669);         // Crisp Fresh Emerald (Vacant, Paid, Ready)
  static const Color successLight = Color(0xFFECFDF5);    // Soft Emerald Glow
  static const Color successBorder = Color(0xFFA7F3D0);

  static const Color attention = Color(0xFFD97706);       // Warm Amber (KYC Review, Cleaning in Progress)
  static const Color attentionLight = Color(0xFFFFFBEB);  // Soft Amber Glow
  static const Color attentionBorder = Color(0xFFFDE68A);

  static const Color departure = Color(0xFFDC2626);       // Crisp Rose Crimson (Checkout, Urgent, OOO)
  static const Color departureLight = Color(0xFFFEF2F2);  // Soft Rose Wash
  static const Color departureBorder = Color(0xFFFECACA);

  static const Color info = Color(0xFF0284C7);            // Sky Azure
  static const Color infoLight = Color(0xFFF0F9FF);
  static const Color infoBorder = Color(0xFFBAE6FD);

  static const Color purple = Color(0xFF7C3AED);          // Royal Purple (Upgrades & VIP)
  static const Color purpleLight = Color(0xFFF5F3FF);
  static const Color purpleBorder = Color(0xFFDDD6FE);

  // Typography & Content (Deep Slate Charcoal — high contrast, never dull)
  static const Color textPrimary = Color(0xFF0F172A);     // Deep Obsidian Slate
  static const Color textSecondary = Color(0xFF334155);   // Crisp Slate
  static const Color textMuted = Color(0xFF64748B);       // Cool Slate Gray
  static const Color textInverted = Color(0xFFFFFFFF);

  // Borders & Hairline Dividers (Soft Clean Contrast)
  static const Color border = Color(0xFFCBD5E1);          // Visible, Clean Slate Border
  static const Color borderSubtle = Color(0xFFE2E8F0);    // Micro Hairline
  static const Color borderFocus = Color(0xFF2563EB);     // Sapphire Focus Ring

  // Shadows (Soft, Natural Atmospheric Diffusion)
  static const BoxShadow shadowSm = BoxShadow(
    color: Color(0x0A0F172A),
    blurRadius: 4,
    offset: Offset(0, 1),
  );

  static const BoxShadow shadowMd = BoxShadow(
    color: Color(0x100F172A),
    blurRadius: 10,
    offset: Offset(0, 3),
  );

  static const BoxShadow shadowLg = BoxShadow(
    color: Color(0x180F172A),
    blurRadius: 20,
    offset: Offset(0, 6),
  );
}
