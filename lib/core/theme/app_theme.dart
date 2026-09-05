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
  });

  bool get isDark => brightness == Brightness.dark;

  // Computed Alpha Tokens (Derived dynamically from theme colors)
  Color get neonGreenAlpha08 => neonGreen.withValues(alpha: 0.08);
  Color get neonGreenAlpha10 => neonGreen.withValues(alpha: 0.10);
  Color get neonGreenAlpha12 => neonGreen.withValues(alpha: 0.12);
  Color get neonGreenAlpha14 => neonGreen.withValues(alpha: 0.14);
  Color get neonGreenAlpha15 => neonGreen.withValues(alpha: 0.15);
  Color get neonGreenAlpha18 => neonGreen.withValues(alpha: 0.18);
  Color get neonGreenAlpha20 => neonGreen.withValues(alpha: 0.20);
  Color get neonGreenAlpha22 => neonGreen.withValues(alpha: 0.22);
  Color get neonGreenAlpha30 => neonGreen.withValues(alpha: 0.30);
  Color get neonGreenAlpha35 => neonGreen.withValues(alpha: 0.35);
  Color get neonGreenAlpha40 => neonGreen.withValues(alpha: 0.40);
  Color get neonGreenAlpha45 => neonGreen.withValues(alpha: 0.45);
  Color get neonGreenAlpha50 => neonGreen.withValues(alpha: 0.50);

  Color get neonLimeAlpha12 => neonLime.withValues(alpha: 0.12);
  Color get neonLimeAlpha14 => neonLime.withValues(alpha: 0.14);
  Color get neonLimeAlpha15 => neonLime.withValues(alpha: 0.15);
  Color get neonLimeAlpha20 => neonLime.withValues(alpha: 0.20);
  Color get neonLimeAlpha30 => neonLime.withValues(alpha: 0.30);
  Color get neonLimeAlpha35 => neonLime.withValues(alpha: 0.35);

  Color get borderSubtleAlpha30 => borderSubtle.withValues(alpha: 0.30);
  Color get borderSubtleAlpha50 => borderSubtle.withValues(alpha: 0.50);
  Color get borderSubtleAlpha60 => borderSubtle.withValues(alpha: 0.60);

  Color get errorRedAlpha12 => errorRed.withValues(alpha: 0.12);
  Color get errorRedAlpha30 => errorRed.withValues(alpha: 0.30);

  Color get neonYellowAlpha14 => neonYellow.withValues(alpha: 0.14);
  Color get neonYellowAlpha28 => neonYellow.withValues(alpha: 0.28);
}

class AppTheme {
  AppTheme._();

  // Core Dark Palette Constants (Backwards Compatibility)
  static const Color background = Color(0xFF0A0F0D);
  static const Color surface = Color(0xFF121A16);
  static const Color surfaceElevated = Color(0xFF1B2620);
  static const Color surfaceHighlight = Color(0xFF26262D);
  static const Color border = Color(0xFF27272A);
  static const Color borderSubtle = Color(0xFF1E1E24);

  // Vivid Accents
  static const Color neonGreen = Color(0xFF00E599);
  static const Color neonGreenLight = Color(0xFF34D399);
  static const Color neonGreenDark = Color(0xFF059669);
  static const Color neonLime = Color(0xFFCCFF00);
  static const Color neonYellow = Color(0xFFFACC15);
  static const Color errorRed = Color(0xFFEF4444);

