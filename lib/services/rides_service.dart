import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ride_document.dart';
import '../models/user_document.dart';
import '../utils/ride_firestore_utils.dart';
import 'firestore_service.dart';
import 'rides_cache_repository.dart';

enum RidesListFilter {
  /// Rides from drivers who are not admin-approved (default).
  unverifiedDrivers,
  /// Rides with `driverVerificationStatus: Pending` (Firestore query).
  unverifiedRides,
  /// All upcoming / in-progress rides.
  all,
}

class AdminRidesService {
  AdminRidesService({
    RidesCacheRepository? cache,
    AdminFirestoreService? usersService,
  })  : _cache = cache ?? RidesCacheRepository(),
        _usersService = usersService ?? AdminFirestoreService();

  static final _rides = FirebaseFirestore.instance.collection('rides');

  final RidesCacheRepository _cache;
  final AdminFirestoreService _usersService;
  Future<List<RideDocument>>? _syncInFlight;

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime _incrementalSince(DateTime? watermark) {
    final startOfToday = _startOfToday();
    if (watermark == null) return startOfToday;
    if (watermark.isBefore(startOfToday)) return startOfToday;
    return watermark;
  }

  static List<RideDocument> _onlyUpcomingOrInProgress(List<RideDocument> rides) {
    return rides.where((r) => r.isUpcomingOrInProgress).toList();
  }

  static Timestamp get _now => Timestamp.now();

  Future<List<RideDocument>> syncRides({bool forceFullRefresh = false}) {
    if (forceFullRefresh) _syncInFlight = null;
    return _syncInFlight ??=
        _doSync(forceFullRefresh: forceFullRefresh).whenComplete(
      () => _syncInFlight = null,
    );
  }

  Future<List<RideDocument>> _doSync({required bool forceFullRefresh}) async {
    if (forceFullRefresh) await _cache.clearAll();

    final watermark = await _cache.getSyncWatermark();
    final cached = await _cache.loadRides();

    if (watermark == null || cached.isEmpty) {
      return _fetchActiveRides();
    }

    final activeCached = _onlyUpcomingOrInProgress(cached);
    if (activeCached.length != cached.length) {
      await _cache.saveRides(activeCached);
    }

    final since = _incrementalSince(watermark);
    final snap = await _rides
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    if (snap.docs.isEmpty) {
      await _cache.setSyncWatermark(DateTime.now());
      final pruned = _onlyUpcomingOrInProgress(await _cache.loadRides());
      await _cache.saveRides(pruned);
      return _sortedRides(pruned);
    }

    final updates = snap.docs.map(RideDocument.fromFirestore).toList();
    await _cache.mergeRides(updates);
    await _cache.setSyncWatermark(DateTime.now());
    final active = _onlyUpcomingOrInProgress(await _cache.loadRides());
    await _cache.saveRides(active);
    return _sortedRides(active);
  }

  /// Upcoming / in-progress rides (carpool Explore rule).
  Future<List<RideDocument>> _fetchActiveRides() async {
    final snap = await _rides
        .where('endTimestamp', isGreaterThan: _now)
        .orderBy('endTimestamp')
        .get();
    final rides =
        _onlyUpcomingOrInProgress(snap.docs.map(RideDocument.fromFirestore).toList());
    await _cache.saveRides(rides);
    await _cache.setSyncWatermark(DateTime.now());
    return _sortedRides(rides);
  }

  /// Active rides with `driverVerificationStatus` Pending.
  Future<List<RideDocument>> _fetchUnverifiedActiveRides() async {
    final byId = <String, RideDocument>{};

    try {
      final snap = await _rides
          .where(
            'driverVerificationStatus',
            isEqualTo: RideDriverVerificationStatus.pending,
          )
          .where('endTimestamp', isGreaterThan: _now)
          .orderBy('endTimestamp')
          .get();
      for (final doc in snap.docs) {
        byId[doc.id] = RideDocument.fromFirestore(doc);
      }
    } on FirebaseException {
      // Composite index may be missing; continue with client-side pass below.
    }

    final active = await _fetchActiveRides();
    for (final r in active) {
      if (!r.isRideVerified) byId[r.id] = r;
    }

    return _sortedRides(byId.values.toList());
  }

