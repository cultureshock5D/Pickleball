# C&J Pickleball — Flutter User-Side UI/UX Specification & Replication Guide

Complete UI/UX design tokens, layout specifications, component blueprints, animations, and widget architectures for building the **client-facing mobile app** in Flutter.

---

## 1. Visual Identity & Design Philosophy

The C&J Pickleball client experience is built on an **Editorial Athletic Luxury** aesthetic (inspired by modern high-performance sports apparel brands like Nike Lab and Aimé Leon Dore):

1. **Monochrome Dominance with High-Impact Contrast**: Pure white canvas (`#FFFFFF`) against deep ink black (`#111111`), separated by crisp 1px hairline borders (`#CACACB` / `#E5E5E5`).
2. **Dual Geometry Language**:
   - **Structural Containers**: 0px border radius (sharp, architectural, brutalist card containers).
   - **Interactive Elements**: Full pill geometry (`BorderRadius.circular(9999)` / `StadiumBorder`) for buttons, status badges, slot chips, and input fields.
3. **Athletic Campaign Typography**:
   - **Display / Hero / Badges**: `Bebas Neue` (condensed, tall, uppercase, tracking-tight).
   - **Headings & Body**: `Inter` / `Roboto` (clean geometric sans-serif, -0.01em tracking).
4. **Tactile Micro-Interactions**:
   - Active tap feedback with immediate spring compression (`transform: scale(0.96)`).
   - Live availability heatmaps and real-time slot state changes.
   - Ticket-style perforated pass design with celebratory confetti on checkout success.

---

## 2. Color Palette & Flutter Design Tokens

### 2.1 Color Swatches

```dart
import 'package:flutter/material.dart';

abstract class AppColors {
  // --- Core Monochrome ---
  static const Color ink = Color(0xFF111111);             // Primary text & dark accents
  static const Color canvas = Color(0xFFFFFFFF);          // Primary background
  static const Color softCloud = Color(0xFFF5F5F5);       // Secondary surface / muted fill
  static const Color charcoal = Color(0xFF39393B);        // Secondary dark
  static const Color ash = Color(0xFF4B4B4D);             // Mid-dark neutral
  static const Color mute = Color(0xFF707072);            // Subtitles & helper text
  static const Color stone = Color(0xFF9E9EA0);           // Light neutral text
  static const Color hairline = Color(0xFFCACACB);        // Card borders & dividers
  static const Color hairlineSoft = Color(0xFFE5E5E5);    // Inset borders & tracks

  // --- Semantic Accents ---
  static const Color courtSuccess = Color(0xFF007D48);    // Confirmed / Open slot green
  static const Color successBright = Color(0xFF1EAA52);   // Active pill badge
  static const Color saleRed = Color(0xFFD30005);         // Error / Cancellation red
  static const Color saleDeep = Color(0xFF780700);        // Deep alert dark
  static const Color infoBlue = Color(0xFF1151FF);        // Info / links
  
  // --- Court Surface Colors (Visualizer) ---
  static const Color courtBlue = Color(0xFF1E3A5F);       // Court 1 surface
  static const Color courtNavy = Color(0xFF2B3244);       // Court 2 surface
  static const Color kitchenGreen = Color(0xFF007D48);    // Non-volley zone
}
```

### 2.2 Flutter `ThemeData` Configuration

```dart
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
    
    // Typography
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: 48,
        letterSpacing: -0.5,
        height: 0.9,
        color: AppColors.ink,
      ),
      displayMedium: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: 32,
        letterSpacing: -0.5,
        height: 0.95,
        color: AppColors.ink,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
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

    // Card Theme (Sharp 0px Geometry with 1px border)
    cardTheme: CardTheme(
      color: AppColors.canvas,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: AppColors.hairline, width: 1),
      ),
    ),

    // Button Themes (Pill Geometry)
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

    // Input Decoration (Pill Inputs)
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

## 3. Brand Logo Vector & Custom Painter

The C&J court monogram consists of an athletic geometric pickleball court outline with dashed kitchen lines, a diagonal 45° strike line, and a center sweetspot circle.

```dart
class BrandLogoPainter extends CustomPainter {
  final Color color;
  final bool inverted;

