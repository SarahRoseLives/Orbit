import 'dart:math';

// sgp4.dart: A Dart port of the SGP4 pure Python library.
// This file contains the core logic for satellite propagation.

// Gravity Constants for WGS72
class Gravity {
  final double mu;
  final double radiusearthkm;
  final double xke;
  final double tumin;
  final double j2;
  final double j3;
  final double j4;
  final double j3oj2;

  const Gravity({
    required this.mu,
    required this.radiusearthkm,
    required this.xke,
    required this.tumin,
    required this.j2,
    required this.j3,
    required this.j4,
    required this.j3oj2,
  });
}

const wgs72 = Gravity(
  mu: 398600.8, // in km3 / s2
  radiusearthkm: 6378.135, // km
  xke: 0.0743669161, // sqrt(mu/earth_radius^3) * 60
  tumin: 13.4468396968953, // 1.0 / xke
  j2: 0.001082616,
  j3: -0.00000253881,
  j4: -0.00000165597,
  j3oj2: -0.0023455686,
);

// Stores the state of a single satellite
class Satrec {
  // Directly from TLE
  late String line1;
  late String line2;
  late int satnum;
  late int epochyr;
  late double epochdays;
  late double ndot;
  late double nddot;
  late double bstar;
  late double inclo;
  late double nodeo;
  late double ecco;
  late double argpo;
  late double mo;
  late double no_kozai;

  // Values computed from TLE
  late double jdsatepoch;
  late double jdsatepochF;
  late double a;
  late double altp;
  late double alta;

  // Internal state for propagation
  late double no_unkozai;
  late String method;
  late double mdot;
  late double nodedot;
  late double argpdot;
  late double gsto;
  late double omgcof, xmcof, nodecf;
  late double t2cof, t3cof, t4cof, t5cof;
  late double sinmao, delmo;
  late double cc1, cc4, cc5, d2, d3, d4;
  late double eta;
  late double x1mth2, x7thm1;
  late double con41; // <-- This was missing

  int error = 0;

  Satrec.fromTle(this.line1, this.line2) {
    _twoline2rv();
  }

  void _twoline2rv() {
    const deg2rad = pi / 180.0;
    const xpdotp = 1440.0 / (2.0 * pi);

    satnum = int.parse(line1.substring(2, 7));
    epochyr = int.parse(line1.substring(18, 20));
    epochdays = double.parse(line1.substring(20, 32));
    ndot = double.parse(line1.substring(33, 43));
    nddot = double.parse('${line1.substring(44, 45)}.${line1.substring(45, 50)}') *
        pow(10, int.parse(line1.substring(50, 52)));
    bstar = double.parse('${line1.substring(53, 54)}.${line1.substring(54, 59)}') *
        pow(10, int.parse(line1.substring(59, 61)));

    inclo = double.parse(line2.substring(8, 16));
    nodeo = double.parse(line2.substring(17, 25));
    ecco = double.parse('0.${line2.substring(26, 33)}');
    argpo = double.parse(line2.substring(34, 42));
    mo = double.parse(line2.substring(43, 51));
    no_kozai = double.parse(line2.substring(52, 63));

    // Convert to standard units
    no_kozai = no_kozai / xpdotp; // rad/min
    nddot = nddot / (xpdotp * 1440.0 * 1440.0);
    ndot = ndot / (xpdotp * 1440.0);
    inclo *= deg2rad;
    nodeo *= deg2rad;
    argpo *= deg2rad;
    mo *= deg2rad;

    // Find epoch
    final year = (epochyr < 57) ? epochyr + 2000 : epochyr + 1900;
    final (mon, day, hr, minute, sec) = days2mdhms(year, epochdays);
    final (jd, fr) = jday(year, mon, day, hr, minute, sec);
    jdsatepoch = jd;
    jdsatepochF = fr;

    _sgp4init();
  }