  List<RideDocument> _sortedRides(List<RideDocument> rides) {
    final copy = List<RideDocument>.from(rides);
    copy.sort((a, b) {
      final aStart = a.startTimestamp ?? a.createdAt ?? DateTime(0);
      final bStart = b.startTimestamp ?? b.createdAt ?? DateTime(0);
      final byStart = aStart.compareTo(bStart);
      if (byStart != 0) return byStart;
      final aCreated = a.createdAt ?? DateTime(0);
      final bCreated = b.createdAt ?? DateTime(0);
      return aCreated.compareTo(bCreated);
    });
    return copy;
  }

  Future<Map<String, UserDocument>> _driversById() async {
    final users = await _usersService.syncUsers();
    return {
      for (final u in users)
        if (u.id != null) u.id!: u,
    };
  }

  Future<List<RideWithDriver>> loadRides({
    RidesListFilter filter = RidesListFilter.unverifiedDrivers,
    bool forceRefresh = false,
  }) async {
    final drivers = await _driversById();

    final List<RideDocument> rides;
    switch (filter) {
      case RidesListFilter.unverifiedRides:
        rides = await _fetchUnverifiedActiveRides();
        break;
      case RidesListFilter.unverifiedDrivers:
      case RidesListFilter.all:
        rides = await syncRides(forceFullRefresh: forceRefresh);
        break;
    }

    final enriched = rides
        .map(
          (r) => RideWithDriver(
            ride: r,
            driver: r.driverId != null ? drivers[r.driverId] : null,
          ),
        )
        .toList();

    return _applyFilter(enriched, filter);
  }

  List<RideWithDriver> _applyFilter(
    List<RideWithDriver> items,
    RidesListFilter filter,
  ) {
    switch (filter) {
      case RidesListFilter.unverifiedDrivers:
        return items.where((e) => !e.driverIsVerified).toList();
      case RidesListFilter.unverifiedRides:
        return items;
      case RidesListFilter.all:
        return items;
    }
  }

  Future<RideWithDriver?> getRide(String rideId) async {
    final drivers = await _driversById();
    final doc = await _rides.doc(rideId).get();
    if (!doc.exists) return null;
    final ride = RideDocument.fromFirestore(doc);
    await _cache.mergeRides([ride]);
    return RideWithDriver(
      ride: ride,
      driver: ride.driverId != null ? drivers[ride.driverId] : null,
    );
  }

