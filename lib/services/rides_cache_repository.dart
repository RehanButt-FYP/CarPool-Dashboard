import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride_document.dart';

class RidesCacheRepository {
  static const _watermarkKey = 'rides_sync_watermark_ms';

  Future<DateTime?> getSyncWatermark() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_watermarkKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setSyncWatermark(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_watermarkKey, value.millisecondsSinceEpoch);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_watermarkKey);
    final file = await _cacheFile();
    if (await file.exists()) await file.delete();
  }

  Future<List<RideDocument>> loadRides() async {
    final file = await _cacheFile();
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      if (raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) => RideDocument.fromMap(
              Map<String, dynamic>.from(e as Map),
              id: e['id']?.toString() ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRides(List<RideDocument> rides) async {
    final file = await _cacheFile();
    await file.writeAsString(jsonEncode(rides.map((r) => r.toMap()).toList()));
  }

  Future<void> mergeRides(List<RideDocument> updates) async {
    if (updates.isEmpty) return;
    final existing = await loadRides();
    final byId = {for (final r in existing) r.id: r};
    for (final r in updates) {
      byId[r.id] = r;
    }
    await saveRides(byId.values.toList());
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/carpool_admin_rides_cache.json');
  }
}