  BrandLogoPainter({this.color = AppColors.ink, this.inverted = false});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeColor = inverted ? AppColors.canvas : color;
    
    final borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final netPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final dashedPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final slashPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
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

    // 3. Kitchen Boundary Lines (dashed simulation)
    _drawDashedLine(canvas, Offset(2, size.height * 0.34), Offset(size.width - 2, size.height * 0.34), dashedPaint);
    _drawDashedLine(canvas, Offset(2, size.height * 0.66), Offset(size.width - 2, size.height * 0.66), dashedPaint);

    // 4. Diagonal 45° Strike Line
    canvas.drawLine(
      Offset(size.width * 0.27, size.height * 0.77),
      Offset(size.width * 0.73, size.height * 0.23),
      slashPaint,
    );

    // 5. Center Sweetspot Dot
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 3.5, dotPaint);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
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

---

## 4. Reusable Core UI Components

### 4.1 Tap Feedback Wrapper (`TapCollapse`)
Replicates the web `.tap-collapse` active state (`scale(0.96)`).

```dart
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

### 4.2 Status Pill Badge
Used throughout for court status, booking confirmation, and calendar heatmaps.

```dart
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

---

## 5. Screen-by-Screen UI/UX Specifications

---

### Screen 1: Home / Landing Screen

```
┌────────────────────────────────────────────────────────┐
│  [Logo: C&J COURTS]                    [Player Pass]   │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │  [Hero Image with Black Gradient Overlay]        │  │
│  │  METRO MANILA • TOURNAMENT GRADE ARENA           │  │
│  │                                                  │  │
│  │  SERVE WITH FORCE.                               │  │
│  │  OWN THE COURT.                                  │  │
│  │                                                  │  │
│  │  Two USA Pickleball 8mm Cushioned Courts         │  │
│  │  ₱300/hr Flat Rate • AC Lounge • Instant Booking │  │
│  │                                                  │  │
│  │  [ (●) Book Court — ₱300/hr ] [ Rates & Gear ]   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  ARENA INVENTORY                                       │
│  FEATURED COURTS                           View Slots >│
│  ────────────────────────────────────────────────────  │
│  ┌────────────────────────┐  ┌───────────────────────┐ │
│  │ [Square Image 1:1]     │  │ [Square Image 1:1]    │ │
│  │ Court 1 — Indoor       │  │ Court 2 — Indoor      │ │
│  │ Pro Cushion • ₱300/hr  │  │ Tour Spec • ₱300/hr   │ │
│  └────────────────────────┘  └───────────────────────┘ │
│                                                        │
│  PRO SHOP & GEAR RENTALS                               │
│  ────────────────────────────────────────────────────  │
│  • Pro 16mm Raw Carbon Paddle Bundle (+₱150)           │
│  • Smart Ball Thrower Automated Feeder (+₱150/hr)      │
│  • Franklin X-40 Tournament Balls (3-Pack)             │
│                                                        │
│  [2D Interactive Court Surface Visualizer]             │
│  [FAQ Accordion: 24h Policy, Shoes, Booking]           │
└────────────────────────────────────────────────────────┘
```

#### Key Implementation Details:
- **Hero Aspect Ratio**: `AspectRatio(aspectRatio: 16 / 10)` on mobile, background image with `LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.8)])`.
- **Display Headline**: Custom font `Bebas Neue`, size 52, `height: 0.88`, uppercase.
- **Action Buttons**: Floating white pill `ElevatedButton` ("Book Court — ₱300/hr") placed on top of hero graphic.

---

### Screen 2: Real-Time Court Booking (`/book`)

The core user reservation workflow. Divided into 4 visual steps:

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

#### Component Specifications:
1. **Court Picker Chips**:
   - Selected: `AppColors.ink` fill, `AppColors.canvas` text, checkmark icon.
   - Unselected: `AppColors.canvas` fill, 1px `AppColors.hairline` border.
