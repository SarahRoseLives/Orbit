import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/select_satellites_screen.dart';
import '../screens/update_tle_screen.dart';
import '../models/tle_data.dart'; // Changed import
import 'package:orbit/models/satellite.dart';

class LeftDrawer extends StatelessWidget {
  final List<Satellite> allSatellitesForSelection;
  final Function(List<TleLine>) onTleUpdated;
  final Function(List<Satellite>) onSatelliteSelectionUpdated;
  final List<String> currentSelectedSatelliteNames; // Names of currently selected satellites

  const LeftDrawer({
    super.key,
    required this.allSatellitesForSelection,
    required this.onTleUpdated,
    required this.onSatelliteSelectionUpdated,
    required this.currentSelectedSatelliteNames,
  });

  @override
  Widget build(BuildContext context) {
    // Convert currentSelectedSatelliteNames back to Satellite objects for initial selection
    final List<Satellite> initialSelectedSatellites = allSatellitesForSelection
        .where((sat) => currentSelectedSatelliteNames.contains(sat.name))
        .toList();

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            child: Center(
              child: Text(
                "Orbit",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text("Home / Overview"),
            onTap: () {
              // No need to pushReplacement if already on HomeScreen
              Navigator.of(context).pop(); // Close the drawer
            },
          ),
          ListTile(
            leading: Icon(Icons.map),
            title: Text("Map View"),
            onTap: () {
              // Implement when you have a dedicated map screen
              // Navigator.of(context).pop();
              // Navigator.of(context).pushReplacement(
              //    MaterialPageRoute(builder: (context) => MapScreen()),
              // );
            },
          ),
          ListTile(
            leading: Icon(Icons.satellite_alt),
            title: Text("Satellite Selection"),
            onTap: () async {
              Navigator.of(context).pop(); // Close the drawer first
              final updatedSelection = await Navigator.of(context).push<List<Satellite>>(
                MaterialPageRoute(
                  builder: (context) => SelectSatellitesScreen(
                    allSatellites: allSatellitesForSelection,
                    selectedSatellitesInitial: initialSelectedSatellites,
                  ),
                ),
              );
              if (updatedSelection != null) {
                onSatelliteSelectionUpdated(updatedSelection);
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.update),
            title: Text("Update TLE"),
            onTap: () async {
              Navigator.of(context).pop(); // Close the drawer first
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UpdateTleScreen(onTleUpdated: onTleUpdated),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text("Settings"),
            onTap: () {
              // Implement when you have a settings screen
              // Navigator.of(context).pop();
              // Navigator.of(context).pushReplacement(
              //    MaterialPageRoute(builder: (context) => SettingsScreen()),
              // );
            },
          ),
        ],
      ),
    );
  }
}