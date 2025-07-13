// widgets/left_drawer.dart

import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/select_satellites_screen.dart';
import '../screens/update_tle_screen.dart';
import '../models/tle_data.dart';
import 'package:orbit/models/satellite.dart';

class LeftDrawer extends StatelessWidget {
  final List<Satellite> allSatellitesForSelection;
  final Function(List<TleLine>) onTleUpdated;
  final Function(List<Satellite>) onSatelliteSelectionUpdated;
  final List<String> currentSelectedSatelliteNames;

  const LeftDrawer({
    super.key,
    required this.allSatellitesForSelection,
    required this.onTleUpdated,
    required this.onSatelliteSelectionUpdated,
    required this.currentSelectedSatelliteNames,
  });

  @override
  Widget build(BuildContext context) {
    final List<Satellite> initialSelectedSatellites = allSatellitesForSelection
        .where((sat) => currentSelectedSatelliteNames.contains(sat.name))
        .toList();

    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Center(
              child: Text(
                "Orbit",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Home / Overview"),
            onTap: () {
              // ⭐️ CORRECTED CODE HERE ⭐️
              // This will pop all routes until the first one (HomeScreen) is reached.
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text("Map View"),
            onTap: () {
              // Not implemented
            },
          ),
          ListTile(
            leading: const Icon(Icons.satellite_alt),
            title: const Text("Satellite Selection"),
            onTap: () async {
              Navigator.of(context).pop();
              final updatedSelection =
                  await Navigator.of(context).push<List<Satellite>>(
                MaterialPageRoute(
                  builder: (context) => SelectSatellitesScreen(
                    allSatellites: allSatellitesForSelection,
                    selectedSatellitesInitial: initialSelectedSatellites,
                    onTleUpdated: onTleUpdated,
                    onSatelliteSelectionUpdated: onSatelliteSelectionUpdated,
                    currentSelectedSatelliteNames: currentSelectedSatelliteNames,
                  ),
                ),
              );
              if (updatedSelection != null) {
                onSatelliteSelectionUpdated(updatedSelection);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.update),
            title: const Text("Update TLE"),
            onTap: () async {
              Navigator.of(context).pop();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UpdateTleScreen(
                    onTleUpdated: onTleUpdated,
                    allSatellitesForSelection: allSatellitesForSelection,
                    onSatelliteSelectionUpdated: onSatelliteSelectionUpdated,
                    currentSelectedSatelliteNames: currentSelectedSatelliteNames,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
              // Not implemented
            },
          ),
        ],
      ),
    );
  }
}