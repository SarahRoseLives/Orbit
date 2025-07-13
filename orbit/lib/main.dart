import 'package:flutter/material.dart';
import 'package:orbit/models/tle_data.dart';
import 'package:orbit/services/tle_storage_service.dart'; // Import storage service
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'screens/home_screen.dart';
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
  final TleStorageService _tleStorageService = TleStorageService();
  static const String _selectedSatellitesKey = 'selected_satellite_names';

  List<TleLine> _allTleLines = [];
  List<TleLine> _selectedTleLines = [];
  List<Satellite> _allSatellitesForSelection = [];
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getLocation();
  }

  Future<void> _loadData() async {
    // Load all TLEs from storage
    List<TleLine> loadedTles = await _tleStorageService.loadTleLines();

    // If storage is empty, initialize with dummy data and save it
    if (loadedTles.isEmpty) {
      loadedTles = _getInitialDummyTles();
      await _tleStorageService.saveTleLines(loadedTles);
    }

    // Load selected satellite names from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final selectedNames = prefs.getStringList(_selectedSatellitesKey) ??
        ['OSCAR 7 (AO-7)', 'SO-50', 'ISS (ZARYA)']; // Default selection

    // Filter the loaded TLEs to get the selected ones
    final selectedTles = loadedTles
        .where((tle) => selectedNames.contains(tle.name))
        .toList();

    setState(() {
      _allTleLines = loadedTles;
      _selectedTleLines = selectedTles;
      _updateAllSatellitesForSelection();
    });
  }

  Future<void> _getLocation() async {
    final loc = await LocationService().getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = loc;
      });
    }
  }

  List<TleLine> _getInitialDummyTles() {
    // This is the fallback initial data
    return [
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
  }

  void _updateAllSatellitesForSelection() {
    _allSatellitesForSelection = _allTleLines.map((tle) {
      final catnum = tle.line1.substring(2, 7);
      return Satellite(tle.name, catnum);
    }).toList();
  }

  void _onTleUpdated(List<TleLine> newTleLines) async {
    // Save the new list of all TLEs
    await _tleStorageService.saveTleLines(newTleLines);

    final currentSelectedNames = _selectedTleLines.map((tle) => tle.name).toList();

    // Re-evaluate selected satellites based on new TLEs
    final newSelectedTles = newTleLines
        .where((newTle) => currentSelectedNames.contains(newTle.name))
        .toList();

    setState(() {
      _allTleLines = newTleLines;
      _selectedTleLines = newSelectedTles;
      _updateAllSatellitesForSelection();
    });

    // Also save the (potentially updated) list of selected names
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _selectedSatellitesKey, newSelectedTles.map((tle) => tle.name).toList());
  }

  void _onSatelliteSelectionUpdated(List<Satellite> newSelectedSatellites) async {
    final newSelectedNames = newSelectedSatellites.map((s) => s.name).toList();

    // Save the new selection to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedSatellitesKey, newSelectedNames);

    setState(() {
      _selectedTleLines = _allTleLines
          .where((tle) => newSelectedNames.contains(tle.name))
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
      home: _allTleLines.isEmpty
          ? Scaffold(
              body: Center(
                  child:
                      CircularProgressIndicator())) // Show loading indicator
          : HomeScreen(
              selectedSatellites:
                  _selectedTleLines.map((tle) => tle.name).toList(),
              selectedTleLines: _selectedTleLines,
              allSatellitesForSelection: _allSatellitesForSelection,
              onTleUpdated: _onTleUpdated,
              onSatelliteSelectionUpdated: _onSatelliteSelectionUpdated,
              currentPosition: _currentPosition,
            ),
      debugShowCheckedModeBanner: false,
    );
  }
}