import 'package:flutter/material.dart';
import '../widgets/left_drawer.dart';
import '../services/tle_service.dart';
import '../models/tle_data.dart';
import 'package:orbit/models/satellite.dart';

class UpdateTleScreen extends StatefulWidget {
  final Function(List<TleLine>) onTleUpdated;
  // Make these properties required
  final List<Satellite> allSatellitesForSelection;
  final Function(List<Satellite>) onSatelliteSelectionUpdated;
  final List<String> currentSelectedSatelliteNames;

  const UpdateTleScreen({
    super.key,
    required this.onTleUpdated,
    // Update the constructor
    required this.allSatellitesForSelection,
    required this.onSatelliteSelectionUpdated,
    required this.currentSelectedSatelliteNames,
  });

  @override
  State<UpdateTleScreen> createState() => _UpdateTleScreenState();
}

class _UpdateTleScreenState extends State<UpdateTleScreen> {
  final TleService _tleService = TleService();

  // Updated list of TLE groups as per your request
  final List<_TleGroup> tleGroups = [
    _TleGroup('amateur', 'Amateur', false),
    _TleGroup('active_amateur', 'Active Amateur', true),
    _TleGroup('cubesat', 'CubeSats', false),
    _TleGroup('orbcomm', 'Corbcomm', false), // Display name per request
    _TleGroup('sarsat', 'Sarsat', false),
    _TleGroup('weather', 'Weather', false),
    _TleGroup('noaa', 'NOAA', false),
    _TleGroup('gps-ops', 'GPS', false), // CelesTrak group for GPS is gps-ops
  ];

  bool isLoading = false;
  bool showSatellites = false;
  List<TleLine> fetchedTleLines = [];

  void _updateTle() async {
    setState(() {
      isLoading = true;
      showSatellites = false;
      fetchedTleLines = [];
    });

    try {
      List<TleLine> allFetchedTles = [];
      for (var group in tleGroups) {
        if (group.selected) {
          List<TleLine> fetched;
          if (group.groupName == 'active_amateur') {
            // Fetch from the custom URL for Active Amateur sats
            fetched = await _tleService.fetchTleFromUrl(
                'https://sarahsforge.dev/downloads/TLE/active_amateur.php');
          } else {
            // Fetch from Celestrak for all other groups
            fetched = await _tleService.fetchTleGroup(group.groupName);
          }
          allFetchedTles.addAll(fetched);
        }
      }

      if (!mounted) return; // Check if the widget is still in the tree

      // Remove duplicates by using a map
      final uniqueTleLines = <String, TleLine>{};
      for (var tle in allFetchedTles) {
        uniqueTleLines[tle.name] = tle;
      }
      fetchedTleLines = uniqueTleLines.values.toList();
      fetchedTleLines.sort((a, b) => a.name.compareTo(b.name));

      // Callback to update the main app state
      widget.onTleUpdated(fetchedTleLines);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update TLE: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        showSatellites = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The drawer is now built unconditionally
      drawer: LeftDrawer(
        allSatellitesForSelection: widget.allSatellitesForSelection,
        onTleUpdated: widget.onTleUpdated,
        onSatelliteSelectionUpdated: widget.onSatelliteSelectionUpdated,
        currentSelectedSatelliteNames: widget.currentSelectedSatelliteNames,
      ),
      appBar: AppBar(
        title: const Text("Update TLE"),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Download TLE Data",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Select the satellite groups to update. When ready, tap 'Update TLE'.",
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: tleGroups.map((group) {
                  return CheckboxListTile(
                    title: Text(group.displayName,
                        style: const TextStyle(color: Colors.white)),
                    value: group.selected,
                    onChanged: (val) {
                      setState(() {
                        group.selected = val ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Colors.blue,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () {
                      _updateTle();
                    },
              icon: const Icon(Icons.cloud_download),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text("Update TLE"),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 0),
                backgroundColor: Colors.blue,
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (showSatellites && fetchedTleLines.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    "Satellites updated (${fetchedTleLines.length}):",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green[200]),
                  ),
                  const SizedBox(height: 8),
                  ...fetchedTleLines.map(
                    (tleLine) => ListTile(
                      dense: true,
                      leading: Icon(Icons.satellite,
                          color: Colors.blue[200], size: 20),
                      title: Text(tleLine.name,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        tleLine.line1.substring(2, 7),
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ),
                  ),
                ],
              )
            else if (showSatellites && fetchedTleLines.isEmpty && !isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    "No TLE data fetched for the selected groups. Please select groups and try again.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TleGroup {
  final String groupName;
  final String displayName;
  bool selected;
  _TleGroup(this.groupName, this.displayName, this.selected);
}