  void _sgp4init() {
    const x2o3 = 2.0 / 3.0;

    final eccsq = ecco * ecco;
    final omeosq = 1.0 - eccsq;
    final rteosq = sqrt(omeosq);
    final cosio = cos(inclo);
    final cosio2 = cosio * cosio;

    // Un-kozai the mean motion
    final ak = pow(wgs72.xke / no_kozai, x2o3);
    final d1 = 0.75 * wgs72.j2 * (3.0 * cosio2 - 1.0) / (rteosq * omeosq);
    final del_ = d1 / (ak * ak);
    final adel = ak * (1.0 - del_ * del_ - del_ * (1.0 / 3.0 + 134.0 * del_ * del_ / 81.0));
    no_unkozai = no_kozai / (1.0 + d1 / (adel * adel));

    final ao = pow(wgs72.xke / no_unkozai, x2o3);
    final sinio = sin(inclo);
    final po = ao * omeosq;
    final con42 = 1.0 - 5.0 * cosio2;
    con41 = -con42 - cosio2 - cosio2;
    final posq = po * po;
    final rp = ao * (1.0 - ecco);

    method = (2 * pi / no_unkozai >= 225.0) ? 'd' : 'n';

    gsto = gstime(jdsatepoch + jdsatepochF);

    // For near-Earth satellites
    final sfour = 1.0 + 78.0 / wgs72.radiusearthkm;
    final qzms24 = pow((120.0 - 78.0) / wgs72.radiusearthkm, 4);
    final perige = (rp - 1.0) * wgs72.radiusearthkm;

    final pinvsq = 1.0 / posq;
    final tsi = 1.0 / (ao - sfour);
    eta = ao * ecco * tsi;
    final etasq = eta * eta;
    final eeta = ecco * eta;
    final psisq = (1.0 - etasq).abs();
    final coef = qzms24 * pow(tsi, 4.0);
    final coef1 = coef / pow(psisq, 3.5);

    cc1 = coef1 *
        no_unkozai *
        (ao * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq)) +
            0.375 * wgs72.j2 * tsi / psisq * con41 * (8.0 + 3.0 * etasq * (8.0 + etasq)));

    final cc3 = (ecco > 1.0e-4) ? -2.0 * coef * tsi * wgs72.j3oj2 * no_unkozai * sinio / ecco : 0.0;
    x1mth2 = 1.0 - cosio2;
    cc4 = 2.0 *
        no_unkozai *
        coef1 *
        ao *
        omeosq *
        (eta * (2.0 + 0.5 * etasq) +
            ecco * (0.5 + 2.0 * etasq) -
            wgs72.j2 * tsi / (ao * psisq) * (-3.0 * con41 * (1.0 - 2.0 * eeta + etasq * (1.5 - 0.5 * eeta)) +
                    0.75 * x1mth2 * (2.0 * etasq - eeta * (1.0 + etasq)) * cos(2.0 * argpo)));
    cc5 = 2.0 * coef1 * ao * omeosq * (1.0 + 2.75 * (etasq + eeta) + eeta * etasq);
    final cosio4 = cosio2 * cosio2;
    final temp1 = 1.5 * wgs72.j2 * pinvsq * no_unkozai;
    final temp2 = 0.5 * temp1 * wgs72.j2 * pinvsq;
    final temp3 = -0.46875 * wgs72.j4 * pinvsq * pinvsq * no_unkozai;

    mdot = no_unkozai +
        0.5 * temp1 * rteosq * con41 +
        0.0625 * temp2 * rteosq * (13.0 - 78.0 * cosio2 + 137.0 * cosio4);
    argpdot = (-0.5 * temp1 * con42 +
        0.0625 * temp2 * (7.0 - 114.0 * cosio2 + 395.0 * cosio4) +
        temp3 * (3.0 - 36.0 * cosio2 + 49.0 * cosio4));
    final xhdot1 = -temp1 * cosio;
    nodedot = xhdot1 +
        (0.5 * temp2 * (4.0 - 19.0 * cosio2) + 2.0 * temp3 * (3.0 - 7.0 * cosio2)) * cosio;

    omgcof = bstar * cc3 * cos(argpo);
    xmcof = (ecco > 1.0e-4) ? -x2o3 * coef * bstar / eeta : 0.0;
    nodecf = 3.5 * omeosq * xhdot1 * cc1;
    t2cof = 1.5 * cc1;

    final delmotemp = 1.0 + eta * cos(mo);
    delmo = pow(delmotemp, 3).toDouble();
    sinmao = sin(mo);

    x7thm1 = 7.0 * cosio2 - 1.0;

    d2 = 4.0 * ao * tsi * cc1 * cc1;
    final temp = d2 * tsi * cc1 / 3.0;
    d3 = (17.0 * ao + sfour) * temp;
    d4 = 0.5 * temp * ao * tsi * (221.0 * ao + 31.0 * sfour) * cc1;

    t3cof = d2 + 2.0 * cc1 * cc1;
    t4cof = 0.25 * (3.0 * d3 + cc1 * (12.0 * d2 + 10.0 * cc1 * cc1));
    t5cof = 0.2 * (3.0 * d4 + 12.0 * cc1 * d3 + 6.0 * d2 * d2 + 15.0 * (cc1 * cc1) * (2.0 * d2 + cc1 * cc1));
  }

  Map<String, List<double>> sgp4(double tsince) {
    const twopi = 2.0 * pi;
    final vkmpersec = wgs72.radiusearthkm * wgs72.xke / 60.0;

    error = 0;

    final xmdf = mo + mdot * tsince;
    final argpdf = argpo + argpdot * tsince;
    final nodedf = nodeo + nodedot * tsince;
    var argpm = argpdf;
    var mm = xmdf;
    final t2 = tsince * tsince;
    var nodem = nodedf + nodecf * t2;
    var tempa = 1.0 - cc1 * tsince;
    var tempe = bstar * cc4 * tsince;
    var templ = t2cof * t2;

    if (method != 'd') {
      final delomg = omgcof * tsince;
      final delmtemp = 1.0 + eta * cos(xmdf);
      final delm = xmcof * (pow(delmtemp, 3) - delmo);
      final temp = delomg + delm;
      mm = xmdf + temp;
      argpm = argpdf - temp;
      final t3 = t2 * tsince;
      final t4 = t3 * tsince;
      tempa = tempa - d2 * t2 - d3 * t3 - d4 * t4;
      tempe = tempe + bstar * cc5 * (sin(mm) - sinmao);
      templ = templ + t3cof * t3 + t4 * (t4cof + tsince * t5cof);
    }

    var nm = no_unkozai;
    var em = ecco;
    var inclm = inclo;

    if (nm <= 0.0) {
      error = 2;
      return {'r': [], 'v': []};
    }

    final am = pow((wgs72.xke / nm), 2.0 / 3.0) * tempa * tempa;
    nm = wgs72.xke / pow(am, 1.5);
    em = em - tempe;

    if (em >= 1.0 || em < -0.001) {
      error = 1;
      return {'r': [], 'v': []};
    }
    if (em < 1.0e-6) em = 1.0e-6;

    mm = mm + no_unkozai * templ;
    final xlm = mm + argpm + nodem;
    nodem = nodem % twopi;
    argpm = argpm % twopi;
    mm = (xlm - argpm - nodem) % twopi;

    final sinim = sin(inclm);
    final cosim = cos(inclm);
    final ep = em;
    final xincp = inclm;
    final argpp = argpm;
    final nodep = nodem;
    final mp = mm;

    final axnl = ep * cos(argpp);
    final temp0 = 1.0 / (am * (1.0 - ep * ep));
    final aynl = ep * sin(argpp); // deep space has extra terms here
    final xl = mp + argpp + nodep; // deep space has extra terms here

    final u = (xl - nodep) % twopi;
    var eo1 = u;
    var tem5 = 9999.9;
    var ktr = 1;
    while (tem5.abs() >= 1.0e-12 && ktr <= 10) {
      final sineo1 = sin(eo1);
      final coseo1 = cos(eo1);
      tem5 = 1.0 - coseo1 * axnl - sineo1 * aynl;
      tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5;
      if (tem5.abs() >= 0.95) {
        tem5 = tem5 > 0.0 ? 0.95 : -0.95;
      }
      eo1 = eo1 + tem5;
      ktr = ktr + 1;
    }

    final ecose = axnl * cos(eo1) + aynl * sin(eo1);
    final esine = axnl * sin(eo1) - aynl * cos(eo1);
    final el2 = axnl * axnl + aynl * aynl;
    final pl = am * (1.0 - el2);
    if (pl < 0.0) {
      error = 4;
      return {'r': [], 'v': []};
    }

    final rl = am * (1.0 - ecose);
    final rdotl = sqrt(am) * esine / rl;
    final rvdotl = sqrt(pl) / rl;
    final betal = sqrt(1.0 - el2);
    final temp = esine / (1.0 + betal);
    final sinu = am / rl * (sin(eo1) - aynl - axnl * temp);
    final cosu = am / rl * (cos(eo1) - axnl + aynl * temp);
    final su = atan2(sinu, cosu);
    final sin2u = (cosu + cosu) * sinu;
    final cos2u = 1.0 - 2.0 * sinu * sinu;
    final temp1 = 0.5 * wgs72.j2 * (1.0 / pl);
    final temp2 = temp1 * (1.0 / pl);

    final mrt = rl * (1.0 - 1.5 * temp2 * betal * con41) + 0.5 * temp1 * x1mth2 * cos2u;

    final xnode = nodep + 1.5 * temp2 * cosim * sin2u;
    final xinc = xincp + 1.5 * temp2 * cosim * sinim * cos2u;
    final mvt = rdotl - nm * temp1 * x1mth2 * sin2u / wgs72.xke;
    final rvdot = rvdotl + nm * temp1 * (x1mth2 * cos2u + 1.5 * con41) / wgs72.xke;

    final sinsu = sin(su);
    final cossu = cos(su);
    final snod = sin(xnode);
    final cnod = cos(xnode);
    final sini = sin(xinc);
    final cosi = cos(xinc);
    final xmx = -snod * cosi;
    final xmy = cnod * cosi;
    final ux = xmx * sinsu + cnod * cossu;
    final uy = xmy * sinsu + snod * cossu;
    final uz = sini * sinsu;
    final vx = xmx * cossu - cnod * sinsu;
    final vy = xmy * cossu - snod * sinsu;
    final vz = sini * cossu;

    final mr = mrt * wgs72.radiusearthkm;
    final r = [mr * ux, mr * uy, mr * uz];
    final v = [
      (mvt * ux + rvdot * vx) * vkmpersec,
      (mvt * uy + rvdot * vy) * vkmpersec,
      (mvt * uz + rvdot * vz) * vkmpersec,
    ];
    if (mrt < 1.0) {
      error = 6;
    }
    return {'r': r, 'v': v};
  }
}