  // Precomputed Alpha Colors (Dark)
  static const Color neonGreenAlpha10 = Color(0x1A00E599);
  static const Color neonGreenAlpha12 = Color(0x1F00E599);
  static const Color neonGreenAlpha15 = Color(0x2600E599);
  static const Color neonGreenAlpha18 = Color(0x2E00E599);
  static const Color neonGreenAlpha20 = Color(0x3300E599);
  static const Color neonGreenAlpha30 = Color(0x4D00E599);
  static const Color neonGreenAlpha40 = Color(0x6600E599);
  static const Color neonGreenAlpha50 = Color(0x8000E599);
  static const Color neonLimeAlpha14 = Color(0x24CCFF00);
  static const Color neonLimeAlpha15 = Color(0x26CCFF00);
  static const Color neonLimeAlpha20 = Color(0x33CCFF00);
  static const Color neonLimeAlpha35 = Color(0x59CCFF00);
  static const Color borderSubtleAlpha30 = Color(0x4D1E1E24);
  static const Color borderSubtleAlpha50 = Color(0x801E1E24);
  static const Color borderSubtleAlpha60 = Color(0x991E1E24);
  static const Color errorRedAlpha12 = Color(0x1FEF4444);
  static const Color errorRedAlpha30 = Color(0x4DEF4444);
  static const Color neonLimeAlpha12 = Color(0x1FCCFF00);
  static const Color neonLimeAlpha30 = Color(0x4DCCFF00);
  static const Color neonGreenAlpha08 = Color(0x1400E599);
  static const Color neonGreenAlpha14 = Color(0x2400E599);
  static const Color neonGreenAlpha22 = Color(0x3800E599);
  static const Color neonGreenAlpha35 = Color(0x5900E599);
  static const Color neonGreenAlpha45 = Color(0x7300E599);
  static const Color neonYellowAlpha14 = Color(0x24FACC15);
  static const Color neonYellowAlpha28 = Color(0x47FACC15);
  static const Color blackAlpha35 = Color(0x59000000);
  static const Color blackAlpha50 = Color(0x80000000);
  static const Color blackAlpha75 = Color(0xBF000000);
  static const Color surfaceElevatedAlpha60 = Color(0x991B2620);

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
  static final TextStyle fontHeaderLarge = GoogleFonts.plusJakartaSans(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static final TextStyle fontSectionTitle = GoogleFonts.plusJakartaSans(
    color: textPrimary,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
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

  static final TextStyle fontPriceHero = GoogleFonts.plusJakartaSans(
    color: neonLime,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static final TextStyle fontBadge = GoogleFonts.plusJakartaSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  // Athletic Sports-Tech Telemetry Typography (Playtomic / Strava benchmark)
  static final TextStyle fontTelemetryHero = GoogleFonts.plusJakartaSans(
    color: textPrimary,
    fontSize: 38,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
  );

  static final TextStyle fontTelemetryValue = GoogleFonts.plusJakartaSans(
    color: textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static final TextStyle fontTelemetryLabel = GoogleFonts.plusJakartaSans(
    color: textMuted,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  static final TextStyle fontSportsBadge = GoogleFonts.plusJakartaSans(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  static final TextStyle fontMonospaceValue = GoogleFonts.robotoMono(
    color: neonLime,
    fontSize: 13,
    fontWeight: FontWeight.w700,
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
    background: Color(0xFF0A0F0D),
    surface: Color(0xFF121A16),
    surfaceElevated: Color(0xFF1B2620),
    surfaceHighlight: Color(0xFF26262D),
    border: Color(0xFF27272A),
    borderSubtle: Color(0xFF1E1E24),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA1A1AA),
    textMuted: Color(0xFF71717A),
    neonGreen: Color(0xFF00E599),
    neonGreenLight: Color(0xFF34D399),
    neonGreenDark: Color(0xFF059669),
    neonLime: Color(0xFFCCFF00),
    neonYellow: Color(0xFFFACC15),
    errorRed: Color(0xFFEF4444),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B2620), Color(0xFF121A16)],
    ),
    elevatedCardGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF23322B), Color(0xFF1B2620)],
    ),
    cardShadow: [
      BoxShadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 8)),
    ],
    neonGlow: [
      BoxShadow(color: Color(0x7300E599), blurRadius: 20, offset: Offset(0, 4)),
    ],
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
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: neonGreen,
        onPrimary: Colors.white,
        secondary: neonLime,
        surface: surface,
        error: errorRed,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
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
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderSubtle),
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
          side: const BorderSide(color: borderSubtle),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: neonGreen,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData _buildLightTheme() {
    const p = lightPalette;

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme.light(
        primary: p.neonGreen,
        secondary: p.neonLime,
        onSecondary: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: p.errorRed,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: p.textPrimary,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          color: p.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: p.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
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
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
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
          side: BorderSide(color: p.border),
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
