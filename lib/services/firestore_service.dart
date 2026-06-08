import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/car_document.dart';
import '../models/ride_document.dart';
import '../models/user_document.dart';
import 'users_cache_repository.dart';

class AdminFirestoreService {
  AdminFirestoreService({UsersCacheRepository? cache})
      : _cache = cache ?? UsersCacheRepository();

  static final _db = FirebaseFirestore.instance;
  static final _users = _db.collection('users');
  static final _cars = _db.collection('cars');
  static final _rides = _db.collection('rides');

  final UsersCacheRepository _cache;
  Future<List<UserDocument>>? _syncInFlight;

  // ── Sync / cache ─────────────────────────────────────────────────────────

  static const _fullSyncInterval = Duration(hours: 24);

  /// Start of today in local time.
  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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
      return _fullSync();
    }

    final watermark = await _cache.getSyncWatermark();
    final cached = await _cache.loadUsers();
    final lastFullSync = await _cache.getLastFullSync();

    final cacheStale = lastFullSync == null ||
        DateTime.now().difference(lastFullSync) > _fullSyncInterval;

    if (watermark == null || cached.isEmpty || cacheStale) {
      return _fullSync();
    }

    if (!await _cacheMatchesServerCount(cached.length)) {
      return _fullSync();
    }

    final since = watermark;
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

    final merged = await _cache.loadUsers();
    if (!await _cacheMatchesServerCount(merged.length)) {
      return _fullSync();
    }
    return _sortedUsers(merged);
  }

  /// True when local cache holds every user doc in Firestore.
  Future<bool> _cacheMatchesServerCount(int cachedCount) async {
    try {
      final agg = await _users.count().get();
      final serverCount = agg.count;
      if (serverCount == null) return true;
      return cachedCount >= serverCount;
    } on FirebaseException {
      return true;
    }
  }

  Future<List<UserDocument>> _fullSync() async {
    final snap = await _users.get();
    final users = snap.docs.map(UserDocument.fromFirestore).toList();
    final now = DateTime.now();
    await _cache.saveUsers(users);
    await _cache.setSyncWatermark(now);
    await _cache.setLastFullSync(now);
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
      final pending = users.where((u) => u.isPendingAdminReview).toList();
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
      yield users.where((u) => u.isAdminApprovedDriver).toList();
    }
  }

  // ── Verification Actions ─────────────────────────────────────────────────

  Future<void> approveDriver(String userId) async {
    await _users.doc(userId).update({
      'verification.verificationStatus': 'verified',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _verifyActiveRidesForDriver(userId);
    await _refreshUserInCache(userId);
  }

  /// Marks upcoming/in-progress rides for [driverId] as Verified on Explore.
  Future<void> _verifyActiveRidesForDriver(String driverId) async {
    final now = DateTime.now();
    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    try {
      final snap = await _rides
          .where('driverId', isEqualTo: driverId)
          .where('endTimestamp', isGreaterThan: Timestamp.fromDate(now))
          .get();
      for (final doc in snap.docs) {
        byId[doc.id] = doc;
      }
    } on FirebaseException {
      final snap = await _rides.where('driverId', isEqualTo: driverId).get();
      for (final doc in snap.docs) {
        byId[doc.id] = doc;
      }
    }

    for (final doc in byId.values) {
      final ride = RideDocument.fromFirestore(doc);
      if (ride.isCanceled) continue;
      if (ride.endTimestamp != null && !ride.endTimestamp!.isAfter(now)) {
        continue;
      }
      if (ride.isRideVerified) continue;
      await _rides.doc(doc.id).update({
        'driverVerificationStatus': RideDriverVerificationStatus.verified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
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

  // ── User admin ───────────────────────────────────────────────────────────

  Future<UserDocument?> getUser(String userId) async {
    final doc = await _users.doc(userId).get();
    if (!doc.exists) return null;
    final user = UserDocument.fromFirestore(doc);
    await _cache.mergeUsers([user]);
    return user;
  }

  Future<void> setUserEnabled(String userId, {required bool enabled}) async {
    await _users.doc(userId).update({
      'isEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _refreshUserInCache(userId);
  }

  Future<void> updateUserProfile(
    String userId, {
    String? fullName,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? gender,
    String? photoURL,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fullName != null) data['fullName'] = fullName.trim();
    if (firstName != null) data['firstName'] = firstName.trim();
    if (lastName != null) data['lastName'] = lastName.trim();
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber.trim();
    if (gender != null) data['gender'] = gender.trim();
    if (photoURL != null) data['photoURL'] = photoURL.trim();
    await _users.doc(userId).update(data);
    await _refreshUserInCache(userId);
  }

  Future<List<CarDocument>> getUserCars(String userId) async {
    final snap = await _cars.where('ownerId', isEqualTo: userId).get();
    final cars = snap.docs.map(CarDocument.fromFirestore).toList();
    cars.sort((a, b) => a.name.compareTo(b.name));
    return cars;
  }

  Future<CarDocument?> getCar(String carId) async {
    final doc = await _cars.doc(carId).get();
    if (!doc.exists) return null;
    return CarDocument.fromFirestore(doc);
  }

  Future<void> updateCar(String carId, CarDocument car) async {
    await _cars.doc(carId).update(car.toFirestoreMap());
  }

  Future<List<SavedRideReference>> getUserSavedRides(String userId) async {
    final snap = await _users.doc(userId).collection('saved_rides').get();
    final refs = snap.docs.map(SavedRideReference.fromFirestore).toList();
    refs.sort((a, b) {
      final aTime = a.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.savedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return refs;
  }

  Future<List<RideDocument>> getUserPostedRides(String userId) async {
    final snap = await _rides.where('driverId', isEqualTo: userId).get();
    final rides = snap.docs.map(RideDocument.fromFirestore).toList();
    rides.sort((a, b) {
      final aStart = a.startTimestamp ?? a.createdAt ?? DateTime(0);
      final bStart = b.startTimestamp ?? b.createdAt ?? DateTime(0);
      return bStart.compareTo(aStart);
    });
    return rides;
  }

  // ── Stats (derived from cache + incremental sync) ────────────────────────

  static const _activeWindow = Duration(hours: 24);

  /// Users who opened the app within the last 24 hours (Firestore `lastSeen`).
  Future<({int activeUsers, int activeDrivers})> fetchActiveUserStats() async {
    final since = DateTime.now().subtract(_activeWindow);
    try {
      final snap = await _users
          .where(
            'lastSeen',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since),
          )
          .get();
      var activeDrivers = 0;
      for (final doc in snap.docs) {
        if (UserDocument.fromFirestore(doc).hasVehicleVerificationDoc) {
          activeDrivers++;
        }
      }
      return (activeUsers: snap.docs.length, activeDrivers: activeDrivers);
    } on FirebaseException {
      // Fall back to cached users when index/query fails.
      final users = await _cache.loadUsers();
      var activeUsers = 0;
      var activeDrivers = 0;
      for (final user in users) {
        if (!user.wasActiveWithin(_activeWindow)) continue;
        activeUsers++;
        if (user.hasVehicleVerificationDoc) activeDrivers++;
      }
      return (activeUsers: activeUsers, activeDrivers: activeDrivers);
    }
  }

  Future<DashboardStats> getDashboardStats() async {
    final users = await syncUsers(forceFullRefresh: true);
    final userStats = _statsFromUsers(users);
    final active = await fetchActiveUserStats();
    return userStats.copyWith(
      activeUsers24h: active.activeUsers,
      activeDrivers24h: active.activeDrivers,
    );
  }

  DashboardStats _statsFromUsers(List<UserDocument> users) {
    final startOfDay = _startOfToday();

    var newToday = 0;
    var newDriversToday = 0;
    var driversWithVehicleDocs = 0;
    var registeredDrivers = 0;
    var pending = 0;
    var approved = 0;

    for (final user in users) {
      if (user.hasVehicleVerificationDoc) driversWithVehicleDocs++;
      if (user.isRegisteredDriver) registeredDrivers++;

      final created = user.createdAt;
      if (created != null && !created.isBefore(startOfDay)) {
        newToday++;
        if (user.hasVehicleVerificationDoc) newDriversToday++;
      }

      if (user.isPendingAdminReview) pending++;
      if (user.isAdminApprovedDriver) approved++;
    }

    return DashboardStats(
      totalUsers: users.length,
      newUsersToday: newToday,
      newDriversToday: newDriversToday,
      driversWithVehicleDocs: driversWithVehicleDocs,
      registeredDrivers: registeredDrivers,
      pendingVerifications: pending,
      approvedDrivers: approved,
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.totalUsers,
    required this.newUsersToday,
    this.newDriversToday = 0,
    this.activeUsers24h = 0,
    this.activeDrivers24h = 0,
    this.driversWithVehicleDocs = 0,
    this.registeredDrivers = 0,
    this.activeRidesNow = 0,
    required this.pendingVerifications,
    required this.approvedDrivers,
  });

  final int totalUsers;
  final int newUsersToday;
  final int newDriversToday;
  final int activeUsers24h;
  final int activeDrivers24h;
  /// Drivers who uploaded a vehicle verification doc (legacy admin metric).
  final int driversWithVehicleDocs;
  /// Users with a car and/or vehicle doc — broader than [driversWithVehicleDocs].
  final int registeredDrivers;
  final int activeRidesNow;
  final int pendingVerifications;
  final int approvedDrivers;

  DashboardStats copyWith({
    int? totalUsers,
    int? newUsersToday,
    int? newDriversToday,
    int? activeUsers24h,
    int? activeDrivers24h,
    int? driversWithVehicleDocs,
    int? registeredDrivers,
    int? activeRidesNow,
    int? pendingVerifications,
    int? approvedDrivers,
  }) {
    return DashboardStats(
      totalUsers: totalUsers ?? this.totalUsers,
      newUsersToday: newUsersToday ?? this.newUsersToday,
      newDriversToday: newDriversToday ?? this.newDriversToday,
      activeUsers24h: activeUsers24h ?? this.activeUsers24h,
      activeDrivers24h: activeDrivers24h ?? this.activeDrivers24h,
      driversWithVehicleDocs:
          driversWithVehicleDocs ?? this.driversWithVehicleDocs,
      registeredDrivers: registeredDrivers ?? this.registeredDrivers,
      activeRidesNow: activeRidesNow ?? this.activeRidesNow,
      pendingVerifications: pendingVerifications ?? this.pendingVerifications,
      approvedDrivers: approvedDrivers ?? this.approvedDrivers,
    );
  }
}
