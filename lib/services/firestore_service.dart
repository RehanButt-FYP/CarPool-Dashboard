import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_document.dart';
import 'users_cache_repository.dart';

class AdminFirestoreService {
  AdminFirestoreService({UsersCacheRepository? cache})
      : _cache = cache ?? UsersCacheRepository();

  static final _db = FirebaseFirestore.instance;
  static final _users = _db.collection('users');

  final UsersCacheRepository _cache;
  Future<List<UserDocument>>? _syncInFlight;

  // ── Sync / cache ─────────────────────────────────────────────────────────

  /// Start of today in local time — data before this can stay in cache.
  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// When the watermark is before today, only fetch from start of today onward.
  static DateTime _incrementalSince(DateTime? watermark) {
    final startOfToday = _startOfToday();
    if (watermark == null) return startOfToday;
    if (watermark.isBefore(startOfToday)) return startOfToday;
    return watermark;
  }

  /// Loads users from cache, then fetches only new/changed docs from Firestore.
  Future<List<UserDocument>> syncUsers({bool forceFullRefresh = false}) {
    if (forceFullRefresh) {
      _syncInFlight = null;
    }
    return _syncInFlight ??= _doSync(forceFullRefresh: forceFullRefresh).whenComplete(
      () => _syncInFlight = null,
    );
  }

  Future<List<UserDocument>> _doSync({required bool forceFullRefresh}) async {
    if (forceFullRefresh) {
      await _cache.clearAll();
    }

    final watermark = await _cache.getSyncWatermark();
    final cached = await _cache.loadUsers();

    if (watermark == null || cached.isEmpty) {
      return _fullSync();
    }

    final since = _incrementalSince(watermark);
    final results = await Future.wait([
      _users
          .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get(),
      _users
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get(),
    ]);

    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        docsById[doc.id] = doc;
      }
    }

    if (docsById.isEmpty) {
      await _cache.setSyncWatermark(DateTime.now());
      return _sortedUsers(cached);
    }

    final updates =
        docsById.values.map(UserDocument.fromFirestore).toList();
    await _cache.mergeUsers(updates);
    await _cache.setSyncWatermark(DateTime.now());
    return _sortedUsers(await _cache.loadUsers());
  }

  Future<List<UserDocument>> _fullSync() async {
    final snap = await _users.get();
    final users = snap.docs.map(UserDocument.fromFirestore).toList();
    await _cache.saveUsers(users);
    await _cache.setSyncWatermark(DateTime.now());
    return _sortedUsers(users);
  }

  List<UserDocument> _sortedUsers(List<UserDocument> users) {
    final copy = List<UserDocument>.from(users);
    copy.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return copy;
  }

  Future<void> _refreshUserInCache(String userId) async {
    final doc = await _users.doc(userId).get();
    if (!doc.exists) return;
    await _cache.mergeUsers([UserDocument.fromFirestore(doc)]);
  }

  // ── Streams (cache-first, then incremental sync) ───────────────────────

  Stream<List<UserDocument>> allUsersStream({bool forceRefresh = false}) async* {
    final cached = await _cache.loadUsers();
    if (cached.isNotEmpty && !forceRefresh) {
      yield _sortedUsers(cached);
    }
    yield await syncUsers(forceFullRefresh: forceRefresh);
  }

  Stream<List<UserDocument>> pendingVerificationStream({
    bool forceRefresh = false,
  }) async* {
    await for (final users in allUsersStream(forceRefresh: forceRefresh)) {
      final pending = users
          .where(
            (u) =>
                u.verification?.verificationStatus == 'pending' &&
                u.hasSubmittedDocs,
          )
          .toList();
      pending.sort((a, b) {
        final aTime = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final bTime = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return bTime.compareTo(aTime);
      });
      yield pending;
    }
  }

  Stream<List<UserDocument>> approvedDriversStream({
    bool forceRefresh = false,
  }) async* {
    await for (final users in allUsersStream(forceRefresh: forceRefresh)) {
      yield users
          .where((u) => u.verification?.verificationStatus == 'approved')
          .toList();
    }
  }

  // ── Verification Actions ─────────────────────────────────────────────────

  Future<void> approveDriver(String userId) async {
    await _users.doc(userId).update({
      'verification.verificationStatus': 'verified',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _refreshUserInCache(userId);
  }

  Future<void> rejectDriver(String userId, {String? reason}) async {
    await _users.doc(userId).update({
      'verification.verificationStatus': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _refreshUserInCache(userId);
  }

  Future<void> resetVerification(String userId) async {
    await _users.doc(userId).update({
      'verification.verificationStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _refreshUserInCache(userId);
  }

  // ── Stats (derived from cache + incremental sync) ────────────────────────

  Future<DashboardStats?> getCachedDashboardStats() async {
    final users = await _cache.loadUsers();
    if (users.isEmpty) return null;
    return _statsFromUsers(users);
  }

  Future<DashboardStats> getDashboardStats({bool forceRefresh = false}) async {
    final users = await syncUsers(forceFullRefresh: forceRefresh);
    return _statsFromUsers(users);
  }

  DashboardStats _statsFromUsers(List<UserDocument> users) {
    final startOfDay = _startOfToday();

    var newToday = 0;
    var withCars = 0;
    var pending = 0;
    var approved = 0;

    for (final user in users) {
      final created = user.createdAt;
      if (created != null && !created.isBefore(startOfDay)) newToday++;

      final ver = user.verification;
      if (ver == null) continue;

      final vehicleFront = ver.vehicleDocFrontUrl?.trim() ?? '';
      if (vehicleFront.isNotEmpty) withCars++;

      final status = ver.verificationStatus;
      if (status == 'pending' && ver.isComplete) pending++;
      if (status == 'approved') approved++;
    }

    return DashboardStats(
      totalUsers: users.length,
      newUsersToday: newToday,
      usersWithCars: withCars,
      pendingVerifications: pending,
      approvedDrivers: approved,
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.totalUsers,
    required this.newUsersToday,
    required this.usersWithCars,
    required this.pendingVerifications,
    required this.approvedDrivers,
  });

  final int totalUsers;
  final int newUsersToday;
  final int usersWithCars;
  final int pendingVerifications;
  final int approvedDrivers;
}