2. **Date Heatmap Calendar**:
   - Display circular dot indicators beneath day numbers:
     - `almost_full`: Orange/Amber dot (`Color(0xFFE65100)`).
     - `fully_booked`: Red dot (`AppColors.saleRed`).
     - `available`: Green dot (`AppColors.courtSuccess`).
3. **Slot Grid Chips**:
   - Height: 48px, Stadium shape.
   - Selected: Black background, white text, checkmark.
   - Available: White background, 1px hairline border, green "Open" text.
   - Booked / Past: Disabled `#F5F5F5` background, muted `#CACACB` text, "Full".
4. **Sticky Bottom Bar (Mobile Viewport)**:
   - On mobile, lock the Total Amount Due and "Pay & Lock Slot" button into a sticky bottom container with 1px top border and safe area padding.

---

### Screen 3: Post-Payment Confirmation & Digital QR Ticket Pass

```
┌────────────────────────────────────────────────────────┐
│               [Confetti Particle Burst]                │
│                                                        │
│        (✓) PAYMENT VERIFIED • RESERVATION CONFIRMED    │
│                                                        │
│                  YOU'RE ON THE COURT                   │
│      Official receipt sent to player@email.com         │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │ C&J COURTS • OFFICIAL TICKET PASS        PAID    │  │
│  │ Court 1 — Indoor (Pro Cushion)    Ref: #80D4920A │  │
│  ├──────────────────────────────────────────────────┤  │
│  │  PLAYING DATE           TIME SLOT                │  │
│  │  Thu, Mar 10, 2026      07:00 AM – 09:00 AM      │  │
│  │                                                  │  │
│  │  DURATION               TOTAL PAID               │  │
│  │  2 Hours Session        ₱900.00 (PayMongo)       │  │
│  ├ - - - - - - - - - - - - - - - - - - - - - - - - -┤  │
│  │                                                  │  │
│  │               ┌───────────────┐                  │  │
│  │               │ █▀▀▀▀█ ▀█ █▀▀ │                  │  │
│  │               │ █ ██ █ █▄ █ █ │                  │  │
│  │               │ ▀▀▀▀▀▀ ▀▀ ▀▀▀ │                  │  │
│  │               └───────────────┘                  │  │
│  │            FAST CHECK-IN QR PASS                 │  │
│  │      Scan at the front desk upon arrival         │  │
│  │                                                  │  │
│  │  Location: Tomas Morato Ave, Quezon City         │  │
│  │  Mandatory: Non-marking court shoes required     │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  [ Print / Save PDF Pass ]    [ View Player Portal ]   │
└────────────────────────────────────────────────────────┘
```

#### Ticket Pass Flutter Implementation:
- **Perforated Ticket Divider**: Custom painter drawing dashed line with semi-circle cutouts on left and right edges.
- **QR Code Rendering**: `qr_flutter` package with `QrImageView(data: jsonPayload, size: 180, eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink))`.
- **Confetti Explosion**: Trigger `confetti` package controller for 1.5 seconds on screen load.

---

### Screen 4: Player Portal / Dashboard (`/dashboard`)

