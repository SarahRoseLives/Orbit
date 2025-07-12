import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../utils/simple_tle_orbit.dart';

class PolarPlot extends StatefulWidget {
  final double? observerLat;
  final double? observerLon;
  final List<dynamic>? selectedTleLines; // List<TleLine> in your app
  final bool showOnlyInFootprint;
  final bool observerDot;

  const PolarPlot({
    this.observerLat,
    this.observerLon,
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

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now().toUtc();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  List<Widget> _buildSatelliteDots(double plotRadius, double center) {
    if (widget.selectedTleLines == null ||
        widget.observerLat == null ||
        widget.observerLon == null) {
      return [];
    }

    List<Widget> dots = [];
    for (var tle in widget.selectedTleLines!) {
      try {
        final pos = simpleSatelliteSubpoint(
          line1: tle.line1,
          line2: tle.line2,
          nowUtc: _currentTime,
        );
        double dLat = (pos['lat']! - widget.observerLat!) * pi / 180.0;
        double dLon = (pos['lon']! - widget.observerLon!) * pi / 180.0;
        double obsLatRad = widget.observerLat! * pi / 180.0;
        double centralAngle = sqrt(dLat * dLat + pow(cos(obsLatRad) * dLon, 2));
        double elevation = 90 - centralAngle * 180 / pi;

        // Optionally show only satellites in observer's radio footprint
        if (widget.showOnlyInFootprint) {
          // Use a typical LEO altitude for footprint, or update as needed
          const satAltitudeKm = 400.0;
          const earthRadiusKm = 6378.137;
          double angleLimit = acos(earthRadiusKm / (earthRadiusKm + satAltitudeKm));
          if (centralAngle > angleLimit) continue;
        }

        if (elevation > 0) {
          double azimuth = atan2(
            sin(dLon) * cos(pos['lat']! * pi / 180.0),
            cos(obsLatRad) * sin(pos['lat']! * pi / 180.0) -
                sin(obsLatRad) * cos(pos['lat']! * pi / 180.0) * cos(dLon),
          );
          double azimuthDeg = (azimuth * 180 / pi + 360) % 360;
          double radius = ((90 - elevation) / 90) * (plotRadius - 14); // keep inside
          double angle = (azimuthDeg - 90) * (pi / 180);
          double x = center + radius * cos(angle) - 5;
          double y = center + radius * sin(angle) - 5;

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
      } catch (_) {}
    }
    // Show observer dot in center if requested
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

  @override
  Widget build(BuildContext context) {
    // Plot size and center (smaller, more padding)
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
                size: Size(plotSize, plotSize),
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

class PolarPlotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final Paint gridPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw circles for elevation rings (every 30°, 60°, 90°)
    for (int i = 1; i <= 3; i++) {
      double radius = size.width / 2 * i / 3;
      canvas.drawCircle(center, radius, gridPaint);
    }

    // Draw main axes (N, E, S, W)
    for (int i = 0; i < 4; i++) {
      double angle = (pi / 2) * i;
      double x = center.dx + (size.width / 2) * cos(angle);
      double y = center.dy + (size.height / 2) * sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // Draw azimuth labels slightly outside the outermost ring
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