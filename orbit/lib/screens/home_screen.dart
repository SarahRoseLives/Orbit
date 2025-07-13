import 'package:flutter/material.dart';
import '../widgets/left_drawer.dart';
import '../widgets/satellite_pass_badge.dart';
import '../widgets/polar_plot.dart';
import 'package:orbit/models/tle_data.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/grid_square.dart';
import '../utils/simple_tle_orbit.dart';
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
  String? _orbitPathSatelliteName;
  late Timer _timer;
  DateTime _currentTime = DateTime.now().toUtc();
  String? _nextPassSatName;
  DateTime? _nextPassAosUtc;
  Map<String, Orbit> _orbitCache = {};

  @override
  void initState() {
    super.initState();
    _updateOrbitCache();
    _selectedSatelliteName =
        widget.selectedSatellites.isNotEmpty ? widget.selectedSatellites[0] : null;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(mounted) {
        setState(() {
          _currentTime = DateTime.now().toUtc();
          // Pass computation is heavy, let's do it less often if needed
          // For now, 1 second is fine for demonstration
          _computeNextPass();
        });
      }
    });
    _computeNextPass();
  }

  void _updateOrbitCache() {
    _orbitCache = {for (var tle in widget.selectedTleLines) tle.name: Orbit(tle)};
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTleLines != oldWidget.selectedTleLines) {
      _updateOrbitCache();
    }
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

  Orbit? _getOrbitForName(String? name) {
    if (name == null) return null;
    return _orbitCache[name];
  }

  void _computeNextPass() {
    if (widget.selectedTleLines.isEmpty || widget.currentPosition == null) {
      _nextPassSatName = null;
      _nextPassAosUtc = null;
      return;
    }
    final observerLat = widget.currentPosition!.latitude;
    final observerLon = widget.currentPosition!.longitude;
    final observerAlt = widget.currentPosition!.altitude / 1000.0; // convert to km
    final now = _currentTime;

    DateTime? soonestAosUtc;
    String? soonestSatName;

    for (final tle in widget.selectedTleLines) {
      final orbit = _getOrbitForName(tle.name);
      if (orbit == null) continue;

      DateTime? satAos;
      bool wasBelow = true;
      // Search up to 36 hours ahead
      for (int i = 0; i < 60 * 36; i++) { // 1-minute steps for 36 hours
        final t = now.add(Duration(minutes: i));
        final gmst = gstimeFromDateTime(t);
        final prop = orbit.propagate(t);
        if (prop['r']!.isEmpty) continue;

        final lookAngles = getLookAngles(
            observerLat, observerLon, observerAlt, prop['r']!, prop['v']!, gmst);
        final isAbove = lookAngles['el']! > 0;

        if (wasBelow && isAbove) {
          // Refine search to find precise AOS by stepping back one minute and searching second by second
          DateTime searchStart = t.subtract(const Duration(minutes: 1));
          for (int j = 0; j < 60; j++) {
            final fineTime = searchStart.add(Duration(seconds: j));
            final fineGmst = gstimeFromDateTime(fineTime);
            final fineProp = orbit.propagate(fineTime);
            if (fineProp['r']!.isEmpty) continue;
            final fineLookAngles = getLookAngles(
                observerLat, observerLon, observerAlt, fineProp['r']!, fineProp['v']!, fineGmst);
            if (fineLookAngles['el']! > 0) {
              satAos = fineTime;
              break;
            }
          }
          break; // Found AOS for this satellite, move to the next one
        }
        wasBelow = !isAbove;
      }
      if (satAos != null && (soonestAosUtc == null || satAos.isBefore(soonestAosUtc))) {
        soonestAosUtc = satAos;
        soonestSatName = tle.name;
      }
    }
    _nextPassSatName = soonestSatName;
    _nextPassAosUtc = soonestAosUtc;
  }

  Widget _buildMovingSatelliteBadges(double mapWidth, double mapHeight) {
    if (widget.selectedTleLines.isEmpty) return const SizedBox.shrink();
    List<Widget> badges = [];
    final gmst = gstimeFromDateTime(_currentTime);

    for (var tle in widget.selectedTleLines) {
      final orbit = _getOrbitForName(tle.name);
      if (orbit == null) continue;

      final prop = orbit.propagate(_currentTime);
      if (prop['r']!.isEmpty) continue;

      final geo = eciToGeodetic(prop['r']!, gmst);
      double satLat = geo['lat']!;
      double satLon = geo['lon']!;
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
    }
    return Stack(children: badges);
  }

  List<List<Offset>> _computeOrbitPathSegments(
      Orbit orbit, double mapWidth, double mapHeight, DateTime centerTime) {
    const int stepMinutes = 1;
    const int totalMinutes = 90;
    List<List<Offset>> segments = [];
    List<Offset> currentSegment = [];
    double? lastLon;

    for (int dtMin = -totalMinutes ~/ 2; dtMin <= totalMinutes ~/ 2; dtMin += stepMinutes) {
      final t = centerTime.add(Duration(minutes: dtMin));
      final gmst = gstimeFromDateTime(t);
      final prop = orbit.propagate(t);
      if (prop['r']!.isEmpty) continue;

      final geo = eciToGeodetic(prop['r']!, gmst);
      final lat = geo['lat']!;
      final lon = geo['lon']!;

      double x = ((lon + 180) / 360) * mapWidth;
      double y = ((90 - lat) / 180) * mapHeight;

      if (lastLon != null && (lon - lastLon).abs() > 180) {
        if (currentSegment.isNotEmpty) segments.add(currentSegment);
        currentSegment = [];
      }
      if (x >= 0 && x <= mapWidth) {
        currentSegment.add(Offset(x, y));
      }
      lastLon = lon;
    }
    if (currentSegment.isNotEmpty) segments.add(currentSegment);

    segments.removeWhere((seg) => seg.length < 2);
    return segments;
  }

  Widget _buildOrbitPath(double mapWidth, double mapHeight) {
    final orbit = _getOrbitForName(_orbitPathSatelliteName);
    if (orbit == null) return const SizedBox.shrink();

    final segments = _computeOrbitPathSegments(orbit, mapWidth, mapHeight, _currentTime);

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

    final orbit = _getOrbitForName(_selectedSatelliteName);
    if (orbit == null) return Text('Calculating for $_selectedSatelliteName...');

    final gmst = gstimeFromDateTime(_currentTime);
    final prop = orbit.propagate(_currentTime);
    if (prop['r']!.isEmpty) {
      return Text('Error propagating $_selectedSatelliteName',
          style: const TextStyle(fontSize: 15, color: Colors.red));
    }

    final geo = eciToGeodetic(prop['r']!, gmst);
    final look = getLookAngles(widget.currentPosition!.latitude,
        widget.currentPosition!.longitude, widget.currentPosition!.altitude / 1000.0, prop['r']!, prop['v']!, gmst);

    final sspLoc = maidenheadLocator(geo['lat']!, geo['lon']!);
    final velocityMiSec = sqrt(pow(prop['v']![0], 2) + pow(prop['v']![1], 2) + pow(prop['v']![2], 2)) * 0.621371;

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
        Text("Azimuth: ${look['az']!.toStringAsFixed(2)}°", style: const TextStyle(fontSize: 15)),
        Text("Elevation: ${look['el']!.toStringAsFixed(2)}°", style: const TextStyle(fontSize: 15)),
        Text("Slant Range: ${(look['range']! * 0.621371).toStringAsFixed(0)} mi",
            style: const TextStyle(fontSize: 15)),
        Text("Range Rate: ${(look['rangeRate']! * 0.621371).toStringAsFixed(3)} mi/sec",
            style: const TextStyle(fontSize: 15)),
        Text("SSP Loc: $sspLoc", style: const TextStyle(fontSize: 15)),
        Text("Altitude: ${(geo['alt']! * 0.621371).toStringAsFixed(0)} mi",
            style: const TextStyle(fontSize: 15)),
        Text("Velocity: ${velocityMiSec.toStringAsFixed(3)} mi/sec",
            style: const TextStyle(fontSize: 15)),
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
      ),
      drawer: LeftDrawer(
        allSatellitesForSelection: widget.allSatellitesForSelection,
        onTleUpdated: widget.onTleUpdated,
        onSatelliteSelectionUpdated: widget.onSatelliteSelectionUpdated,
        currentSelectedSatelliteNames: widget.selectedSatellites,
      ),
      body: Column(
        children: [
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
                          "${_currentTime.toLocal().toString().substring(0, 19)} EDT",
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
                      if (_orbitPathSatelliteName != null)
                        _buildOrbitPath(actualMapWidth, actualMapHeight),
                      _buildMovingSatelliteBadges(actualMapWidth, actualMapHeight),
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
                                      shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
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
                observerAlt: widget.currentPosition?.altitude,
                selectedTleLines: widget.selectedTleLines.isNotEmpty ? widget.selectedTleLines : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  bool shouldRepaint(_OrbitPathPainterSegments oldDelegate) => true;
}