import 'dart:math';
import 'sgp4.dart';
import '../models/tle_data.dart'; // <-- This was missing

// A wrapper class to hold both the Satrec object and the original TLE data
class Orbit {
  final TleLine tle;
  final Satrec satrec;

  Orbit(this.tle) : satrec = Satrec.fromTle(tle.line1, tle.line2);

  // Propagates the satellite to a specific UTC time.
  // Returns position (r) and velocity (v) vectors in TEME (ECI) coordinates (km and km/s).
  Map<String, List<double>> propagate(DateTime utc) {
    final (jd, fr) = jdayFromDateTime(utc);
    final minutesSinceEpoch =
        (jd - satrec.jdsatepoch) * 1440.0 + (fr - satrec.jdsatepochF) * 1440.0;

    return satrec.sgp4(minutesSinceEpoch);
  }
}

// Converts ECI (Earth-Centered Inertial) coordinates to Geodetic (lat, lon, alt)
Map<String, double> eciToGeodetic(List<double> r, double gmst) {
  const double rad2deg = 180 / pi;
  final double x = r[0];
  final double y = r[1];
  final double z = r[2];

  // ECI to ECEF rotation
  final double lonRad = atan2(y, x) - gmst;
  final double r_ = sqrt(x * x + y * y);

  // ECEF to Geodetic
  final double a = wgs72.radiusearthkm;
  const double f = 1 / 298.26; // WGS72 flattening
  const double e2 = 2 * f - f * f;

  double latRad = atan2(z, r_);
  double c = cos(latRad);
  double s = sin(latRad);
  double N = a / sqrt(1 - e2 * s * s);

  for (int i = 0; i < 5; i++) {
    // Iterate to refine latitude
    c = cos(latRad);
    s = sin(latRad);
    N = a / sqrt(1 - e2 * s * s);
    latRad = atan2(z + N * e2 * s, r_);
  }

  final double alt = r_ / cos(latRad) - N;

  return {
    'lat': latRad * rad2deg,
    'lon': (lonRad * rad2deg + 180) % 360 - 180, // Normalize lon to -180, 180
    'alt': alt,
  };
}


// Calculates Greenwich Mean Sidereal Time for a given UTC DateTime
double gstimeFromDateTime(DateTime utc) {
  final (jd, fr) = jdayFromDateTime(utc);
  return gstime(jd + fr);
}

// Calculates Julian Date from a DateTime object
(double, double) jdayFromDateTime(DateTime utc) {
  return jday(utc.year, utc.month, utc.day, utc.hour, utc.minute,
      utc.second + utc.millisecond / 1000.0);
}

// Correct Az/El calculation from ECI position and velocity vectors
Map<String, double> getLookAngles(
    double obsLat, double obsLon, double obsAlt, List<double> rSatEci, List<double> vSatEci, double gmst) {
  const double rad2deg = 180 / pi;
  const double deg2rad = pi / 180;

  final obsLatRad = obsLat * deg2rad;
  final obsLonRad = obsLon * deg2rad;

  // ECEF of Observer
  final double obsX = (wgs72.radiusearthkm + obsAlt) * cos(obsLatRad) * cos(obsLonRad);
  final double obsY = (wgs72.radiusearthkm + obsAlt) * cos(obsLatRad) * sin(obsLonRad);
  final double obsZ = (wgs72.radiusearthkm + obsAlt) * sin(obsLatRad);
  final List<double> rObsEcef = [obsX, obsY, obsZ];

  // ECEF of Satellite
  final satX = rSatEci[0] * cos(gmst) + rSatEci[1] * sin(gmst);
  final satY = rSatEci[0] * -sin(gmst) + rSatEci[1] * cos(gmst);
  final satZ = rSatEci[2];

  // Range vector in ECEF
  final rx = satX - obsX;
  final ry = satY - obsY;
  final rz = satZ - obsZ;
  final List<double> rangeVec = [rx, ry, rz];

  // Topocentric-Horizon coordinates (SEZ)
  final s = sin(obsLatRad) * cos(obsLonRad) * rx + sin(obsLatRad) * sin(obsLonRad) * ry - cos(obsLatRad) * rz;
  final e = -sin(obsLonRad) * rx + cos(obsLonRad) * ry;
  final z = cos(obsLatRad) * cos(obsLonRad) * rx + cos(obsLatRad) * sin(obsLonRad) * ry + sin(obsLatRad) * rz;

  final range = sqrt(rx*rx + ry*ry + rz*rz);
  final el = asin(z / range);
  var az = atan2(e, -s); // Correct formula for Azimuth from North (E, N)
  if (az < 0) {
    az += 2 * pi; // Normalize to 0-2PI range
  }
  // Range Rate
  // Simplified by using dot product of range vector and velocity vector
  final vSatEcef = [
      vSatEci[0] * cos(gmst) + vSatEci[1] * sin(gmst),
      vSatEci[0] * -sin(gmst) + vSatEci[1] * cos(gmst),
      vSatEci[2]
  ];
  final rangeRate = (rangeVec[0]*vSatEcef[0] + rangeVec[1]*vSatEcef[1] + rangeVec[2]*vSatEcef[2]) / range;

  return {'az': az * rad2deg, 'el': el * rad2deg, 'range': range, 'rangeRate': rangeRate};
}