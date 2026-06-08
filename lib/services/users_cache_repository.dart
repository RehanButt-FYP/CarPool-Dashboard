import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_document.dart';

/// Persists user documents locally and tracks the last Firestore sync time.
class UsersCacheRepository {
  static const _watermarkKey = 'users_sync_watermark_ms';

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

  Future<void> clearSyncWatermark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_watermarkKey);
  }

  Future<List<UserDocument>> loadUsers() async {
    final file = await _cacheFile();
    if (!await file.exists()) return [];
    try {
      final raw = await file.readAsString();
      if (raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => UserDocument.fromMap(
                Map<String, dynamic>.from(e as Map),
                id: (e['id'] as String?)?.trim().isNotEmpty == true
                    ? e['id'] as String
                    : null,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveUsers(List<UserDocument> users) async {
    final file = await _cacheFile();
    final encoded = jsonEncode(users.map((u) => u.toMap()).toList());
    await file.writeAsString(encoded);
  }

  Future<void> mergeUsers(List<UserDocument> updates) async {
    if (updates.isEmpty) return;
    final existing = await loadUsers();
    final byId = <String, UserDocument>{
      for (final u in existing)
        if (u.id != null) u.id!: u,
    };
    for (final u in updates) {
      if (u.id != null) byId[u.id!] = u;
    }
    await saveUsers(byId.values.toList());
  }

  Future<void> clearUsers() async {
    final file = await _cacheFile();
    if (await file.exists()) await file.delete();
  }

  Future<void> clearAll() async {
    await clearUsers();
    await clearSyncWatermark();
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/carpool_admin_users_cache.json');
  }
}
