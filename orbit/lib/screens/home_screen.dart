import 'package:flutter/material.dart';
import '../widgets/left_drawer.dart';
import '../widgets/satellite_pass_badge.dart';
import '../widgets/polar_plot.dart';
import 'package:orbit/models/tle_data.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/grid_square.dart';
import '../utils/simple_tle_orbit.dart';
import 'package:orbit/screens/select_satellites_screen.dart'; // <-- Needed for Satellite
import 'dart:async';
import 'dart:math';
import 'package:orbit/models/satellite.dart';

class HomeScreen extends StatefulWidget {
  final List<String> selectedSatellites;
  final List<TleLine> selectedTleLines;
  final List<Satellite> allSatellitesForSelection;
  final Function(List<TleLine>) onTleUpdated;
  final Function(List<Satellite>) onSatelliteSelectionUpdated;
  final Position? currentPosition;

  const HomeScreen({
    super.key,
    required this.selectedSatellites,
    required this.selectedTleLines,
    required this.allSatellitesForSelection,
    required this.onTleUpdated,
    required this.onSatelliteSelectionUpdated,
    required this.currentPosition,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedSatelliteName;
  String? _orbitPathSatelliteName; // For orbit path highlighting
  late Timer _timer;
  DateTime _currentTime = DateTime.now().toUtc();

  // Next pass info
  String? _nextPassSatName;
  DateTime? _nextPassAosUtc;

  @override
  void initState() {
    super.initState();
    _selectedSatelliteName = widget.selectedSatellites.isNotEmpty
        ? widget.selectedSatellites[0]
        : null;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now().toUtc();
        _computeNextPass();
      });
    });
    _computeNextPass();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSatellites.isNotEmpty &&
        !widget.selectedSatellites.contains(_selectedSatelliteName)) {
      _selectedSatelliteName = widget.selectedSatellites[0];
    } else if (widget.selectedSatellites.isEmpty) {
      _selectedSatelliteName = null;
    }
    if (_orbitPathSatelliteName != null &&
        !widget.selectedSatellites.contains(_orbitPathSatelliteName)) {
      _orbitPathSatelliteName = null;
    }
    _computeNextPass();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Returns the TleLine for a given name or null
  TleLine? _getTleForName(String? name) {
    if (name == null) return null;
    return widget.selectedTleLines.firstWhere(
      (t) => t.name == name,
      orElse: () => widget.selectedTleLines.first,
    );
  }

  // --- Next pass calculation ---
  // This is a very simple brute force search for next AOS for any selected satellite
  // For a real app use a pass prediction library!
  void _computeNextPass() {
    if (widget.selectedTleLines.isEmpty || widget.currentPosition == null) {
      _nextPassSatName = null;
      _nextPassAosUtc = null;
      return;
    }
    final observerLat = widget.currentPosition!.latitude;
    final observerLon = widget.currentPosition!.longitude;
    final now = _currentTime;

    DateTime? soonestAosUtc;
    String? soonestSatName;

    for (final tle in widget.selectedTleLines) {
      // Search up to 36 hours ahead, in 15s steps
      DateTime? satAos;
      bool above = false;
      for (int i = 0; i < 60 * 36 * 4; i++) {
        final t = now.add(Duration(seconds: i * 15));
        final satPos = simpleSatelliteSubpoint(
          line1: tle.line1,
          line2: tle.line2,
          nowUtc: t,
        );
        final satLat = satPos['lat']!;
        final satLon = satPos['lon']!;
        final azEl = _azEl(observerLat, observerLon, satLat, satLon);
        if (!above && azEl[1] > 0) {
          satAos = t;
          break;
        }
        above = azEl[1] > 0;
      }
      if (satAos != null &&
          (soonestAosUtc == null || satAos.isBefore(soonestAosUtc))) {
        soonestAosUtc = satAos;
        soonestSatName = tle.name;
      }
    }

    _nextPassSatName = soonestSatName;
    _nextPassAosUtc = soonestAosUtc;
  }

  // Helper: returns [azimuth, elevation]
  List<double> _azEl(
      double observerLat, double observerLon, double satLat, double satLon) {
    final observerLatRad = observerLat * pi / 180;
    final observerLonRad = observerLon * pi / 180;
    final satLatRad = satLat * pi / 180;
    final satLonRad = satLon * pi / 180;
    final dLon = satLonRad - observerLonRad;
    final cosD = sin(observerLatRad) * sin(satLatRad) +
        cos(observerLatRad) * cos(satLatRad) * cos(dLon);
    final centralAngle = acos(cosD);
    final elevationRad = asin(
      (sin(satLatRad) - sin(observerLatRad) * cos(centralAngle)) /
          (cos(observerLatRad) * sin(centralAngle) + 1e-10),
    );
    double elevationDeg = elevationRad * 180 / pi;
    double azRad = atan2(
      sin(dLon),
      cos(observerLatRad) * tan(satLatRad) - sin(observerLatRad) * cos(dLon),
    );
    double azimuthDeg = (azRad * 180 / pi + 360) % 360;
    return [azimuthDeg, elevationDeg];
  }

  Widget _buildMovingSatelliteBadges(double mapWidth, double mapHeight) {
    if (widget.selectedTleLines.isEmpty) return const SizedBox.shrink();
    List<Widget> badges = [];
    for (var tle in widget.selectedTleLines) {
      try {
        final pos = simpleSatelliteSubpoint(
          line1: tle.line1,
          line2: tle.line2,
          nowUtc: _currentTime,
        );
        double satLat = pos['lat']!;
        double satLon = pos['lon']!;
        const double badgeWidth = 64;
        const double badgeHeight = 28;
        double x = ((satLon + 180) / 360) * mapWidth - badgeWidth / 2;
        double y = ((90 - satLat) / 180) * mapHeight - badgeHeight / 2;
        x = x.clamp(0.0, mapWidth - badgeWidth);
        y = y.clamp(0.0, mapHeight - badgeHeight);

        String badgeLabel =
            tle.name.contains('(') ? tle.name.split('(')[1].replaceAll(')', '') : tle.name;

        badges.add(Positioned(
          left: x,
          top: y,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _orbitPathSatelliteName =
                    (_orbitPathSatelliteName == tle.name) ? null : tle.name;
                _selectedSatelliteName = tle.name;
              });
            },
            child: SatellitePassBadge(
              badgeLabel,
              highlight: _orbitPathSatelliteName == tle.name,
            ),
          ),
        ));
      } catch (_) {}
    }
    return Stack(children: badges);
  }

  List<List<Offset>> _computeOrbitPathSegments(
      TleLine tle, double mapWidth, double mapHeight, DateTime centerTime) {
    // Draw the orbit for +/- 45 minutes from now, every 1 minute
    const int stepMinutes = 1;
    const int totalMinutes = 90; // 45 before, 45 after
    List<List<Offset>> segments = [];
    List<Offset> currentSegment = [];
    double? lastLon;

    for (int dtMin = -totalMinutes ~/ 2; dtMin <= totalMinutes ~/ 2; dtMin += stepMinutes) {
      final t = centerTime.add(Duration(minutes: dtMin));
      final pos = simpleSatelliteSubpoint(
        line1: tle.line1,
        line2: tle.line2,
        nowUtc: t,
      );
      final lat = pos['lat']!;
      final lon = pos['lon']!;

      double x = ((lon + 180) / 360) * mapWidth;
      double y = ((90 - lat) / 180) * mapHeight;

      // If jump in longitude is over 180°, start a new segment (handle wrap)
      if (lastLon != null && (lon - lastLon).abs() > 180) {
        if (currentSegment.isNotEmpty) segments.add(currentSegment);
        currentSegment = [];
      }
      // Only add points that are in the map horizontal range
      if (x >= 0 && x <= mapWidth) {
        currentSegment.add(Offset(x, y));
      }
      lastLon = lon;
    }
    if (currentSegment.isNotEmpty) segments.add(currentSegment);

    // Remove empty segments that may result from above
    segments.removeWhere((seg) => seg.length < 2);

    return segments;
  }

  Widget _buildOrbitPath(double mapWidth, double mapHeight) {
    final tle = _getTleForName(_orbitPathSatelliteName);
    if (tle == null) return const SizedBox.shrink();

    final segments = _computeOrbitPathSegments(tle, mapWidth, mapHeight, _currentTime);

    return CustomPaint(
      painter: _OrbitPathPainterSegments(segments: segments),
      size: Size(mapWidth, mapHeight),
    );
  }

  Widget _buildSatelliteInfoPanel() {
    if (_selectedSatelliteName == null ||
        widget.selectedTleLines.isEmpty ||
        widget.currentPosition == null) {
      return const Text('No satellite selected.', style: TextStyle(fontSize: 15));
    }

    final tle = _getTleForName(_selectedSatelliteName);
    if (tle == null) return const Text('No satellite selected.', style: TextStyle(fontSize: 15));

    final observerLat = widget.currentPosition!.latitude;
    final observerLon = widget.currentPosition!.longitude;

    final satPos = simpleSatelliteSubpoint(
      line1: tle.line1,
      line2: tle.line2,
      nowUtc: _currentTime,
    );
    final satLat = satPos['lat']!;
    final satLon = satPos['lon']!;

    final observerLatRad = observerLat * pi / 180;
    final observerLonRad = observerLon * pi / 180;
    final satLatRad = satLat * pi / 180;
    final satLonRad = satLon * pi / 180;
    const earthRadiusKm = 6378.137;
    final satAltitudeKm = 400.0;

    final dLon = satLonRad - observerLonRad;
    final cosD = sin(observerLatRad) * sin(satLatRad) +
        cos(observerLatRad) * cos(satLatRad) * cos(dLon);
    final centralAngle = acos(cosD);

    final rangeKm = sqrt(pow(earthRadiusKm + satAltitudeKm, 2) +
        pow(earthRadiusKm, 2) -
        2 * (earthRadiusKm + satAltitudeKm) * earthRadiusKm * cos(centralAngle));
    final slantRangeMiles = rangeKm * 0.621371;

    final elevationRad = asin(
      (sin(satLatRad) - sin(observerLatRad) * cos(centralAngle)) /
          (cos(observerLatRad) * sin(centralAngle) + 1e-10),
    );
    double elevationDeg = elevationRad * 180 / pi;

    double azRad = atan2(
      sin(dLon),
      cos(observerLatRad) * tan(satLatRad) - sin(observerLatRad) * cos(dLon),
    );
    double azimuthDeg = (azRad * 180 / pi + 360) % 360;

    double footprintMiles =
        2 * pi * earthRadiusKm * cos(centralAngle / 2) * 0.621371;

    final rangeRateMiSec = 3.1;
    final sspLoc = maidenheadLocator(satLat, satLon);
    final velocityMiSec = 4.67;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          value: _selectedSatelliteName,
          dropdownColor: Colors.grey[900],
          items: widget.selectedSatellites
              .map((satName) => DropdownMenuItem(
                    value: satName,
                    child: Text(
                      satName,
                      style: TextStyle(
                        color: Colors.blue[100],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ))
              .toList(),
          underline: Container(),
          onChanged: (val) {
            setState(() {
              _selectedSatelliteName = val!;
            });
          },
        ),
        const SizedBox(height: 8),
        Text("Azimuth: ${azimuthDeg.toStringAsFixed(2)}°", style: const TextStyle(fontSize: 15)),
        Text("Elevation: ${elevationDeg.toStringAsFixed(2)}°", style: const TextStyle(fontSize: 15)),
        Text("Slant Range: ${slantRangeMiles.toStringAsFixed(0)} mi", style: const TextStyle(fontSize: 15)),
        Text("Range Rate: ${rangeRateMiSec.toStringAsFixed(3)} mi/sec", style: const TextStyle(fontSize: 15)),
        const Text(
          "Next Event: AO-85: 2025/07/12 04:19:41",
          style: TextStyle(fontSize: 15),
        ),
        Text("SSP Loc: $sspLoc", style: const TextStyle(fontSize: 15)),
        Text("Footprint: ${footprintMiles.toStringAsFixed(0)} mi", style: const TextStyle(fontSize: 15)),
        Text("Altitude: ${satAltitudeKm.toStringAsFixed(0)} mi", style: const TextStyle(fontSize: 15)),
        Text("Velocity: ${velocityMiSec.toStringAsFixed(3)} mi/sec", style: const TextStyle(fontSize: 15)),
        Row(
          children: [
            const Text("Visibility: ", style: TextStyle(fontSize: 15)),
            Chip(
              label: const Text("Eclipsed", style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.blueGrey,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const double mapAspectRatio = 2.0;
    const double mapVerticalMargin = 8.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double mapWidth = screenWidth - (mapVerticalMargin * 2);
    final double mapHeight = mapWidth / mapAspectRatio;
    const double dotSize = 12.0;

    // --- Format next pass string ---
    String nextPassString = "None";
    if (_nextPassSatName != null && _nextPassAosUtc != null) {
      final dt = _nextPassAosUtc!;
      final now = _currentTime;
      final diff = dt.difference(now);
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      final label =
          _nextPassSatName!.contains('(') ? _nextPassSatName!.split('(')[1].replaceAll(')', '') : _nextPassSatName!;
      nextPassString =
          "Next: $label in ${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orbit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ],
      ),
      drawer: LeftDrawer(
        allSatellitesForSelection: widget.allSatellitesForSelection,
        onTleUpdated: widget.onTleUpdated,
        onSatelliteSelectionUpdated: widget.onSatelliteSelectionUpdated,
        currentSelectedSatelliteNames: widget.selectedSatellites,
      ),
      body: Column(
        children: [
          // MAP
          Container(
            margin: const EdgeInsets.all(mapVerticalMargin),
            width: mapWidth,
            height: mapHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double actualMapWidth = constraints.maxWidth;
                  final double actualMapHeight = constraints.maxHeight;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/world_map.jpg',
                          fit: BoxFit.fill,
                          color: Colors.black.withOpacity(0.33),
                          colorBlendMode: BlendMode.darken,
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 16,
                        child: Text(
                          "2025/07/12 ${TimeOfDay.fromDateTime(_currentTime.toLocal()).format(context)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            nextPassString,
                            style: TextStyle(
                              color: Colors.green[200],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      // Orbit path for selected satellite (if any)
                      if (_orbitPathSatelliteName != null)
                        _buildOrbitPath(actualMapWidth, actualMapHeight),
                      // Moving satellite badges (real-time, tappable)
                      _buildMovingSatelliteBadges(actualMapWidth, actualMapHeight),
                      // Our location dot
                      if (widget.currentPosition != null)
                        Builder(
                          builder: (context) {
                            double lat = widget.currentPosition!.latitude;
                            double lon = widget.currentPosition!.longitude;
                            double x = ((lon + 180) / 360) * actualMapWidth - dotSize / 2;
                            double y = ((90 - lat) / 180) * actualMapHeight - dotSize / 2;
                            x = x.clamp(0.0, actualMapWidth - dotSize);
                            y = y.clamp(0.0, actualMapHeight - dotSize);
                            String grid = maidenheadLocator(lat, lon);

                            return Positioned(
                              left: x,
                              top: y,
                              child: Column(
                                children: [
                                  Container(
                                    width: dotSize,
                                    height: dotSize,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                  Text(
                                    grid,
                                    style: TextStyle(
                                      color: Colors.red[100],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          // SATELLITE INFO PANEL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey[900]?.withOpacity(0.95),
              child: Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                child: _buildSatelliteInfoPanel(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: PolarPlot(
                observerLat: widget.currentPosition?.latitude,
                observerLon: widget.currentPosition?.longitude,
                selectedTleLines: widget.selectedTleLines.isNotEmpty ? widget.selectedTleLines : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Painter for orbit path line (segments)
class _OrbitPathPainterSegments extends CustomPainter {
  final List<List<Offset>> segments;
  _OrbitPathPainterSegments({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (final segment in segments) {
      if (segment.length < 2) continue;
      final path = Path()..moveTo(segment[0].dx, segment[0].dy);
      for (final pt in segment.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPathPainterSegments oldDelegate) {
    return true;
  }
}