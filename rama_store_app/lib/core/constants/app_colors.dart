import 'package:flutter/material.dart';

/// App color system for Samaur Mart:
/// Deep Indigo (#3525CD), Emerald Mint (#4EDEA3 / #006C49), Sleek Glass Surfaces.
class AppColors {
  // Primary Brand Colors
  static const Color primary = Color(0xFF6B1F28);          // Deep Luxury Maroon
  static const Color primaryContainer = Color(0xFF4A1218); // Dark Maroon
  static const Color primaryLight = Color(0xFF8A2E39);     // Surface Tint Maroon
  static const Color primaryFixedDim = Color(0xFFE8D0D3);  // Soft Muted Maroon

  // Secondary & Emerald Accents
  static const Color secondary = Color(0xFF006C49);        // Deep Emerald Mint CTA
  static const Color secondaryContainer = Color(0xFF6CF8BB);// Light Emerald Mint Container
  static const Color secondaryFixedDim = Color(0xFF4EDEA3); // Bright Emerald Accent
  static const Color secondaryFixed = Color(0xFF6FFBBE);    // Mint Highlight Tag

  // Gold & Amber Accents (Loyalty & Badges)
  static const Color primaryGold = Color(0xFFB8892B);     // Refined Store Gold
  static const Color primaryGoldLight = Color(0xFFD4B066);// Bright Gold Highlight
  static const Color primaryGoldDark = Color(0xFF8F681C); // Deep Muted Gold
  static const Color accentAmber = Color(0xFFD4B066);     // Star rating & badges

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8F9FF);      // Crisp clean backdrop
  static const Color surface = Color(0xFFFFFFFF);         // Pure white card surface
  static const Color surfaceLight = Color(0xFFF1F5F9);    // Subtle slate tint
  static const Color inputBackground = Color(0xFFF8FAFC); // Clean input fill
  static const Color cardBorder = Color(0xFFE2E8F0);      // Modern subtle border

  // Light Mode Explicit
  static const Color lightBackground = Color(0xFFF8F9FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);

  // Text Colors (High Contrast)
  static const Color textPrimary = Color(0xFF0F172A);     // Deep midnight slate
  static const Color textSecondary = Color(0xFF475569);   // Elegant muted slate
  static const Color textMuted = Color(0xFF94A3B8);       // Subtle helper text

  // Dark Variant Tokens
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Feedback & Status
  static const Color success = Color(0xFF10B981);         // Mint green
  static const Color warning = Color(0xFFF59E0B);         // Amber warning
  static const Color error = Color(0xFFBA1A1A);           // Red Error
  static const Color info = Color(0xFF3525CD);            // Indigo info
}

