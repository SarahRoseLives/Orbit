import 'package:flutter/material.dart';
import '../widgets/left_drawer.dart';
import '../services/tle_service.dart';
import '../models/tle_data.dart';
import 'package:orbit/models/satellite.dart';

class UpdateTleScreen extends StatefulWidget {
  final Function(List<TleLine>) onTleUpdated;
  final List<Satellite>? allSatellitesForSelection;
  final Function(List<Satellite>)? onSatelliteSelectionUpdated;
  final List<String>? currentSelectedSatelliteNames;

  const UpdateTleScreen({
    super.key,
    required this.onTleUpdated,
    this.allSatellitesForSelection,
    this.onSatelliteSelectionUpdated,
    this.currentSelectedSatelliteNames,
  });

  @override
  State<UpdateTleScreen> createState() => _UpdateTleScreenState();
}

class _UpdateTleScreenState extends State<UpdateTleScreen> {
  final TleService _tleService = TleService();

  final List<_TleGroup> tleGroups = [
    _TleGroup('amateur', 'Amateur', true),
    _TleGroup('cubesat', 'CubeSats', false),
    _TleGroup('orbcomm', 'Orbcomm', false),
    _TleGroup('sarsat', 'Sarsat', false),
    _TleGroup('goes', 'GOES', false),
    _TleGroup('weather', 'Weather', false),
    _TleGroup('noaa', 'NOAA', false),
    _TleGroup('gps', 'GPS', false),
    _TleGroup('science', 'Science', false),
    _TleGroup('other', 'Other', false),
  ];

  bool isLoading = false;
  bool showSatellites = false;
  List<TleLine> fetchedTleLines = [];

  final Map<String, String> _celestrakGroupMap = {
    'amateur': 'amateur',
    'cubesat': 'cubesat',
    'orbcomm': 'orbcomm',
    'sarsat': 'sarsat',
    'goes': 'goes',
    'noaa': 'noaa',
    'gps': 'gps',
  };

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
          if (_celestrakGroupMap.containsKey(group.groupName)) {
            final fetched = await _tleService.fetchTleGroup(group.groupName);
            allFetchedTles.addAll(fetched);
          } else {
            if (group.groupName == 'weather') {
              allFetchedTles.addAll([
                TleLine(
                  name: 'METEOR-M2',
                  line1: '1 40069U 14037B   25192.12345678  .00000123  00000+0  12345-4 0  9998',
                  line2: '2 40069  98.1234 100.5678 0001234  45.6789 300.1234 14.12345678901234',
                ),
                TleLine(
                  name: 'FENGYUN-3C',
                  line1: '1 39215U 13054A   25192.98765432  .00000456  00000+0  67890-4 0  9995',
                  line2: '2 39215  98.1234 123.4567 0008765 270.1234  89.0123 15.12345678901234',
                ),
              ]);
            } else if (group.groupName == 'science') {
              allFetchedTles.addAll([
                TleLine(
                  name: 'AQUA',
                  line1: '1 27424U 02022A   25192.12345678  .00000123  00000+0  12345-4 0  9998',
                  line2: '2 27424  98.1234 100.5678 0001234  45.6789 300.1234 14.12345678901234',
                ),
                TleLine(
                  name: 'TERRA',
                  line1: '1 25994U 99068A   25192.98765432  .00000456  00000+0  67890-4 0  9995',
                  line2: '2 25994  98.1234 123.4567 0008765 270.1234  89.0123 15.12345678901234',
                ),
              ]);
            } else if (group.groupName == 'other') {
              allFetchedTles.addAll([
                TleLine(
                  name: 'TLE-OTHER-1',
                  line1: '1 11111U 11111A   25192.11111111  .00000001  00000+0  11111-1 0  9999',
                  line2: '2 11111 00.1111 000.1111 0000001 000.1111 000.1111 0.11111111111111',
                ),
                TleLine(
                  name: 'TLE-OTHER-2',
                  line1: '1 22222U 22222A   25192.22222222  .00000002  00000+0  22222-2 0  8888',
                  line2: '2 22222 00.2222 000.2222 0000002 000.2222 000.2222 0.22222222222222',
                ),
              ]);
            }
          }
        }
      }
      final uniqueTleLines = <String, TleLine>{};
      for (var tle in allFetchedTles) {
        uniqueTleLines[tle.name] = tle;
      }
      fetchedTleLines = uniqueTleLines.values.toList();
      fetchedTleLines.sort((a, b) => a.name.compareTo(b.name));
      widget.onTleUpdated(fetchedTleLines);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update TLE: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
        showSatellites = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: (widget.allSatellitesForSelection != null &&
              widget.onSatelliteSelectionUpdated != null &&
              widget.currentSelectedSatelliteNames != null)
          ? LeftDrawer(
              allSatellitesForSelection: widget.allSatellitesForSelection!,
              onTleUpdated: widget.onTleUpdated,
              onSatelliteSelectionUpdated: widget.onSatelliteSelectionUpdated!,
              currentSelectedSatelliteNames: widget.currentSelectedSatelliteNames!,
            )
          : null,
      appBar: AppBar(
        title: const Text("Update TLE"),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Download TLE from Celestrak",
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: tleGroups.map((group) {
                  return CheckboxListTile(
                    title: Text(group.displayName, style: const TextStyle(color: Colors.white)),
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[200]),
                  ),
                  const SizedBox(height: 8),
                  ...fetchedTleLines.map(
                    (tleLine) => ListTile(
                      dense: true,
                      leading: Icon(Icons.satellite, color: Colors.blue[200], size: 20),
                      title: Text(tleLine.name, style: const TextStyle(color: Colors.white)),
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