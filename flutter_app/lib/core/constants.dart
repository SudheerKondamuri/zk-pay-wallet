import 'package:flutter/material.dart';

/// Verdigris design system — spacing, radii, and motion constants.
/// Every value used app-wide must come from here; nothing off-scale.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double card = 12;
  static const double button = 8;
  static const double input = 8;
  static const double bottomSheet = 24;

  static const BorderRadius cardBorder = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonBorder = BorderRadius.all(Radius.circular(button));
  static const BorderRadius inputBorder = BorderRadius.all(Radius.circular(input));
  static const BorderRadius bottomSheetBorder = BorderRadius.only(
    topLeft: Radius.circular(bottomSheet),
    topRight: Radius.circular(bottomSheet),
  );
}

abstract final class AppDuration {
  /// Sheet/dialog transitions.
  static const Duration sheet = Duration(milliseconds: 250);

  /// Micro-interactions (button press, toggle).
  static const Duration micro = Duration(milliseconds: 120);

  /// Balance polling interval.
  static const Duration balancePoll = Duration(seconds: 15);

  /// Rollup state polling interval (~8s).
  static const Duration statePoll = Duration(seconds: 8);
}

/// Spring curves — never linear tweens.
abstract final class AppCurves {
  static const Curve sheet = Curves.easeOutCubic;
  static const Curve micro = Curves.easeOutCubic;
}