// Helper functions made public for use across the app
(int, int, int, int, double) days2mdhms(int year, double days) {
  var dayOfYear = days.floor();
  var dayFraction = days - dayOfYear;
  var second = dayFraction * 86400.0;
  var minute = (second / 60.0).floor();
  second -= (minute * 60.0);
  var hour = (minute / 60.0).floor();
  minute = minute % 60;

  final is_leap = year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
  final (month, day) = _day_of_year_to_month_day(dayOfYear, is_leap);
  return (month, day, hour, minute, second);
}

(int, int) _day_of_year_to_month_day(int day_of_year, bool is_leap) {
  final month_lengths = [0, 31, is_leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var month = 1;
  while (day_of_year > month_lengths[month]) {
    day_of_year -= month_lengths[month];
    month++;
  }
  return (month, day_of_year);
}

(double, double) jday(int year, int mon, int day, int hr, int minute, double sec) {
  final jd = (367.0 * year -
          (7 * (year + ((mon + 9) / 12.0).floor()) * 0.25).floor() +
          (275 * mon / 9.0).floor() +
          day +
          1721013.5)
      .toDouble();
  final fr = (sec + minute * 60.0 + hr * 3600.0) / 86400.0;
  return (jd, fr);
}

double gstime(double jdut1) {
  const twopi = 2.0 * pi;
  const deg2rad = pi / 180.0;
  final tut1 = (jdut1 - 2451545.0) / 36525.0;
  var temp = -6.2e-6 * tut1 * tut1 * tut1 +
      0.093104 * tut1 * tut1 +
      (876600.0 * 3600 + 8640184.812866) * tut1 +
      67310.54841;
  temp = (temp * deg2rad / 240.0) % twopi;
  if (temp < 0.0) {
    temp += twopi;
  }
  return temp;
}