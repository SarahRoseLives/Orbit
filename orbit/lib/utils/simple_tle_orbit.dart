import 'dart:math';

// Helper to parse TLE epoch (YYDDD.DDDDDDDD) to DateTime
DateTime tleEpochToDateTime(String epochString) {
  // Example: 25192.95387804
  int year = int.parse(epochString.substring(0, 2));
  int dayOfYear = int.parse(epochString.substring(2, 5));
  double dayFraction = double.parse(epochString.substring(5));
  // Convert year (assume 2000+ if <57, else 1900+)
  year += (year < 57) ? 2000 : 1900;
  DateTime jan1 = DateTime.utc(year, 1, 1);
  return jan1.add(Duration(days: dayOfYear - 1)) // DayOfYear is 1-based
      .add(Duration(milliseconds: (dayFraction * 24 * 60 * 60 * 1000).round()));
}

// Extract mean motion (rev/day) from TLE line 2
double parseMeanMotion(String line2) {
  // Mean motion is columns 53-63 (starts at char 52, 11 chars)
  return double.parse(line2.substring(52, 63).trim());
}

// Extract inclination (deg) from TLE line 2
double parseInclination(String line2) {
  // Inclination is columns 9-16
  return double.parse(line2.substring(8, 16).trim());
}

// Calculate satellite subpoint (lat, lon) at given time
Map<String, double> simpleSatelliteSubpoint({
  required String line1,
  required String line2,
  required DateTime nowUtc,
}) {
  // 1. Parse the epoch and mean motion
  String epochString = line1.substring(18, 32).trim();
  DateTime epoch = tleEpochToDateTime(epochString);
  double meanMotion = parseMeanMotion(line2); // rev/day
  double inclination = parseInclination(line2) * pi / 180; // radians

  // 2. Calculate minutes since epoch
  double minutesSinceEpoch = nowUtc.difference(epoch).inSeconds / 60.0;

  // 3. Calculate mean anomaly (radians)
  double meanAnomaly = 2 * pi * ((meanMotion * minutesSinceEpoch) / (24 * 60));
  meanAnomaly = meanAnomaly % (2 * pi);

  // 4. Simple circular orbital plane: assume equatorial for now, add inclination
  double orbitRadius = 6771; // Earth radius + 400km, km (LEO demo)
  double satX = orbitRadius * cos(meanAnomaly);
  double satY = orbitRadius * sin(meanAnomaly) * cos(inclination);

  // 5. Convert to lat/lon assuming Earth's rotation
  double earthRotationRate = 2 * pi / (23.9345 * 3600); // rad/sec
  double secondsSinceEpoch = nowUtc.difference(epoch).inSeconds.toDouble();
  double earthAngle = earthRotationRate * secondsSinceEpoch;

  double longitude = atan2(satY, satX) * 180 / pi - earthAngle * 180 / pi;
  longitude = ((longitude + 180) % 360) - 180;
  double latitude = asin(sin(meanAnomaly) * sin(inclination)) * 180 / pi;

  return {'lat': latitude, 'lon': longitude};
}