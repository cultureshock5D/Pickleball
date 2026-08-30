import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceHighlight;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color neonGreen;
  final Color neonGreenLight;
  final Color neonGreenDark;
  final Color neonLime;
  final Color neonYellow;
  final Color errorRed;
  final LinearGradient cardGradient;
  final LinearGradient elevatedCardGradient;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> neonGlow;

  // Alphas
  final Color neonGreenAlpha10;
  final Color neonGreenAlpha12;
  final Color neonGreenAlpha15;
  final Color neonGreenAlpha18;
  final Color neonGreenAlpha20;
  final Color neonGreenAlpha30;
  final Color neonGreenAlpha40;
  final Color neonGreenAlpha50;
  final Color neonLimeAlpha14;
  final Color neonLimeAlpha15;
  final Color neonLimeAlpha20;
  final Color neonLimeAlpha35;
  final Color borderSubtleAlpha30;
  final Color borderSubtleAlpha50;
  final Color borderSubtleAlpha60;
  final Color errorRedAlpha12;
  final Color errorRedAlpha30;
  final Color neonLimeAlpha12;
  final Color neonLimeAlpha30;
  final Color neonGreenAlpha08;
  final Color neonGreenAlpha14;
  final Color neonGreenAlpha22;
  final Color neonGreenAlpha35;
  final Color neonGreenAlpha45;
  final Color neonYellowAlpha14;
  final Color neonYellowAlpha28;

  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceHighlight,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.neonGreen,
    required this.neonGreenLight,
    required this.neonGreenDark,
    required this.neonLime,
    required this.neonYellow,
    required this.errorRed,
    required this.cardGradient,
    required this.elevatedCardGradient,
    required this.cardShadow,
    required this.neonGlow,
    required this.neonGreenAlpha10,
    required this.neonGreenAlpha12,
    required this.neonGreenAlpha15,
    required this.neonGreenAlpha18,
    required this.neonGreenAlpha20,
    required this.neonGreenAlpha30,
    required this.neonGreenAlpha40,
    required this.neonGreenAlpha50,
    required this.neonLimeAlpha14,
    required this.neonLimeAlpha15,
    required this.neonLimeAlpha20,
    required this.neonLimeAlpha35,
    required this.borderSubtleAlpha30,
    required this.borderSubtleAlpha50,
    required this.borderSubtleAlpha60,
    required this.errorRedAlpha12,
    required this.errorRedAlpha30,
    required this.neonLimeAlpha12,
    required this.neonLimeAlpha30,
    required this.neonGreenAlpha08,
    required this.neonGreenAlpha14,
    required this.neonGreenAlpha22,
    required this.neonGreenAlpha35,
    required this.neonGreenAlpha45,
    required this.neonYellowAlpha14,
    required this.neonYellowAlpha28,
  });

  bool get isDark => brightness == Brightness.dark;
}

class AppTheme {
  AppTheme._();

  // Core Dark Palette Constants (Backwards Compatibility)
  static const Color background = Color(0xFF070709);
  static const Color surface = Color(0xFF131316);
  static const Color surfaceElevated = Color(0xFF1C1C21);
  static const Color surfaceHighlight = Color(0xFF26262D);
  static const Color border = Color(0xFF27272A);
  static const Color borderSubtle = Color(0xFF1E1E24);

  // Vivid Accents
  static const Color neonGreen = Color(0xFF10B981);
  static const Color neonGreenLight = Color(0xFF34D399);
  static const Color neonGreenDark = Color(0xFF059669);
  static const Color neonLime = Color(0xFF84CC16);
  static const Color neonYellow = Color(0xFFFACC15);
  static const Color errorRed = Color(0xFFEF4444);

