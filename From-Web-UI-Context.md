# C&J Pickleball — Flutter User-Side UI/UX Specification & AI Prompt Blueprint

This document translates the complete **client-facing Next.js web application** into an exhaustive, production-grade **Flutter Mobile Implementation Blueprint & AI Prompt System**. Use this document directly as context or copy individual prompts into your Flutter project or AI coding agent.

---

## 📑 Table of Contents

1. [Visual Identity & Design Philosophy](#1-visual-identity--design-philosophy)
2. [Color Palette & Flutter Design Tokens](#2-color-palette--flutter-design-tokens)
3. [ThemeData & Typography System](#3-themedata--typography-system)
4. [Vector Monogram & Custom Canvas Painters](#4-vector-monogram--custom-canvas-painters)
5. [Reusable Core UI Component Blueprints](#5-reusable-core-ui-component-blueprints)
6. [Screen-by-Screen UI/UX Specifications](#6-screen-by-screen-uiux-specifications)
   - [Screen 1: Landing / Home (`/`)](#screen-1-landing--home-)
   - [Screen 2: Real-Time Court Booking (`/book`)](#screen-2-real-time-court-booking-book)
   - [Screen 3: Confirmation & Digital QR Ticket Pass (`/booking/success/:id`)](#screen-3-confirmation--digital-qr-ticket-pass-bookingsuccessid)
   - [Screen 4: Player Portal / Dashboard (`/dashboard`)](#screen-4-player-portal--dashboard-dashboard)
   - [Screen 5: Cancellation & Refund Bottom Sheet](#screen-5-cancellation--refund-bottom-sheet)
   - [Screen 6: Auth Screens (Login, Sign Up, Forgot Password)](#screen-6-auth-screens-login-sign-up-forgot-password)
7. [Modular Copy-Paste AI Implementation Prompts](#7-modular-copy-paste-ai-implementation-prompts)
8. [Flutter Project Architecture & Dependencies (`pubspec.yaml`)](#8-flutter-project-architecture--dependencies-pubspecyaml)

---

## 1. Visual Identity & Design Philosophy

The C&J Pickleball mobile client replicates an **Editorial Athletic Luxury** aesthetic (inspired by Nike Lab, Aimé Leon Dore, and tournament athletics):

1. **Monochrome Dominance with High-Impact Contrast**: Pure white canvas (`#FFFFFF`) against deep ink black (`#111111`), delineated by crisp 1px hairline borders (`#CACACB` / `#E5E5E5`).
2. **Dual Geometry Language**:
   - **Structural Containers**: Sharp brutalist 0px radius (`BorderRadius.zero`) with 1px hairline borders.
   - **Interactive Elements**: Stadium pill geometry (`BorderRadius.circular(9999)` / `StadiumBorder()`) for buttons, status chips, duration pickers, and text inputs.
3. **Athletic Campaign Typography**:
   - **Display / Hero / Headings**: `Bebas Neue` (condensed, uppercase, tracking-tight, line-height 0.88–0.95).
   - **Body / Subtitles / Badges**: `Inter` / `Roboto` (clean geometric sans-serif, -0.01em tracking).
4. **Tactile Micro-Interactions**:
   - Active tap compression (`transform: scale(0.96)`) on all interactive cards and buttons.
   - Perforated physical ticket pass with live SVG/Canvas QR generation for front-desk check-in.
   - Confetti particle explosion upon successful payment verification.
   - Interactive 2D USAP Court Blueprint with selectable tactical zones.

---

## 2. Color Palette & Flutter Design Tokens

```dart
// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

abstract class AppColors {
  // --- Core Monochrome ---
  static const Color ink = Color(0xFF111111);             // Primary text & dark buttons
  static const Color canvas = Color(0xFFFFFFFF);          // Primary background
  static const Color softCloud = Color(0xFFF5F5F5);       // Secondary surface / input fill
  static const Color charcoal = Color(0xFF39393B);        // Secondary dark neutral
  static const Color ash = Color(0xFF4B4B4D);             // Mid-dark neutral
  static const Color mute = Color(0xFF707072);            // Subtitles & helper text
  static const Color stone = Color(0xFF9E9EA0);           // Light neutral text
  static const Color hairline = Color(0xFFCACACB);        // Card borders & hairline dividers
  static const Color hairlineSoft = Color(0xFFE5E5E5);    // Inset borders & background tracks

  // --- Semantic Accents ---
  static const Color courtSuccess = Color(0xFF007D48);    // Confirmed / Open slot green
  static const Color successBright = Color(0xFF1EAA52);   // Active pill badge
  static const Color saleRed = Color(0xFFD30005);         // Error / Cancellation red
  static const Color saleDeep = Color(0xFF780700);        // Deep alert dark
  static const Color infoBlue = Color(0xFF1151FF);        // Info & external links
  static const Color warningAmber = Color(0xFFE65100);    // Almost full slot status

  // --- Court Surface & Blueprint Colors ---
  static const Color courtBlue = Color(0xFF1E3A5F);       // Court 1 surface
  static const Color courtNavy = Color(0xFF2B3244);       // Court 2 surface
  static const Color kitchenGreen = Color(0xFF007D48);    // Non-Volley Zone (NVZ)
}
```

---

## 3. ThemeData & Typography System

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: AppColors.canvas,
      secondary: AppColors.softCloud,
      onSecondary: AppColors.ink,
      surface: AppColors.canvas,
      onSurface: AppColors.ink,
      error: AppColors.saleRed,
      onError: AppColors.canvas,
      outline: AppColors.hairline,
    ),

    // Athletic Typography Hierarchy
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: 56,
        letterSpacing: -0.5,
        height: 0.88,
        color: AppColors.ink,
      ),
      displayMedium: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: 36,
        letterSpacing: -0.5,
        height: 0.92,
        color: AppColors.ink,
      ),
      displaySmall: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: 26,
        letterSpacing: -0.3,
        height: 0.95,
        color: AppColors.ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.ink,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.mute,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.mute,
      ),
    ),

    // Sharp 0px Brutalist Card Theme with 1px hairline border
    cardTheme: const CardTheme(
      color: AppColors.canvas,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: AppColors.hairline, width: 1),
      ),
    ),

    // Pill Interactive Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.canvas,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.hairline, width: 1),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Stadium Pill Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.softCloud,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9999),
        borderSide: const BorderSide(color: AppColors.saleRed, width: 1),
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        color: AppColors.stone,
      ),
    ),
  );
}
```

---

## 4. Vector Monogram & Custom Canvas Painters

### 4.1 Brand Logo Painter (`BrandLogoWidget`)
Replicates the official athletic monogram badge (outer court boundary, net line, dashed NVZ kitchen lines, 45° strike line, and center sweetspot).

```dart
// lib/widgets/brand_logo.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BrandLogoWidget extends StatelessWidget {
  final double size;
  final bool withSubtitle;
  final bool inverted;

  const BrandLogoWidget({
    super.key,
    this.size = 36.0,
    this.withSubtitle = true,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = inverted ? AppColors.canvas : AppColors.ink;
    final secondaryColor = inverted ? AppColors.hairline : AppColors.mute;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: BrandLogoPainter(inverted: inverted),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'C&J',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: size * 0.7,
                    letterSpacing: -0.8,
                    height: 0.9,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'COURTS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: size * 0.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            if (withSubtitle)
              Text(
                'PICKLEBALL ARENA',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: (size * 0.22).clamp(7, 10),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: secondaryColor,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class BrandLogoPainter extends CustomPainter {
  final bool inverted;
  BrandLogoPainter({this.inverted = false});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeColor = inverted ? AppColors.canvas : AppColors.ink;

    final borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;

    final netPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final dashedPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final slashPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.square;

    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    // 1. Outer Court Boundary
    canvas.drawRect(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), borderPaint);

    // 2. Net Center Line
    canvas.drawLine(
      Offset(2, size.height * 0.5),
      Offset(size.width - 2, size.height * 0.5),
      netPaint,
    );

    // 3. Kitchen Boundary Lines (Dashed)
    _drawDashedLine(canvas, Offset(2, size.height * 0.34), Offset(size.width - 2, size.height * 0.34), dashedPaint);
    _drawDashedLine(canvas, Offset(2, size.height * 0.66), Offset(size.width - 2, size.height * 0.66), dashedPaint);

    // 4. Diagonal 45° Strike Line
    canvas.drawLine(
      Offset(size.width * 0.27, size.height * 0.77),
      Offset(size.width * 0.73, size.height * 0.23),
      slashPaint,
    );

    // 5. Center Sweetspot Dot
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 3.2, dotPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 3.5;
    const dashSpace = 2.5;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(Offset(startX, p1.dy), Offset(startX + dashWidth, p1.dy), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

### 4.2 Interactive 2D USAP Court Blueprint (`CourtVisualizerWidget`)
Replicates the 20' × 44' technical court diagram with selectable zones (Kitchen NVZ, Left Service Box, Right Service Box, Net, Baseline):

```dart
// lib/widgets/court_visualizer.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum CourtZone { kitchen, serviceLeft, serviceRight, net, baseline }

class CourtVisualizerWidget extends StatefulWidget {
  final String courtName;
  const CourtVisualizerWidget({super.key, this.courtName = "Court 1 & Court 2"});

  @override
  State<CourtVisualizerWidget> createState() => _CourtVisualizerWidgetState();
}

class _CourtVisualizerWidgetState extends State<CourtVisualizerWidget> {
  CourtZone _activeZone = CourtZone.kitchen;

  final Map<CourtZone, ({String label, String title, String dims, String desc, String rules, String tactics})> _data = {
    CourtZone.kitchen: (
      label: "The Kitchen (NVZ)",
      title: "Non-Volley Zone (The Kitchen)",
      dims: "7' × 20' (Both sides of Net)",
      desc: "The defining tactical zone of pickleball. Players may not hit a ball out of the air while standing in or touching the kitchen line.",
      rules: "A volley is any ball hit before bouncing. Even momentum stepping on the line after a volley is a fault.",
      tactics: "Neutralize power hitters by dropping soft dinks low into the kitchen. Force them to lift the ball for your put-away.",
    ),
    CourtZone.serviceRight: (
      label: "Right Service Court",
      title: "Right Service Court (Even / Server 1)",
      dims: "10' × 15' Playing Box",
      desc: "Starting station for every match at 0-0-2. Used when serving team's score is an even number (0, 2, 4, 6, 8, 10).",
      rules: "Serves must clear the 7-foot kitchen line and land diagonally into this box before being returned.",
      tactics: "Drive a deep slice serve into opponent's backhand corner to pin them deep.",
    ),
    CourtZone.serviceLeft: (
      label: "Left Service Court",
      title: "Left Service Court (Odd)",
      dims: "10' × 15' Playing Box",
      desc: "Active service box when serving team's score is an odd number (1, 3, 5, 7, 9).",
      rules: "Receivers and servers must each let the ball bounce once (Two-Bounce Rule).",
      tactics: "Aim sharp crosscourt angles that pull receiver off their court boundary.",
    ),
    CourtZone.net: (
      label: "Championship Net",
      title: "Tournament Center Net",
      dims: "36\" Posts • 34\" Center Strap",
      desc: "Official USAP tensioned steel mesh net with heavy-duty PVC white headband and center strap.",
      rules: "A ball hitting the net cord and landing in the correct service box is in play (no lets in pickleball).",
      tactics: "Clear the net by only 2 to 4 inches on non-attackable dinks to eliminate counter-attack angles.",
    ),
    CourtZone.baseline: (
      label: "Baseline & 8mm Cushion",
      title: "Baseline & 8mm Shock Floor",
      dims: "22' from Net • Shock Absorption",
      desc: "Rear boundary equipped with tournament-spec 8mm polyurethane shock absorption to preserve knees during rapid sprints.",
      rules: "Balls landing on the outer edge of any perimeter line are considered 100% IN.",
      tactics: "Deploy the 'Third Shot Drop' from here — a gentle arc landing softly into the opponent's kitchen.",
    ),
  };

  @override
  Widget build(BuildContext context) {
    final current = _data[_activeZone]!;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.softCloud,
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TECHNICAL BLUEPRINT', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.mute)),
                  const SizedBox(height: 2),
                  const Text("20' × 44' USAP COURT ARCHITECTURE", style: TextStyle(fontFamily: 'BebasNeue', fontSize: 24, letterSpacing: -0.2, color: AppColors.ink)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(9999), border: Border.all(color: AppColors.hairline)),
                child: Text(widget.courtName, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Zone Switcher Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: CourtZone.values.map((zone) {
                final isSelected = _activeZone == zone;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9999),
                    onTap: () => setState(() => _activeZone = zone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.ink : AppColors.canvas,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: isSelected ? AppColors.ink : AppColors.hairline),
                      ),
                      child: Text(
                        _data[zone]!.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.canvas : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // SVG-style Canvas Rendering
          AspectRatio(
            aspectRatio: 2.1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.canvas,
                border: Border.all(color: AppColors.hairline),
              ),
              child: CustomPaint(
                painter: CourtBlueprintPainter(activeZone: _activeZone),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Technical Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(current.title, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    Text(current.dims, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.mute)),
                  ],
                ),
                const Divider(color: AppColors.hairlineSoft, height: 20),
                _buildInfoRow('FUNCTION', current.desc),
                const SizedBox(height: 8),
                _buildInfoRow('USAP RULE', current.rules),
                const SizedBox(height: 8),
                _buildInfoRow('PRO TACTIC', current.tactics),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.mute, height: 1.35)),
      ],
    );
  }
}

class CourtBlueprintPainter extends CustomPainter {
  final CourtZone activeZone;
  CourtBlueprintPainter({required this.activeZone});

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()..color = AppColors.ink..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final paintHighlight = Paint()..color = AppColors.ink.withOpacity(0.18)..style = PaintingStyle.fill;
    final paintNet = Paint()..color = activeZone == CourtZone.net ? AppColors.saleRed : AppColors.ink..strokeWidth = activeZone == CourtZone.net ? 3.0 : 2.0;

    final courtRect = Rect.fromLTWH(16, 12, size.width - 32, size.height - 24);
    canvas.drawRect(courtRect, paintLine);

    final midX = courtRect.center.dx;
    final midY = courtRect.center.dy;
    final nvzWidth = courtRect.width * 0.16;

    // Kitchen / NVZ Left & Right
    final nvzLeft = Rect.fromLTRB(midX - nvzWidth, courtRect.top, midX, courtRect.bottom);
    final nvzRight = Rect.fromLTRB(midX, courtRect.top, midX + nvzWidth, courtRect.bottom);

    if (activeZone == CourtZone.kitchen) {
      canvas.drawRect(nvzLeft, paintHighlight);
      canvas.drawRect(nvzRight, paintHighlight);
    }
    canvas.drawRect(nvzLeft, paintLine);
    canvas.drawRect(nvzRight, paintLine);

    // Left Service Boxes (Top / Bottom)
    final serviceLeftTop = Rect.fromLTRB(courtRect.left, courtRect.top, midX - nvzWidth, midY);
    final serviceLeftBottom = Rect.fromLTRB(courtRect.left, midY, midX - nvzWidth, courtRect.bottom);

    if (activeZone == CourtZone.serviceLeft) {
      canvas.drawRect(serviceLeftTop, paintHighlight);
    } else if (activeZone == CourtZone.serviceRight) {
      canvas.drawRect(serviceLeftBottom, paintHighlight);
    }
    canvas.drawRect(serviceLeftTop, paintLine);
    canvas.drawRect(serviceLeftBottom, paintLine);

    // Right Service Boxes (Top / Bottom)
    final serviceRightTop = Rect.fromLTRB(midX + nvzWidth, courtRect.top, courtRect.right, midY);
    final serviceRightBottom = Rect.fromLTRB(midX + nvzWidth, midY, courtRect.right, courtRect.bottom);

    if (activeZone == CourtZone.serviceRight) {
      canvas.drawRect(serviceRightTop, paintHighlight);
    } else if (activeZone == CourtZone.serviceLeft) {
      canvas.drawRect(serviceRightBottom, paintHighlight);
    }
    canvas.drawRect(serviceRightTop, paintLine);
    canvas.drawRect(serviceRightBottom, paintLine);

    // Baseline Highlight
    if (activeZone == CourtZone.baseline) {
      final baseLeft = Rect.fromLTWH(courtRect.left, courtRect.top, 8, courtRect.height);
      final baseRight = Rect.fromLTWH(courtRect.right - 8, courtRect.top, 8, courtRect.height);
      canvas.drawRect(baseLeft, Paint()..color = AppColors.courtSuccess.withOpacity(0.35));
      canvas.drawRect(baseRight, Paint()..color = AppColors.courtSuccess.withOpacity(0.35));
    }

    // Net Line (Center)
    canvas.drawLine(Offset(midX, courtRect.top - 4), Offset(midX, courtRect.bottom + 4), paintNet);
    canvas.drawCircle(Offset(midX, courtRect.top - 4), 3, Paint()..color = AppColors.ink);
    canvas.drawCircle(Offset(midX, courtRect.bottom + 4), 3, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant CourtBlueprintPainter oldDelegate) => oldDelegate.activeZone != activeZone;
}
```

---

## 5. Reusable Core UI Component Blueprints

### 5.1 Tap Feedback Wrapper (`TapCollapse`)
```dart
// lib/widgets/tap_collapse.dart
import 'package:flutter/material.dart';

class TapCollapse extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TapCollapse({super.key, required this.child, this.onTap});

  @override
  State<TapCollapse> createState() => _TapCollapseState();
}

class _TapCollapseState extends State<TapCollapse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
```

### 5.2 Status Pill Badge (`StatusBadge`)
```dart
// lib/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeVariant { success, neutral, alert, dark }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;

  const StatusBadge({super.key, required this.label, this.variant = BadgeVariant.neutral});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    Color border;

    switch (variant) {
      case BadgeVariant.success:
        bg = AppColors.softCloud;
        text = AppColors.courtSuccess;
        border = AppColors.courtSuccess.withOpacity(0.3);
        break;
      case BadgeVariant.alert:
        bg = AppColors.softCloud;
        text = AppColors.saleRed;
        border = AppColors.saleRed.withOpacity(0.3);
        break;
      case BadgeVariant.dark:
        bg = AppColors.ink;
        text = AppColors.canvas;
        border = AppColors.ink;
        break;
      case BadgeVariant.neutral:
      default:
        bg = AppColors.softCloud;
        text = AppColors.mute;
        border = AppColors.hairline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: text,
        ),
      ),
    );
  }
}
```

### 5.3 Perforated Ticket Divider & QR Pass (`PerforatedTicketDivider`)
```dart
// lib/widgets/perforated_ticket_divider.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PerforatedTicketDivider extends StatelessWidget {
  final double cutoutRadius;
  const PerforatedTicketDivider({super.key, this.cutoutRadius = 12.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cutoutRadius * 2,
      child: CustomPaint(
        painter: PerforatedPainter(radius: cutoutRadius),
      ),
    );
  }
}

class PerforatedPainter extends CustomPainter {
  final double radius;
  PerforatedPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.canvas..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = AppColors.hairline..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final dashPaint = Paint()..color = AppColors.hairline..style = PaintingStyle.stroke..strokeWidth = 1.2;

    // Left semi-circle cutout
    canvas.drawCircle(Offset(0, size.height / 2), radius, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(0, size.height / 2), radius: radius), -1.57, 3.14, false, borderPaint);

    // Right semi-circle cutout
    canvas.drawCircle(Offset(size.width, size.height / 2), radius, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: radius), 1.57, 3.14, false, borderPaint);

    // Center Dashed Line
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = radius + 4;
    final endX = size.width - radius - 4;

    while (startX < endX) {
      canvas.drawLine(Offset(startX, size.height / 2), Offset(startX + dashWidth, size.height / 2), dashPaint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

---

## 6. Screen-by-Screen UI/UX Specifications

---

### Screen 1: Landing / Home (`/`)

#### Layout Architecture:
1. **Utility Strip & Top Navigation**:
   - Monogram `BrandLogoWidget`, live open status indicator (`Courts 1 & 2 Open`), and "Book Court" pill button.
2. **Hero Action Banner**:
   - `AspectRatio(aspectRatio: 16 / 10)`, background image `assets/images/hero-action.jpg` with `LinearGradient` from transparent to black 85%.
   - Headline: `Bebas Neue` 48px uppercase ("SERVE WITH FORCE. OWN THE COURT.").
   - Subtitle: "Two USA Pickleball 8mm Cushioned Courts • ₱300/hr Flat Rate".
   - Primary Action: Floating white pill button (`ElevatedButton`: "Book Court — ₱300/hr") and outlined pill ("Rates & Equipment").
3. **Arena Catalog (Featured Courts Grid)**:
   - 1:1 square asset containers (`assets/images/court-overhead.png`) on `#F5F5F5` surface.
   - Promo badge ("Just In" / "High Demand") in pill geometry.
   - Swatch dots row (`#111111`, `#1E3A5F`, `#007D48`).
   - Pricing metadata (`₱300 / hour`) and "Book Now" CTA pill.
4. **Pro Shop & Gear Rentals (4-Up Rail)**:
   - `C&J Pro 16mm Raw Carbon Paddle` (₱150 / session)
   - `Franklin X-40 Tournament Balls (3-Pack)` (₱150)
   - `Complete Doubles Squad Bundle` (₱300)
   - `C&J Performance Microfiber Court Towel` (₱250)
5. **Campaign Split Tile**:
   - Background image with dark overlay: "THE KITCHEN HAS RULES. PLAY BY THEM."
   - 7-ft NVZ rule explanation and "Read Court Guidelines" CTA.
6. **Technical USAP Court Blueprint**:
   - Interactive `CourtVisualizerWidget` with zone highlight buttons.
7. **FAQ Accordion Rows**:
   - 24-hour refund policy, non-marking shoe requirements, multi-hour booking rules.

---

### Screen 2: Real-Time Court Booking (`/book`)

The centerpiece user reservation flow. Supports 1 to 12-hour session blocks and instant PayMongo checkout.

```
┌────────────────────────────────────────────────────────┐
│  LIVE RESERVATION                                      │
│  SELECT COURT & SCHEDULE                               │
│  ₱300/hr Flat Rate • 24h Cancellation Guarantee        │
├────────────────────────────────────────────────────────┤
│  1. SELECT COURT                                       │
│  ┌──────────────────────────────────────────────────┐  │
│  │ (•) Court 1 — Indoor (Pro Cushion)      ₱300/hr ✓│  │
│  ├──────────────────────────────────────────────────┤  │
│  │ ( ) Court 2 — Indoor (Tournament Spec)  ₱300/hr  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  SESSION DURATION                                      │
│  [ 2 Hours — ₱600 (Doubles match)                ▼ ]   │
│                                                        │
│  2. SELECT DATE                                        │
│  [ Today ] [ Tomorrow ]               March 2026       │
│  ────────────────────────────────────────────────────  │
│   Mo  Tu  We  Th  Fr  Sa  Su                           │
│           1   2   3   4   5                            │
│   6   7   8   9  [10] 11  12  (Heatmap indicator dots) │
│                                                        │
│  3. CHOOSE TIME SLOT                                   │
│  [ ALL ] [ MORNING ] [ AFTERNOON ] [ NIGHT ]           │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────┐ │
│  │ 06:00 AM     │ │ 07:00 AM  ✓  │ │ 08:00 AM   Full │ │
│  │ Open         │ │ Selected     │ │ (Disabled)      │ │
│  └──────────────┘ └──────────────┘ └─────────────────┘ │
│                                                        │
│  ADD-ON RENTALS                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [Img] Pro Carbon Paddle Bundle         +₱150     │  │
│  │ 2x 16mm Raw Carbon + 3 Balls           [+ Add]   │  │
│  ├──────────────────────────────────────────────────┤  │
│  │ [Img] Smart Ball Thrower Machine       +₱300     │  │
│  │ Automated feeder & drills (₱150/hr)    [Remove]  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ────────────────────────────────────────────────────  │
│  TOTAL AMOUNT DUE                           ₱900.00    │
│  No Hidden Fees                                        │
│                                                        │
│  [ PAY ₱900.00 & LOCK SLOT (PayMongo)               ]  │
│  Instant lock via GCash, Maya, QR Ph & Cards           │
└────────────────────────────────────────────────────────┘
```

#### Price Calculation Formula:
```dart
final courtSubtotal = selectedCourt.hourlyRate * durationHours;
final paddleFee = hasPaddleRental ? 150 : 0;
final ballThrowerFee = hasBallThrowerRental ? 150 * durationHours : 0;
final grandTotal = courtSubtotal + paddleFee + ballThrowerFee;
```

#### Slot & Calendar Behavior:
- **Operating Hours**: 6:00 AM – 10:00 PM (Hours 6 through 21).
- **Contiguous Block Rule**: When duration is $N$ hours, slot starting at hour $H$ requires hours $H, H+1, \dots, H+N-1$ to all be available.
- **Calendar Dots**:
  - `available`: Green dot (`#007D48`)
  - `almost_full`: Orange dot (`#E65100`) (when $\le 5$ slots remain or $\ge 65\%$ booked)
  - `fully_booked`: Red dot (`#D30005`)

---

### Screen 3: Confirmation & Digital QR Ticket Pass (`/booking/success/:id`)

- **Confetti Trigger**: `confetti` package controller fires for 2 seconds on mount.
- **Header Status**: "PAYMENT VERIFIED • RESERVATION CONFIRMED".
- **Physical Ticket Card**:
  - Top Athletic Header (Dark `#111111` with Court Name, Status, and Ref `#80D4920A`).
  - Key Metadata Grid (Playing Date, Time Interval, Arena Location, Player Contact).
  - Pricing Breakdown with Grand Total.
  - Perforated separator (`PerforatedTicketDivider`).
  - High-Contrast QR Code (`qr_flutter` widget) embedding:
    ```json
    {
      "ref": "80D4920A-34D9-47F3-8F1B-4627F5B289DE",
      "court": "Court 1 — Indoor (Pro Cushion)",
      "player": "Juan Dela Cruz",
      "start": "2026-09-10T07:00:00+08:00",
      "system": "C&J Arena"
    }
    ```
- **Actions Bar**: "Print / Save PDF Pass" (triggers system print/share) and "View Player Portal".

---

### Screen 4: Player Portal / Dashboard (`/dashboard`)

- **Player Hero Strip**: Member Name, "Active Player" badge, and arena location.
- **4-Up Metrics Grid**:
  - `Upcoming Bookings` (count)
  - `Court Hours` (lifetime total hours played)
  - `Court Surface` (8mm Cushion)
  - `Tournament Spec` (USAP Official)
- **Tabs**:
  1. `Upcoming Sessions`: Active cards with "Pass Receipt" and "Cancel & Refund" actions.
  2. `Booking History`: Historical records with payment status and receipt references.
  3. `Settings`: Password change form and profile details.
- **24-Hour Policy Check**:
  ```dart
  final hoursUntilStart = booking.startTime.difference(DateTime.now()).inHours;
  final isEligibleForRefund = hoursUntilStart >= 24;
  ```

---

### Screen 5: Cancellation & Refund Bottom Sheet

- **Eligibility Header**: Displays court name, match date, and refundable total price.
- **E-Wallet Selector Pills**: `GCash`, `Maya`, `GrabPay`, `GoTyme`, `Bank`.
- **Form Fields**:
  - `Account Holder Name` (required)
  - `Account / Mobile Number` (required)
  - `Reason for Cancellation` (Dropdown: Schedule Conflict, Emergency, Weather, Wrong Court, Other)
- **Submission**: Updates `bookings` status to `cancelled_refund_pending` and inserts record into `booking_refunds`.

---

### Screen 6: Auth Screens (Login, Sign Up, Forgot Password)

- **Layout**: Centered brutalist card with 1px hairline border on white canvas.
- **Header**: Monogram `BrandLogoWidget` with athletic uppercase headline.
- **Inputs**: Stadium pill text fields (`AppColors.softCloud` fill, no border until focused).
- **Sign Up Confirmation**: State switches to "Check Your Email" with inbox graphic.
- **Forgot Password**: Server-generated temporary password dispatch confirmation.

---

## 7. Modular Copy-Paste AI Implementation Prompts

Use the following modular prompts in sequence to build the complete Flutter application:

---

### 🟢 Prompt 1: Design Tokens, Theme & Core Architecture
```markdown
You are building the client-facing mobile application for C&J Pickleball in Flutter.
The design philosophy is "Editorial Athletic Luxury" (Nike Lab / Aimé Leon Dore aesthetic) featuring:
- Core Monochrome Palette: #111111 (Ink), #FFFFFF (Canvas), #F5F5F5 (Soft Cloud), #CACACB (Hairline), #E5E5E5 (Soft Hairline), #707072 (Mute).
- Semantic Accents: #007D48 (Court Success), #D30005 (Sale / Alert Red), #E65100 (Amber Warning).
- Dual Geometry: Brutalist 0px containers for cards/dividers; full pill geometry (BorderRadius.circular(9999) / StadiumBorder) for all buttons, chips, badges, and input fields.
- Typography: Display/Headlines in 'BebasNeue', Body/Labels in 'Inter'.

Please implement:
1. `lib/theme/app_colors.dart` with all named constants.
2. `lib/theme/app_theme.dart` configuring ThemeData with custom TextTheme, zero-elevation CardTheme, StadiumBorder buttons, and pill InputDecorationTheme.
3. `lib/widgets/brand_logo.dart` implementing the CustomPainter for the official C&J court monogram with dashed kitchen lines, 45° strike line, and center dot.
```

---

### 🟢 Prompt 2: Reusable Widgets & 2D Court Visualizer
```markdown
Implement the core reusable UI components for C&J Pickleball:
1. `lib/widgets/tap_collapse.dart`: An active feedback wrapper scaling the child to 0.96 on pointer down.
2. `lib/widgets/status_badge.dart`: A pill badge supporting variants (.success, .neutral, .alert, .dark).
3. `lib/widgets/perforated_ticket_divider.dart`: A CustomPainter drawing a ticket perforation with left and right semi-circle cutouts and center dashed hairline.
4. `lib/widgets/court_visualizer.dart`: An interactive 2D USAP Court Blueprint (20' × 44') with zone selector pills (The Kitchen NVZ, Left Service, Right Service, Net, Baseline) that updates the canvas highlight and shows detailed dimensions, USAP rules, and tactics.
```

---

### 🟢 Prompt 3: Real-Time Court Booking Screen (`/book`)
```markdown
Create the complete court booking screen in `lib/screens/booking/booking_screen.dart`:
1. Court selector chips for Court 1 (Indoor Pro Cushion) and Court 2 (Indoor Tournament Spec) at ₱300/hr.
2. Duration picker dropdown supporting 1 to 12 hours with match type descriptions (e.g. 1hr Single, 2hr Doubles, 4hr Squad).
3. Date Heatmap Calendar with availability status dots (Green = available, Orange = almost full, Red = fully booked) and quick selectors ("Today", "Tomorrow").
4. Time slot grid (6:00 AM to 10:00 PM) with filters (All, Morning, Afternoon, Night). Implement the multi-hour contiguous slot availability algorithm.
5. Add-on rental cards:
   - Pro Carbon Paddle Bundle (+₱150 flat)
   - Smart Ball Thrower Machine (+₱150/hr × duration)
6. Sticky Bottom Bar showing live breakdown, Grand Total, and "Pay & Lock Slot" button initiating the PayMongo checkout WebView.
```

---

### 🟢 Prompt 4: Confirmation & Digital QR Ticket Pass Screen
```markdown
Create `lib/screens/booking/booking_success_screen.dart`:
1. Automatic Confetti celebration burst for 2 seconds on mount using package:confetti.
2. Verified payment header badge ("PAYMENT VERIFIED • RESERVATION CONFIRMED").
3. Printable/Shareable physical ticket card:
   - Dark athletic header with Court Name and Reference ID.
   - Playing Date, Time Interval, Arena Location, and Player details.
   - Perforated tear line (PerforatedTicketDivider).
   - High-contrast square QR code pass generated via package:qr_flutter containing the booking JSON payload.
   - 24-hour cancellation policy reminder and venue footwear rules.
4. Action buttons: "Print / Save PDF Receipt", "Book Another Court", and "View My Portal".
```

---

### 🟢 Prompt 5: Player Portal Dashboard & Cancellation Flow
```markdown
Create `lib/screens/dashboard/dashboard_screen.dart` and `lib/widgets/refund_request_bottom_sheet.dart`:
1. Member Profile Header with "Active Player" badge and member since date.
2. 4-Up Metrics row (Upcoming Bookings, Court Hours Played, 8mm Cushion, USAP Official).
3. Tabbed view:
   - Upcoming Sessions: Cards showing date, time, court, and "Cancel & Refund" action.
   - Booking History: Historical completed and cancelled bookings.
   - Settings: Password update form with validation.
4. Cancellation & Refund Logic:
   - Check strict 24-hour rule: `startTime.difference(DateTime.now()).inHours >= 24`.
   - If eligible, open RefundRequestBottomSheet collecting E-Wallet (GCash/Maya/GrabPay/GoTyme/Bank), Account Holder Name, Account Number, and Reason.
   - Update booking state to `cancelled_refund_pending` upon submission.
```

---

## 8. Flutter Project Architecture & Dependencies (`pubspec.yaml`)

### Recommended Directory Structure
```
lib/
├── main.dart
├── router.dart                     # GoRouter declarative navigation with auth guard
├── theme/
│   ├── app_colors.dart
│   └── app_theme.dart
├── models/
│   ├── court.dart
│   ├── booking.dart
│   ├── booking_refund.dart
│   └── availability_slot.dart
├── services/
│   ├── supabase_service.dart       # Supabase Auth & DB client
│   ├── booking_service.dart        # Slot availability & reservation logic
│   └── payment_service.dart        # PayMongo Next.js API connector
├── providers/                      # State management (Riverpod / Bloc)
│   ├── auth_provider.dart
│   ├── booking_provider.dart
│   └── court_provider.dart
├── screens/
│   ├── landing/landing_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── forgot_password_screen.dart
│   ├── booking/booking_screen.dart
│   ├── success/booking_success_screen.dart
│   └── dashboard/dashboard_screen.dart
└── widgets/
    ├── brand_logo.dart
    ├── tap_collapse.dart
    ├── status_badge.dart
    ├── court_visualizer.dart
    ├── perforated_ticket_divider.dart
    └── refund_request_bottom_sheet.dart
```

### Required `pubspec.yaml`
```yaml
name: cj_pickleball
description: "C&J Pickleball Arena - Official Client Application"
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.8.0
  go_router: ^14.3.0
  flutter_riverpod: ^2.5.1
  qr_flutter: ^4.1.0
  confetti: ^0.7.0
  intl: ^0.19.0
  http: ^1.2.2
  webview_flutter: ^4.10.0
  url_launcher: ^6.3.0
  lucide_icons: ^0.252.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/icons/

  fonts:
    - family: BebasNeue
      fonts:
        - asset: assets/fonts/BebasNeue-Regular.ttf
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```
