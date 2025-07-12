import 'package:flutter/material.dart';
import 'package:orbit/models/tle_data.dart';
import 'screens/home_screen.dart';
import 'screens/select_satellites_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'services/location_service.dart';
import 'package:orbit/models/satellite.dart';

void main() {
  runApp(OrbitApp());
}

class OrbitApp extends StatefulWidget {
  @override
  State<OrbitApp> createState() => _OrbitAppState();
}

class _OrbitAppState extends State<OrbitApp> {
  // Initial dummy data for all satellites and selected satellites
  // In a real app, this would be loaded from persistent storage
  List<TleLine> _allTleLines = [];
  List<TleLine> _selectedTleLines = [];

  // Placeholder for the "all satellites" list that will be used by SelectSatellitesScreen
  List<Satellite> _allSatellitesForSelection = [];

  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initializeSatellites();
    _getLocation();
  }

  Future<void> _getLocation() async {
    final loc = await LocationService().getCurrentPosition();
    setState(() {
      _currentPosition = loc;
    });
  }

  void _initializeSatellites() {
    // Populate initial dummy TLE data for demonstration
    // In a real application, this would come from a saved state or initial fetch
    _allTleLines = [
      TleLine(
          name: 'OSCAR 7 (AO-7)',
          line1:
              '1 07530U 74089B   25192.95387804 -.00000037  00000+0  57653-4 0  9996',
          line2:
              '2 07530 101.9934 197.5627 0012601  61.3979 313.7346 12.53690118317886'),
      TleLine(
          name: 'PHASE 3B (AO-10)',
          line1:
              '1 14129U 83058B   25192.43303499 -.00000115  00000+0  00000+0 0  9991',
          line2:
              '2 14129  26.5746 277.1771 6066072  20.9247 355.8407  2.05870077288479'),
      TleLine(
          name: 'UOSAT 2 (UO-11)',
          line1:
              '1 14781U 84021B   25193.18400329  .00000935  00000+0  10396-3 0  9991',
          line2:
              '2 14781  97.7562 158.9124 0006672 220.6374 139.4346 14.89461001227492'),
      TleLine(
          name: 'SO-50',
          line1:
              '1 27607U 02058C   25192.12345678  .00000123  00000+0  12345-4 0  9998',
          line2:
              '2 27607  98.1234 100.5678 0001234  45.6789 300.1234 14.12345678901234'),
      TleLine(
          name: 'ISS (ZARYA)',
          line1:
              '1 25544U 98067A   25192.98765432  .00000456  00000+0  67890-4 0  9995',
          line2:
              '2 25544  51.6432 123.4567 0008765 270.1234  89.0123 15.12345678901234'),
    ];

    // Initialize selected satellites (e.g., from a saved preference)
    _selectedTleLines = [
      _allTleLines[0], // OSCAR 7
      _allTleLines[3], // SO-50
      _allTleLines[4], // ISS
    ];

    _updateAllSatellitesForSelection();
  }

  void _updateAllSatellitesForSelection() {
    _allSatellitesForSelection = _allTleLines.map((tle) {
      // Extract NORAD Cat ID from TLE line1
      final catnum = tle.line1.substring(2, 7);
      return Satellite(tle.name, catnum);
    }).toList();
  }

  // This function will be passed to UpdateTleScreen to receive updated TLEs
  void _onTleUpdated(List<TleLine> newTleLines) {
    setState(() {
      _allTleLines = newTleLines;
      // Re-evaluate selected satellites based on new TLEs, keeping existing if possible
      _selectedTleLines = _selectedTleLines
          .where(
              (selected) => newTleLines.any((newTle) => newTle.name == selected.name))
          .toList();
      _updateAllSatellitesForSelection(); // Update the selection list
    });
  }

  // This function will be passed to SelectSatellitesScreen to receive updated selection
  void _onSatelliteSelectionUpdated(List<Satellite> newSelectedSatellites) {
    setState(() {
      _selectedTleLines = _allTleLines
          .where(
              (tle) => newSelectedSatellites.any((selected) => selected.name == tle.name))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbit - Satellite Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        selectedSatellites: _selectedTleLines.map((tle) => tle.name).toList(),
        selectedTleLines: _selectedTleLines, // <-- pass this!
        allSatellitesForSelection: _allSatellitesForSelection,
        onTleUpdated: _onTleUpdated,
        onSatelliteSelectionUpdated: _onSatelliteSelectionUpdated,
        currentPosition: _currentPosition,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}