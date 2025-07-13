import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:orbit/models/tle_data.dart';
// Import the correct file for getLookAngles
import '../utils/simple_tle_orbit.dart';

class PolarPlot extends StatefulWidget {
  final double? observerLat;
  final double? observerLon;
  final double? observerAlt; // Add observer altitude
  final List<TleLine>? selectedTleLines;
  final bool showOnlyInFootprint;
  final bool observerDot;

  const PolarPlot({
    this.observerLat,
    this.observerLon,
    this.observerAlt, // Add to constructor
    this.selectedTleLines,
    this.showOnlyInFootprint = false,
    this.observerDot = false,
    Key? key,
  }) : super(key: key);

  @override
  State<PolarPlot> createState() => _PolarPlotState();
}

class _PolarPlotState extends State<PolarPlot> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now().toUtc();
  Map<String, Orbit> _orbitCache = {};

  @override
  void initState() {
    super.initState();
    _updateOrbitCache();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now().toUtc();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant PolarPlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTleLines != oldWidget.selectedTleLines) {
      _updateOrbitCache();
    }
  }

  void _updateOrbitCache() {
    if (widget.selectedTleLines != null) {
      _orbitCache = {for (var tle in widget.selectedTleLines!) tle.name: Orbit(tle)};
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  List<Widget> _buildSatelliteDots(double plotRadius, double center) {
    if (widget.selectedTleLines == null ||
        widget.observerLat == null ||
        widget.observerLon == null ||
        widget.observerAlt == null) { // Check for altitude
      return [];
    }

    List<Widget> dots = [];
    final gmst = gstimeFromDateTime(_currentTime);

    for (var tle in widget.selectedTleLines!) {
      final orbit = _orbitCache[tle.name];
      if (orbit == null) continue;

      final prop = orbit.propagate(_currentTime);
      if (prop['r']!.isEmpty) continue;

      // Use the corrected, central getLookAngles function
      final look = getLookAngles(
          widget.observerLat!,
          widget.observerLon!,
          widget.observerAlt! / 1000.0, // Pass altitude in km
          prop['r']!,
          prop['v']!,
          gmst);

      final elevation = look['el']!;

      if (elevation > 0) {
        final azimuthDeg = look['az']!;
        // The angle calculation for plotting is now correct because the azimuth is correct
        final radius = ((90 - elevation) / 90) * (plotRadius - 14);
        final angle = (azimuthDeg - 90) * (pi / 180);
        final x = center + radius * cos(angle) - 5;
        final y = center + radius * sin(angle) - 5;

        dots.add(Positioned(
          left: x,
          top: y,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Tooltip(
              message: tle.name,
              child: const SizedBox.shrink(),
            ),
          ),
        ));
      }
    }

    if (widget.observerDot == true) {
      dots.add(Positioned(
        left: center - 5,
        top: center - 5,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ));
    }
    return dots;
  }

  // REMOVE THE DUPLICATED azElFromEci FUNCTION ENTIRELY

  @override
  Widget build(BuildContext context) {
    const double plotSize = 170;
    const double plotRadius = plotSize / 2;
    const double center = plotSize / 2;

    return Center(
      child: ClipOval(
        child: Container(
          width: plotSize,
          height: plotSize,
          color: Colors.transparent,
          child: Stack(
            children: [
              CustomPaint(
                size: const Size(plotSize, plotSize),
                painter: PolarPlotGridPainter(),
              ),
              ..._buildSatelliteDots(plotRadius, center),
            ],
          ),
        ),
      ),
    );
  }
}
// PolarPlotGridPainter class remains unchanged
class PolarPlotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final Paint gridPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      double radius = size.width / 2 * i / 3;
      canvas.drawCircle(center, radius, gridPaint);
    }
    for (int i = 0; i < 4; i++) {
      double angle = (pi / 2) * i;
      double x = center.dx + (size.width / 2) * cos(angle);
      double y = center.dy + (size.height / 2) * sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }
    final textStyle = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400);
    final azLabels = ['N', 'E', 'S', 'W'];
    final labelDist = (size.width / 2) + 14;
    for (int i = 0; i < 4; i++) {
      double angle = (pi / 2) * i - pi / 2;
      double x = center.dx + labelDist * cos(angle);
      double y = center.dy + labelDist * sin(angle);

      final textSpan = TextSpan(text: azLabels[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: 32);

      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}