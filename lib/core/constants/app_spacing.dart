import 'package:flutter/material.dart';

/// Luxury Spacing, Sizing, and Radii Constants
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // Border Radii
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius roundedFull = BorderRadius.all(Radius.circular(radiusFull));

  // Gaps
  static const SizedBox gapH4 = SizedBox(width: 4);
  static const SizedBox gapH8 = SizedBox(width: 8);
  static const SizedBox gapH12 = SizedBox(width: 12);
  static const SizedBox gapH16 = SizedBox(width: 16);
  static const SizedBox gapH20 = SizedBox(width: 20);
  static const SizedBox gapH24 = SizedBox(width: 24);

  static const SizedBox gapV4 = SizedBox(height: 4);
  static const SizedBox gapV8 = SizedBox(height: 8);
  static const SizedBox gapV12 = SizedBox(height: 12);
  static const SizedBox gapV16 = SizedBox(height: 16);
  static const SizedBox gapV20 = SizedBox(height: 20);
  static const SizedBox gapV24 = SizedBox(height: 24);
  static const SizedBox gapV32 = SizedBox(height: 32);
}
