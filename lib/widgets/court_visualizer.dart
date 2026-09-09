import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

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
    final colors = context.colors;
    final current = _data[_activeZone]!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TECHNICAL BLUEPRINT',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "20' × 44' USAP COURT ARCHITECTURE",
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 24,
                        letterSpacing: -0.2,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  widget.courtName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
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
                        color: isSelected ? colors.textPrimary : colors.surface,
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isSelected ? colors.textPrimary : colors.border,
                        ),
                      ),
                      child: Text(
                        _data[zone]!.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? colors.background : colors.textPrimary,
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
                color: colors.surface,
                border: Border.all(color: colors.border),
              ),
              child: CustomPaint(
                painter: CourtBlueprintPainter(
                  activeZone: _activeZone,
                  primaryColor: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Technical Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        current.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      current.dims,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
                Divider(color: colors.borderSubtle, height: 20),
                _buildInfoRow('FUNCTION', current.desc, colors),
                const SizedBox(height: 8),
                _buildInfoRow('USAP RULE', current.rules, colors),
                const SizedBox(height: 8),
                _buildInfoRow('PRO TACTIC', current.tactics, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String desc, AppPalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: colors.textMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class CourtBlueprintPainter extends CustomPainter {
  final CourtZone activeZone;
  final Color primaryColor;

  CourtBlueprintPainter({
    required this.activeZone,
    this.primaryColor = AppColors.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final paintHighlight = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final paintNet = Paint()
      ..color = activeZone == CourtZone.net ? AppColors.saleRed : primaryColor
      ..strokeWidth = activeZone == CourtZone.net ? 3.0 : 2.0;

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
      canvas.drawRect(baseLeft, Paint()..color = AppColors.courtSuccess.withValues(alpha: 0.35));
      canvas.drawRect(baseRight, Paint()..color = AppColors.courtSuccess.withValues(alpha: 0.35));
    }

    // Net Line (Center)
    canvas.drawLine(
      Offset(midX, courtRect.top - 4),
      Offset(midX, courtRect.bottom + 4),
      paintNet,
    );
    canvas.drawCircle(Offset(midX, courtRect.top - 4), 3, Paint()..color = primaryColor);
    canvas.drawCircle(Offset(midX, courtRect.bottom + 4), 3, Paint()..color = primaryColor);
  }

  @override
  bool shouldRepaint(covariant CourtBlueprintPainter oldDelegate) =>
      oldDelegate.activeZone != activeZone || oldDelegate.primaryColor != primaryColor;
}