```
┌────────────────────────────────────────────────────────┐
│  MEMBER PROFILE • [ Active Player ]                    │
│  JUAN'S PLAYER PASS                                    │
│  Tomas Morato Arena • Member since March 2026          │
│                                                        │
│  [ (+) Book a Court (₱300/hr) ]                        │
├────────────────────────────────────────────────────────┤
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌──────┐ │
│  │ UPCOMING   │ │ COURT HRS  │ │ SURFACE    │ │ SPEC │ │
│  │ 2 Sessions │ │ 14 hrs     │ │ 8mm Cushion│ │ USAP │ │
│  └────────────┘ └────────────┘ └────────────┘ └──────┘ │
│                                                        │
│  [ (•) Upcoming (2) ] [ History (5) ] [ Settings ]     │
│  ────────────────────────────────────────────────────  │
│  ┌──────────────────────────────────────────────────┐  │
│  │ COURT 1 — INDOOR (PRO CUSHION)       [CONFIRMED] │  │
│  │ 📅 Thu, Mar 10, 2026 • ⏰ 07:00 AM – 09:00 AM     │  │
│  │ Total Paid: ₱600.00 • PayMongo (GCash)           │  │
│  │                                                  │  │
│  │ [ Pass Receipt ]          [ Cancel & Refund ]    │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

#### Dashboard Business Logic in UI:
- **"Cancel & Refund" Button State**:
  - If `start_time - now >= 24 hours`: Active red outline button, opens Refund Request Bottom Sheet.
  - If `start_time - now < 24 hours`: Disabled or tooltip explaining strict 24-hour rule.
- **Tabs**: Smooth horizontal scrollable or segmented pills for `Upcoming`, `History`, `Settings`.

---

### Screen 5: Cancellation & Refund Bottom Sheet

```
┌────────────────────────────────────────────────────────┐
│  Request Booking Refund                       [ ✕ ]    │
│  Court 1 — Indoor • Thu, Mar 10 • ₱600.00              │
├────────────────────────────────────────────────────────┤
│  ⓘ 24-Hour Policy Notice                               │
│  Eligible for 100% full refund to your e-wallet.       │
│                                                        │
│  SELECT REFUND DESTINATION                             │
│  (•) GCash   ( ) Maya   ( ) Bank Transfer   ( ) Cash   │
│                                                        │
│  ACCOUNT HOLDER NAME                                   │
│  [ Juan Dela Cruz                                    ] │
│                                                        │
│  GCASH MOBILE NUMBER                                   │
│  [ 09171234567                                       ] │
│                                                        │
│  REASON FOR CANCELLATION                               │
│  [ Schedule Conflict                               ▼ ] │
│                                                        │
│  [ CONFIRM CANCELLATION & SUBMIT REFUND              ] │
│  Processed within 24–48 hours to your registered wallet│
└────────────────────────────────────────────────────────┘
```

---

## 6. Animation & Motion Guidelines

| Interaction | Flutter Technique | Duration | Curve |
|-------------|-------------------|----------|-------|
| **Button / Card Press** | `TapCollapse` (`Transform.scale`) | 100ms in / 150ms out | `Curves.easeInOut` |
| **Slot Selection** | `AnimatedContainer` (color & border) | 180ms | `Curves.fastOutSlowIn` |
| **Tab Switching** | `PageView` or `AnimatedSwitcher` | 250ms | `Curves.easeOutCubic` |
| **Success Celebration** | `confetti` controller | 2000ms | N/A |
| **Loading Skeleton** | `shimmer` package gradient sweep | 1200ms loop | `Curves.linear` |
| **Modal Entry** | `showModalBottomSheet(isScrollControlled: true)` | 300ms | `Curves.easeOutExpo` |

---

## 7. Responsive Layout Adaptations (Mobile vs Tablet)

```dart
Widget buildResponsiveBookingLayout(BuildContext context) {
  final isTablet = MediaQuery.of(context).size.width >= 768;

  if (isTablet) {
    // 2-Column Split View (Left: Court/Calendar/Slots, Right: Sticky Summary)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: BookingSelectorsColumn()),
        const SizedBox(width: 32),
        Expanded(flex: 5, child: StickyCheckoutCard()),
      ],
    );
  }

  // Mobile Single Column with Bottom Sheet Checkout
  return Column(
    children: [
      BookingSelectorsColumn(),
      const SizedBox(height: 24),
      MobileStickyCheckoutBottomBar(),
    ],
  );
}
```

---

## 8. Recommended Flutter Asset Structure

```
assets/
├── fonts/
│   ├── BebasNeue-Regular.ttf
│   ├── Inter-Regular.ttf
│   ├── Inter-Medium.ttf
│   ├── Inter-SemiBold.ttf
│   └── Inter-Bold.ttf
├── images/
│   ├── hero-action.jpg
│   ├── court-overhead.png
│   ├── gear-paddle.jpg
│   ├── gear-balls.jpg
│   └── gear-ball-thrower.png
└── icons/
    └── court_monogram.svg
```
