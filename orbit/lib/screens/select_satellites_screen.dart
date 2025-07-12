import 'package:flutter/material.dart';
import 'package:orbit/models/tle_data.dart'; // Import the TleLine model
import 'package:orbit/models/satellite.dart';

class SelectSatellitesScreen extends StatefulWidget {
  final List<Satellite> allSatellites; // All available satellites from TLE data
  final List<Satellite> selectedSatellitesInitial; // Currently selected satellites

  const SelectSatellitesScreen({
    super.key,
    required this.allSatellites,
    required this.selectedSatellitesInitial,
  });

  @override
  State<SelectSatellitesScreen> createState() => _SelectSatellitesScreenState();
}

class _SelectSatellitesScreenState extends State<SelectSatellitesScreen> {
  late List<Satellite> available;
  late List<Satellite> selected;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize selected list with a deep copy to avoid modifying the original list
    selected = List<Satellite>.from(widget.selectedSatellitesInitial);
    // Initialize available by filtering out satellites already in 'selected'
    available = widget.allSatellites
        .where((sat) => !selected.any((s) => s.catnum == sat.catnum))
        .toList();
  }

  void addSatellite(Satellite sat) {
    setState(() {
      available.remove(sat);
      selected.add(sat);
      selected.sort((a, b) => a.name.compareTo(b.name)); // Keep selected list sorted
    });
  }

  void removeSatellite(Satellite sat) {
    setState(() {
      selected.remove(sat);
      available.add(sat);
      available.sort((a, b) => a.name.compareTo(b.name)); // Keep available list sorted
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filtering based on search
    List<Satellite> filteredAvailable = available
        .where((sat) =>
            sat.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            sat.catnum.contains(searchQuery))
        .toList();

    List<Satellite> filteredSelected = selected
        .where((sat) =>
            sat.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            sat.catnum.contains(searchQuery))
        .toList();

    return Scaffold(
      // No drawer here: put it only on your main screens, not modal selection flows.
      appBar: AppBar(
        title: const Text("Satellite Selection"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  labelText: "Search satellites",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
                onChanged: (val) {
                  setState(() {
                    searchQuery = val;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    "Tap to add or remove satellites from your tracking list.",
                    style: TextStyle(
                        color: Colors.grey[400], fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  // Selected satellites
                  if (filteredSelected.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                      child: Text(
                        "Tracking",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[300],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ...filteredSelected.map(
                    (sat) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        key: ValueKey(sat.catnum),
                        leading: Icon(Icons.radio_button_checked, color: Colors.green[400]),
                        title: Text(sat.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text("Catnum: ${sat.catnum}", style: TextStyle(color: Colors.grey[400])),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: Colors.red[300]),
                          tooltip: "Remove from tracking",
                          onPressed: () => removeSatellite(sat),
                        ),
                        tileColor: Colors.green.withOpacity(0.07),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        onTap: () => removeSatellite(sat),
                      ),
                    ),
                  ),
                  if (filteredSelected.isNotEmpty) const SizedBox(height: 12),

                  // Available satellites
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text(
                      "Available",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[200],
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (filteredAvailable.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          "No satellites found.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),
                  ...filteredAvailable.map(
                    (sat) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        key: ValueKey(sat.catnum),
                        leading: Icon(Icons.radio_button_unchecked, color: Colors.blue[200]),
                        title: Text(sat.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text("Catnum: ${sat.catnum}", style: TextStyle(color: Colors.grey[400])),
                        trailing: IconButton(
                          icon: Icon(Icons.add_circle_outline, color: Colors.blue[300]),
                          tooltip: "Add to tracking",
                          onPressed: () => addSatellite(sat),
                        ),
                        tileColor: Colors.blue.withOpacity(0.06),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        onTap: () => addSatellite(sat),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16)
                ],
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                    ),
                    child: const Text("Cancel"),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, selected); // Return the updated selected list
                    },
                    child: const Text("Save"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}