  // Precomputed Alpha Colors (Dark)
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
  static const Color borderSubtleAlpha60 = Color(0x991E1E24);
  static const Color errorRedAlpha12 = Color(0x1FEF4444);
  static const Color errorRedAlpha30 = Color(0x4DEF4444);
  static const Color neonLimeAlpha12 = Color(0x1F84CC16);
  static const Color neonLimeAlpha30 = Color(0x4D84CC16);
  static const Color neonGreenAlpha08 = Color(0x1410B981);
  static const Color neonGreenAlpha14 = Color(0x2410B981);
  static const Color neonGreenAlpha22 = Color(0x3810B981);
  static const Color neonGreenAlpha35 = Color(0x5910B981);
  static const Color neonGreenAlpha45 = Color(0x7310B981);
  static const Color neonYellowAlpha14 = Color(0x24FACC15);
  static const Color neonYellowAlpha28 = Color(0x47FACC15);
  static const Color blackAlpha35 = Color(0x59000000);
  static const Color blackAlpha50 = Color(0x80000000);
  static const Color blackAlpha75 = Color(0xBF000000);
  static const Color surfaceElevatedAlpha60 = Color(0x991C1C21);

  // Aliases for backwards compatibility
  static const Color neonMagenta = neonGreen;
  static const Color neonMagentaLight = neonGreenLight;
  static const Color neonMagentaDark = neonGreenDark;

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);
  static const Color textDark = Color(0xFF09090B);

  // Pre-instantiated Text Styles
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
  static const List<BoxShadow> neonGlow = [
    BoxShadow(
      color: neonGreenAlpha45,
      blurRadius: 20,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: blackAlpha50,
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  // -------------------------------------------------------------
  // Palettes (Dark & Light)
  // -------------------------------------------------------------
  static const AppPalette darkPalette = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF070709),
    surface: Color(0xFF131316),
    surfaceElevated: Color(0xFF1C1C21),
    surfaceHighlight: Color(0xFF26262D),
    border: Color(0xFF27272A),
    borderSubtle: Color(0xFF1E1E24),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    neonGreen: Color(0xFF10B981),
    neonGreenLight: Color(0xFF34D399),
    neonGreenDark: Color(0xFF059669),
    neonLime: Color(0xFF84CC16),
    neonYellow: Color(0xFFFACC15),
    errorRed: Color(0xFFEF4444),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1F1F24), Color(0xFF121215)],
    ),
    elevatedCardGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF27272E), Color(0xFF17171C)],
    ),
    cardShadow: [
      BoxShadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 8)),
    ],
    neonGlow: [
      BoxShadow(color: Color(0x7310B981), blurRadius: 20, offset: Offset(0, 4)),
    ],
    neonGreenAlpha10: Color(0x1A10B981),
    neonGreenAlpha12: Color(0x1F10B981),
    neonGreenAlpha15: Color(0x2610B981),
    neonGreenAlpha18: Color(0x2E10B981),
    neonGreenAlpha20: Color(0x3310B981),
    neonGreenAlpha30: Color(0x4D10B981),
    neonGreenAlpha40: Color(0x6610B981),
    neonGreenAlpha50: Color(0x8010B981),
    neonLimeAlpha14: Color(0x2484CC16),
    neonLimeAlpha15: Color(0x2684CC16),
    neonLimeAlpha20: Color(0x3384CC16),
    neonLimeAlpha35: Color(0x5984CC16),
    borderSubtleAlpha30: Color(0x4D1E1E24),
    borderSubtleAlpha50: Color(0x801E1E24),
    borderSubtleAlpha60: Color(0x991E1E24),
    errorRedAlpha12: Color(0x1FEF4444),
    errorRedAlpha30: Color(0x4DEF4444),
    neonLimeAlpha12: Color(0x1F84CC16),
    neonLimeAlpha30: Color(0x4D84CC16),
    neonGreenAlpha08: Color(0x1410B981),
    neonGreenAlpha14: Color(0x2410B981),
    neonGreenAlpha22: Color(0x3810B981),
    neonGreenAlpha35: Color(0x5910B981),
    neonGreenAlpha45: Color(0x7310B981),
    neonYellowAlpha14: Color(0x24FACC15),
    neonYellowAlpha28: Color(0x47FACC15),
  );

  static const AppPalette lightPalette = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF8FAFC), // Crisp luxury porcelain
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    surfaceHighlight: Color(0xFFE2E8F0),
    border: Color(0xFFE2E8F0),
    borderSubtle: Color(0xFFCBD5E1),
    textPrimary: Color(0xFF0F172A), // Deep Slate
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    neonGreen: Color(0xFF059669), // Emerald 600 for crisp light contrast
    neonGreenLight: Color(0xFF10B981),
    neonGreenDark: Color(0xFF047857),
    neonLime: Color(0xFF65A30D), // Lime 600
    neonYellow: Color(0xFFCA8A04),
    errorRed: Color(0xFFDC2626),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    ),
    elevatedCardGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
    ),
    cardShadow: [
      BoxShadow(color: Color(0x0C0F172A), blurRadius: 16, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x060F172A), blurRadius: 4, offset: Offset(0, 1)),
    ],
    neonGlow: [
      BoxShadow(color: Color(0x33059669), blurRadius: 16, offset: Offset(0, 4)),
    ],
    neonGreenAlpha10: Color(0x1A059669),
    neonGreenAlpha12: Color(0x1F059669),
    neonGreenAlpha15: Color(0x26059669),
    neonGreenAlpha18: Color(0x2E059669),
    neonGreenAlpha20: Color(0x33059669),
    neonGreenAlpha30: Color(0x4D059669),
    neonGreenAlpha40: Color(0x66059669),
    neonGreenAlpha50: Color(0x80059669),
    neonLimeAlpha14: Color(0x2465A30D),
    neonLimeAlpha15: Color(0x2665A30D),
    neonLimeAlpha20: Color(0x3365A30D),
    neonLimeAlpha35: Color(0x5965A30D),
    borderSubtleAlpha30: Color(0x4DCBD5E1),
    borderSubtleAlpha50: Color(0x80CBD5E1),
    borderSubtleAlpha60: Color(0x99CBD5E1),
    errorRedAlpha12: Color(0x1FDC2626),
    errorRedAlpha30: Color(0x4DDC2626),
    neonLimeAlpha12: Color(0x1F65A30D),
    neonLimeAlpha30: Color(0x4D65A30D),
    neonGreenAlpha08: Color(0x14059669),
    neonGreenAlpha14: Color(0x24059669),
    neonGreenAlpha22: Color(0x38059669),
    neonGreenAlpha35: Color(0x59059669),
    neonGreenAlpha45: Color(0x73059669),
    neonYellowAlpha14: Color(0x24CA8A04),
    neonYellowAlpha28: Color(0x47CA8A04),
  );

  /// Helper to get current adaptive palette from context
  static AppPalette colorsOf(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkPalette : lightPalette;
  }

  // -------------------------------------------------------------
  // Cached ThemeData Definitions
  // -------------------------------------------------------------
  static final ThemeData darkTheme = _buildDarkTheme();
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildDarkTheme() {
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

  static ThemeData _buildLightTheme() {
    final p = lightPalette;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: p.background,
      primaryColor: p.neonGreen,
      colorScheme: ColorScheme.light(
        primary: p.neonGreen,
        onPrimary: Colors.white,
        secondary: p.neonLime,
        onSecondary: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: p.errorRed,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.inter(
          color: p.textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.inter(
          color: p.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.inter(
          color: p.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: p.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.inter(
          color: p.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.inter(
          color: p.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: GoogleFonts.inter(
          color: p.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.inter(
          color: p.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: GoogleFonts.inter(
          color: p.textSecondary,
          fontSize: 14,
        ),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.neonGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.errorRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.errorRed, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.border, width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.neonGreen,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

/// Extension on BuildContext for effortless palette access
extension AppThemeContextExtension on BuildContext {
  AppPalette get colors => AppTheme.colorsOf(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
