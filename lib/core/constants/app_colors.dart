import 'package:flutter/material.dart';

/// App-wide color constants
/// Apple-inspired Content-First Design with Clean Visual Language
/// Pure white backgrounds with minimal accent colors
/// Change colors here and they will apply throughout the entire app
class AppColors {
  // ============================================================
  // BACKGROUNDS - Pure White & System Grays
  // ============================================================

  /// Pure White - Primary surfaces, main backgrounds
  static const Color background = Color(0xFFFFFFFF);

  /// System Gray 6 - Secondary backgrounds, cards, elevated surfaces
  static const Color backgroundSecondary = Color(0xFFF2F2F7);

  /// System Gray 5 - Tertiary backgrounds, subtle containers
  static const Color backgroundTertiary = Color(0xFFE5E5EA);

  /// Pure White - Surface color (same as background)
  static const Color surface = Color(0xFFFFFFFF);

  /// System Gray 6 - Surface variant
  static const Color surfaceVariant = Color(0xFFF2F2F7);

  // ============================================================
  // TEXT - Label System
  // ============================================================

  /// Label - Primary text, main content (#000000)
  static const Color textPrimary = Color(0xFF000000);

  /// Secondary Label - Secondary text, descriptions (#3C3C43)
  static const Color textSecondary = Color(0xFF3C3C43);

  /// Tertiary Label - Tertiary text, subtle hints (#3C3C43 60% opacity)
  static const Color textTertiary = Color(0x993C3C43);

  /// Text on colored backgrounds
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ============================================================
  // ACCENTS - System Blue & Gray
  // ============================================================

  /// System Blue - Primary accent, interactive elements (#007AFF)
  static const Color primary = Color(0xFF007AFF);

  /// System Blue variants
  static const Color primaryLight = Color(0xFF5AC8FA);
  static const Color primaryDark = Color(0xFF0051D5);

  /// System Gray - Neutral accents (#8E8E93)
  static const Color secondary = Color(0xFF8E8E93);
  static const Color secondaryLight = Color(0xFFC7C7CC);
  static const Color secondaryDark = Color(0xFF636366);

  // ============================================================
  // SIDEBAR COLORS
  // ============================================================

  static const Color sidebarBackground = Color(0xFFFFFFFF);
  static const Color sidebarHover = Color(0xFFF2F2F7);
  static const Color sidebarSelected = Color(0xFFE5E5EA);
  static const Color sidebarText = Color(0xFF000000);
  static const Color sidebarTextSelected = Color(0xFF007AFF);
  static const Color sidebarBorder = Color(0xFFE5E5EA);
  static const Color sidebarAccent = Color(0xFF007AFF);

  // ============================================================
  // APPBAR COLORS
  // ============================================================

  static const Color appBarBackground = Color(0xFFFFFFFF);
  static const Color appBarText = Color(0xFF000000);
  static const Color appBarIcon = Color(0xFF000000);
  static const Color appBarBorder = Color(0xFFE5E5EA);

  // ============================================================
  // BORDERS & DIVIDERS
  // ============================================================

  /// System Gray 5 - Main borders
  static const Color border = Color(0xFFE5E5EA);

  /// System Gray 6 - Light borders
  static const Color borderLight = Color(0xFFF2F2F7);

  /// Divider color
  static const Color divider = Color(0xFFE5E5EA);

  // ============================================================
  // OVERLAY
  // ============================================================

  /// Semi-transparent black overlay
  static const Color overlay = Color(0x4D000000); // 30% black

  // ============================================================
  // STATUS COLORS - Vibrant but not overwhelming
  // ============================================================

  /// System Green - Success states
  static const Color success = Color(0xFF34C759);

  /// System Red - Error states
  static const Color error = Color(0xFFFF3B30);

  /// System Orange - Warning states
  static const Color warning = Color(0xFFFF9500);

  /// System Blue - Info states
  static const Color info = Color(0xFF007AFF);

  // ============================================================
  // UTILITY
  // ============================================================

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Private constructor to prevent instantiation
  AppColors._();
}