  Future<void> updateRide(String rideId, Map<String, dynamic> data) async {
    await _rides.doc(rideId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final doc = await _rides.doc(rideId).get();
    if (doc.exists) {
      await _cache.mergeRides([RideDocument.fromFirestore(doc)]);
    }
  }

  Future<void> saveRideEdits({
    required String rideId,
    required String from,
    required String to,
    required String otherStopsText,
    required String driverName,
    required String carName,
    String? carId,
    int? carYear,
    required DateTime rideDate,
    required String startTimeWall,
    required String endTimeWall,
    required String rideFare,
    required int totalSeats,
    required int availableSeats,
    String? notes,
    String? whatsappPhone,
    String? rideStatus,
    required bool isEnable,
    bool? isActive,
    required String driverVerificationStatus,
  }) async {
    final timestamps = RideFirestoreUtils.timestampsForDate(
      rideDate,
      startTimeWall,
      endTimeWall,
    );

    final data = <String, dynamic>{
      'from': from.trim(),
      'to': to.trim(),
      'otherStops': RideFirestoreUtils.parseOtherStops(otherStopsText),
      'driverName': driverName.trim(),
      'carName': carName.trim(),
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'startTime': startTimeWall,
      'endTime': endTimeWall,
      'startTimestamp': timestamps.start,
      'endTimestamp': timestamps.end,
      'rideFare': rideFare.trim(),
      'notes': notes?.trim() ?? '',
      'whatsappPhone': whatsappPhone?.trim() ?? '',
      'isEnable': isEnable,
      'driverVerificationStatus': driverVerificationStatus,
    };

    if (carId != null && carId.trim().isNotEmpty) {
      data['carId'] = carId.trim();
    }
    if (carYear != null) {
      data['carYear'] = carYear;
    }
    if (isActive != null) {
      data['isActive'] = isActive;
    }

    if (rideStatus == null || rideStatus.isEmpty) {
      data['rideStatus'] = FieldValue.delete();
    } else {
      data['rideStatus'] = rideStatus;
    }

    await updateRide(rideId, data);
  }

  /// Rides currently listed on Explore (upcoming, verified, not canceled).
  Future<int> countActiveRidesNow({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await syncRides(forceFullRefresh: true);
    }

    // Query Firestore directly so the count is not stale vs the local ride cache.
    final snap = await _rides
        .where('endTimestamp', isGreaterThan: _now)
        .get();

    return snap.docs
        .map(RideDocument.fromFirestore)
        .where((r) => r.isListedOnExplore)
        .length;
  }

  /// Quick WhatsApp-sourced ride defaults.
  static const defaultDriverName = 'Carpool user';
  static const defaultCarName = 'Carpool';

  /// Creates a ride (defaults suit WhatsApp admin entry).
  Future<String> createRide({
    required String from,
    required String to,
    required DateTime rideDate,
    required String startTimeWall,
    required String endTimeWall,
    String otherStopsText = '',
    String driverName = '',
    String? driverId,
    String? driverPhotoURL,
    String carName = '',
    String? carId,
    int? carYear,
    String rideFare = '',
    int totalSeats = 4,
    int? availableSeats,
    String? notes,
    String? whatsappPhone,
    bool isEnable = true,
    bool? isActive,
    String driverVerificationStatus = RideDriverVerificationStatus.pending,
  }) async {
    final timestamps = RideFirestoreUtils.timestampsForDate(
      rideDate,
      startTimeWall,
      endTimeWall,
    );

    final seats = totalSeats.clamp(1, 20);
    final available = (availableSeats ?? seats).clamp(0, seats);

    final data = <String, dynamic>{
      'from': from.trim(),
      'to': to.trim(),
      'otherStops': RideFirestoreUtils.parseOtherStops(otherStopsText),
      'driverName': driverName.trim().isEmpty ? defaultDriverName : driverName.trim(),
      'carName': carName.trim().isEmpty ? defaultCarName : carName.trim(),
      'totalSeats': seats,
      'availableSeats': available,
      'startTime': startTimeWall,
      'endTime': endTimeWall,
      'startTimestamp': timestamps.start,
      'endTimestamp': timestamps.end,
      'rideFare': rideFare.trim(),
      'notes': notes?.trim() ?? '',
      'whatsappPhone': whatsappPhone?.trim() ?? '',
      'isEnable': isEnable,
      'driverVerificationStatus': driverVerificationStatus,
      'requests': <dynamic>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (driverId != null && driverId.trim().isNotEmpty) {
      data['driverId'] = driverId.trim();
    }
    if (driverPhotoURL != null && driverPhotoURL.trim().isNotEmpty) {
      data['driverPhotoURL'] = driverPhotoURL.trim();
    }
    if (carId != null && carId.trim().isNotEmpty) {
      data['carId'] = carId.trim();
    }
    if (carYear != null) {
      data['carYear'] = carYear;
    }
    if (isActive != null) {
      data['isActive'] = isActive;
    }

    final ref = await _rides.add(data);
    final doc = await ref.get();
    if (doc.exists) {
      await _cache.mergeRides([RideDocument.fromFirestore(doc)]);
    }
    return ref.id;
  }
}
