import 'package:flutter/material.dart';

class SatellitePassBadge extends StatelessWidget {
  final String label;
  final bool highlight;
  const SatellitePassBadge(this.label, {this.highlight = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight
          ? Colors.yellow.withOpacity(0.33)
          : Colors.yellow.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.yellow[200],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}