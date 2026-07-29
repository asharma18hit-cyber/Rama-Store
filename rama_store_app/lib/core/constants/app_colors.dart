import 'package:flutter/material.dart';

/// App color system matching Google Stitch Design System & Rama Store aesthetic:
/// Deep Indigo (#3525CD), Emerald Mint (#4EDEA3 / #006C49), Sleek Glass Surfaces.
class AppColors {
  // Google Stitch Primary Colors
  static const Color primary = Color(0xFF3525CD);          // Deep Royal Indigo
  static const Color primaryContainer = Color(0xFF4F46E5); // Indigo Container
  static const Color primaryLight = Color(0xFF4D44E3);     // Surface Tint Indigo
  static const Color primaryFixedDim = Color(0xFFC3C0FF);  // Soft Muted Indigo

  // Google Stitch Secondary & Emerald Accents
  static const Color secondary = Color(0xFF006C49);        // Deep Emerald Mint CTA
  static const Color secondaryContainer = Color(0xFF6CF8BB);// Light Emerald Mint Container
  static const Color secondaryFixedDim = Color(0xFF4EDEA3); // Bright Emerald Accent
  static const Color secondaryFixed = Color(0xFF6FFBBE);    // Mint Highlight Tag

  // Gold & Amber Accents (Preserved for Loyalty & Badges)
  static const Color primaryGold = Color(0xFFD97706);     // Rich gold CTA
  static const Color primaryGoldLight = Color(0xFFF59E0B);// Bright amber highlight
  static const Color primaryGoldDark = Color(0xFFB45309); // Muted gold hover
  static const Color accentAmber = Color(0xFFFBBF24);     // Star rating & badges

  // Backgrounds & Glass Surfaces
  static const Color background = Color(0xFF0B0F19);      // Deep charcoal navy
  static const Color surface = Color(0xFF1E293B);         // Soft slate card surface
  static const Color surfaceLight = Color(0xFF334155);    // Interactive hover card surface
  static const Color inputBackground = Color(0xFF0F172A); // Dark input fill

  // Light Mode Google Stitch Colors
  static const Color lightBackground = Color(0xFFF8F9FA); // Google Stitch Clean Surface Bright
  static const Color lightSurface = Color(0xFFFFFFFF);    // Pure White Card
  static const Color lightSurfaceContainerLow = Color(0xFFF3F4F5);
  static const Color lightTextPrimary = Color(0xFF191C1D);
  static const Color lightTextSecondary = Color(0xFF464555);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);     // Warm off-white
  static const Color textSecondary = Color(0xFF94A3B8);   // Muted slate gray
  static const Color textMuted = Color(0xFF64748B);       // Subtle helper text

  // Feedback & Status
  static const Color success = Color(0xFF10B981);         // Mint green
  static const Color warning = Color(0xFFF59E0B);         // Amber warning
  static const Color error = Color(0xFFBA1A1A);           // Google Stitch Red Error
  static const Color info = Color(0xFF3525CD);            // Indigo info
}
