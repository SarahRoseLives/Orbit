import 'package:http/http.dart' as http;
import 'package:orbit/models/tle_data.dart';

class TleService {
  static const String _celestrakBaseUrl =
      'https://celestrak.org/NORAD/elements/gp.php';

  Future<List<TleLine>> fetchTleGroup(String groupName) async {
    final url = Uri.parse('$_celestrakBaseUrl?GROUP=$groupName&FORMAT=tle');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return _parseTleData(response.body);
    } else {
      throw Exception(
          'Failed to load TLE data for $groupName. Status code: ${response.statusCode}');
    }
  }

  // New method to fetch TLE from a full, custom URL
  Future<List<TleLine>> fetchTleFromUrl(String urlString) async {
    final url = Uri.parse(urlString);
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return _parseTleData(response.body);
    } else {
      throw Exception(
          'Failed to load TLE data from $urlString. Status code: ${response.statusCode}');
    }
  }

  List<TleLine> _parseTleData(String rawTleData) {
    final List<TleLine> tleLines = [];
    final lines = rawTleData.split('\n');
    for (int i = 0; i < lines.length; i += 3) {
      if (i + 2 < lines.length &&
          lines[i].isNotEmpty &&
          lines[i + 1].isNotEmpty &&
          lines[i + 2].isNotEmpty) {
        // TLE names sometimes have leading/trailing spaces, trim them.
        final name = lines[i].trim().replaceAll(RegExp(r'\s+'), ' ');
        final line1 = lines[i + 1].trim();
        final line2 = lines[i + 2].trim();
        tleLines.add(TleLine(name: name, line1: line1, line2: line2));
      }
    }
    return tleLines;
  }
}