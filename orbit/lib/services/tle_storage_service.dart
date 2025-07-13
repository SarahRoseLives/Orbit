import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/tle_data.dart';

class TleStorageService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/tle_data.json');
  }

  Future<List<TleLine>> loadTleLines() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((json) => TleLine.fromJson(json)).toList();
    } catch (e) {
      print("Error loading TLE lines: $e");
      return [];
    }
  }

  Future<File> saveTleLines(List<TleLine> tleLines) async {
    final file = await _localFile;
    final jsonList = tleLines.map((tle) => tle.toJson()).toList();
    return file.writeAsString(json.encode(jsonList));
  }
}