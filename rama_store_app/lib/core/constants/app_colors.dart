import 'package:flutter/material.dart';

/// App color system matching Rama Store's dark, ledger/bookshop aesthetic:
/// Deep charcoal/navy backgrounds, warm gold/amber accents, soft surfaces.
class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0B0F19);      // Deep charcoal navy
  static const Color surface = Color(0xFF1E293B);         // Soft slate card surface
  static const Color surfaceLight = Color(0xFF334155);    // Interactive hover/active card surface
  static const Color inputBackground = Color(0xFF0F172A); // Dark input fill

  // Gold & Amber Accents
  static const Color primaryGold = Color(0xFFD97706);     // Rich gold CTA
  static const Color primaryGoldLight = Color(0xFFF59E0B);// Bright amber highlight
  static const Color primaryGoldDark = Color(0xFFB45309); // Muted gold hover/pressed
  static const Color accentAmber = Color(0xFFFBBF24);     // Star rating & badges

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);     // Warm off-white
  static const Color textSecondary = Color(0xFF94A3B8);   // Muted slate gray
  static const Color textMuted = Color(0xFF64748B);       // Subtle helper text

  // Feedback & Status
  static const Color success = Color(0xFF10B981);         // Mint green
  static const Color warning = Color(0xFFF59E0B);         // Amber warning
  static const Color error = Color(0xFFEF4444);           // Vibrant red error
  static const Color info = Color(0xFF3B82F6);            // Sapphire blue

  // Light Mode Fallback Colors
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
}
