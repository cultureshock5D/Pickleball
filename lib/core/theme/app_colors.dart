import 'package:flutter/material.dart';

/// Design tokens from C&J Pickleball UI/UX Specification (UI-Context.md)
/// Editorial Athletic Luxury monochrome palette with high-impact accents.
abstract class AppColors {
  // --- Core Monochrome ---
  static const Color ink = Color(0xFF111111); // Primary text & dark accents
  static const Color canvas = Color(0xFFFFFFFF); // Primary background
  static const Color softCloud = Color(0xFFF5F5F5); // Secondary surface / muted fill
  static const Color charcoal = Color(0xFF39393B); // Secondary dark
  static const Color ash = Color(0xFF4B4B4D); // Mid-dark neutral
  static const Color mute = Color(0xFF707072); // Subtitles & helper text
  static const Color stone = Color(0xFF9E9EA0); // Light neutral text
  static const Color hairline = Color(0xFFCACACB); // Card borders & dividers
  static const Color hairlineSoft = Color(0xFFE5E5E5); // Inset borders & tracks

  // --- Semantic Accents ---
  static const Color courtSuccess = Color(0xFF007D48); // Confirmed / Open slot green
  static const Color successBright = Color(0xFF1EAA52); // Active pill badge
  static const Color saleRed = Color(0xFFD30005); // Error / Cancellation red
  static const Color saleDeep = Color(0xFF780700); // Deep alert dark
  static const Color infoBlue = Color(0xFF1151FF); // Info / links
  static const Color warningAmber = Color(0xFFE65100); // Almost full slot status

  // --- Court Surface Colors (Visualizer) ---
  static const Color courtBlue = Color(0xFF1E3A5F); // Court 1 surface
  static const Color courtNavy = Color(0xFF2B3244); // Court 2 surface
  static const Color kitchenGreen = Color(0xFF007D48); // Non-volley zone
}
