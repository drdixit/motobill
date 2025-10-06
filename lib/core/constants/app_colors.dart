import 'package:flutter/material.dart';

/// App-wide color constants
/// White and Black Theme with Minimal Gray Accents
/// Change colors here and they will apply throughout the entire app
class AppColors {
  // Primary Colors - Black Theme
  static const Color primary = Color(0xFF000000);
  static const Color primaryLight = Color(0xFF424242);
  static const Color primaryDark = Color(0xFF000000);

  // Secondary Colors - Dark Gray
  static const Color secondary = Color(0xFF212121);
  static const Color secondaryLight = Color(0xFF616161);
  static const Color secondaryDark = Color(0xFF000000);

  // Background Colors - White
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAFAFA);

  // Sidebar Colors - White with Black Text
  static const Color sidebarBackground = Color(0xFFFFFFFF);
  static const Color sidebarHover = Color(0xFFF5F5F5);
  static const Color sidebarSelected = Color(0xFFEEEEEE);
  static const Color sidebarText = Color(0xFF000000);
  static const Color sidebarTextSelected = Color(0xFF000000);
  static const Color sidebarBorder = Color(0xFFE0E0E0);

  // AppBar Colors
  static const Color appBarBackground = Color(0xFFFFFFFF);
  static const Color appBarText = Color(0xFF000000);
  static const Color appBarIcon = Color(0xFF000000);

  // Text Colors - Black on White
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Border Colors - Light Gray
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);
  static const Color divider = Color(0xFFEEEEEE);

  // Overlay Colors
  static const Color overlay = Color(0x4D000000); // 30% black

  // Status Colors - Minimal and Subtle
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Utility
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Private constructor to prevent instantiation
  AppColors._();
}
