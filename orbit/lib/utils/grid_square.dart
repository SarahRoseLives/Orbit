// Maidenhead Grid Square utility
String maidenheadLocator(double lat, double lon) {
  // Adapted from: https://stackoverflow.com/a/31382152/463206
  lat += 90.0;
  lon += 180.0;
  int A = (lon ~/ 20);
  int B = (lat ~/ 10);
  int C = ((lon % 20) ~/ 2);
  int D = ((lat % 10) ~/ 1);
  int E = (((lon % 2) * 12).toInt());
  int F = (((lat % 1) * 24).toInt());
  return "${String.fromCharCode(A + 65)}${String.fromCharCode(B + 65)}"
      "${C}${D}"
      "${String.fromCharCode(E + 65)}${String.fromCharCode(F + 65)}";
}