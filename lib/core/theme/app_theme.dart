import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Core Palette
  static const Color background = Color(0xFF070709);
  static const Color surface = Color(0xFF131316);
  static const Color surfaceElevated = Color(0xFF1C1C21);
  static const Color surfaceHighlight = Color(0xFF26262D);
  static const Color border = Color(0xFF27272A);
  static const Color borderSubtle = Color(0xFF1E1E24);

  // Vivid Accents (Green Theme)
  static const Color neonGreen = Color(0xFF10B981);
  static const Color neonGreenLight = Color(0xFF34D399);
  static const Color neonGreenDark = Color(0xFF059669);
  static const Color neonLime = Color(0xFF84CC16);
  static const Color neonYellow = Color(0xFFFACC15);
  static const Color errorRed = Color(0xFFEF4444);

  // Precomputed Alpha Colors (eliminates runtime .withOpacity / shader allocations)
  static const Color neonGreenAlpha10 = Color(0x1A10B981);
  static const Color neonGreenAlpha12 = Color(0x1F10B981);
  static const Color neonGreenAlpha15 = Color(0x2610B981);
  static const Color neonGreenAlpha18 = Color(0x2E10B981);
  static const Color neonGreenAlpha20 = Color(0x3310B981);
  static const Color neonGreenAlpha30 = Color(0x4D10B981);
  static const Color neonGreenAlpha40 = Color(0x6610B981);
  static const Color neonGreenAlpha50 = Color(0x8010B981);
  static const Color neonLimeAlpha14 = Color(0x2484CC16);
  static const Color neonLimeAlpha15 = Color(0x2684CC16);
  static const Color neonLimeAlpha20 = Color(0x3384CC16);
  static const Color neonLimeAlpha35 = Color(0x5984CC16);
  static const Color borderSubtleAlpha30 = Color(0x4D1E1E24);
  static const Color borderSubtleAlpha50 = Color(0x801E1E24);

  // Aliases for backwards compatibility
  static const Color neonMagenta = neonGreen;
  static const Color neonMagentaLight = neonGreenLight;
  static const Color neonMagentaDark = neonGreenDark;

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);
  static const Color textDark = Color(0xFF09090B);

  // Pre-instantiated Text Styles (eliminates repeated GoogleFonts.inter() build allocations)
  static final TextStyle fontHeaderLarge = GoogleFonts.inter(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static final TextStyle fontSectionTitle = GoogleFonts.inter(
    color: textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
  );

  static final TextStyle fontCardTitle = GoogleFonts.inter(
    color: textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static final TextStyle fontBody = GoogleFonts.inter(
    color: textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  static final TextStyle fontMuted = GoogleFonts.inter(
    color: textMuted,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle fontPriceHero = GoogleFonts.inter(
    color: neonLime,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static final TextStyle fontBadge = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  // Gradients
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1F1F24),
      Color(0xFF121215),
    ],
  );

  static const LinearGradient elevatedCardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF27272E),
      Color(0xFF17171C),
    ],
  );

  static const LinearGradient neonGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF10B981),
      Color(0xFF059669),
    ],
  );

  static const LinearGradient neonMagentaGradient = neonGreenGradient;

  // Shadows
  static List<BoxShadow> neonGlow = [
    BoxShadow(
      color: neonGreen.withOpacity(0.45),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // ThemeData
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: neonGreen,
      colorScheme: const ColorScheme.dark(
        primary: neonGreen,
        onPrimary: Colors.white,
        secondary: neonLime,
        onSecondary: Colors.black,
        surface: surface,
        onSurface: textPrimary,
        error: errorRed,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.inter(
          color: textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: neonGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0B0B0E),
        selectedItemColor: neonGreen,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
