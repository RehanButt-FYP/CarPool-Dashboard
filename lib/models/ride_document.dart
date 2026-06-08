import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/ride_firestore_utils.dart';
import 'user_document.dart';

/// Firestore `driverVerificationStatus` on ride documents.
abstract final class RideDriverVerificationStatus {
  static const pending = 'Pending';
  static const verified = 'Verified';

  static bool isVerified(String? value) =>
      value?.trim().toLowerCase() == verified.toLowerCase();

  static String fromFirestore(Map<String, dynamic> map) {
    final raw = map['driverVerificationStatus']?.toString().trim();
    if (raw != null && raw.isNotEmpty) {
      return isVerified(raw) ? verified : pending;
    }
    // Legacy boolean `isVerified` before this field existed.
    if (map['isVerified'] == true) return verified;
    return pending;
  }
}

/// Admin view of a ride in Firestore `rides/{rideId}`.
class RideDocument {
  const RideDocument({
    required this.id,
    this.driverId,
    this.driverName = '',
    this.driverPhotoURL,
    this.fromLocation = '',
    this.toLocation = '',
    this.otherStops = const [],
    this.carName = '',
    this.carId,
    this.carYear,
    this.totalSeats = 4,
    this.availableSeats = 4,
    this.rideFare = '',
    this.driverNotes,
    this.whatsappPhone,
    this.startTimeWall = '00:00',
    this.endTimeWall = '00:00',
    this.startTimestamp,
    this.endTimestamp,
    this.createdAt,
    this.updatedAt,
    this.rideStatus,
    this.isEnable = true,
    this.isActive,
  /// `Pending` or `Verified` — independent of the user account verification.
    this.driverVerificationStatus = RideDriverVerificationStatus.pending,
    this.requestCount = 0,
  });

  final String id;
  final String? driverId;
  final String driverName;
  final String? driverPhotoURL;
  final String fromLocation;
  final String toLocation;
  final List<String> otherStops;
  final String carName;
  final String? carId;
  final int? carYear;
  final int totalSeats;
  final int availableSeats;
  final String rideFare;
  final String? driverNotes;
  final String? whatsappPhone;
  /// Wall-clock times stored as `HH:mm` on the ride doc.
  final String startTimeWall;
  final String endTimeWall;
  final DateTime? startTimestamp;
  final DateTime? endTimestamp;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? rideStatus;
  final bool isEnable;
  final bool? isActive;
  final String driverVerificationStatus;
  final int requestCount;

  bool get isRideVerified =>
      RideDriverVerificationStatus.isVerified(driverVerificationStatus);

  bool get isCanceled {
    final s = (rideStatus ?? '').toLowerCase();
    return s == 'canceled' || s == 'cancelled';
  }

  bool get isUpcomingOrInProgress {
    final end = endTimestamp;
    if (end == null) return true;
    return end.isAfter(DateTime.now());
  }

  DateTime? get rideDate {
    final s = startTimestamp;
    if (s == null) return null;
    return DateTime(s.year, s.month, s.day);
  }

  String get routeLabel {
    if (otherStops.isEmpty) return '$fromLocation → $toLocation';
    return '$fromLocation → ${otherStops.join(' → ')} → $toLocation';
  }

  String get otherStopsText => otherStops.join(', ');

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static int _int(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  factory RideDocument.fromMap(Map<String, dynamic> map, {required String id}) {
    final otherStopsRaw = map['otherStops'];
    final otherStops = otherStopsRaw is List
        ? otherStopsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final requestsRaw = map['requests'];
    final requestCount =
        requestsRaw is List ? requestsRaw.whereType<Map>().length : 0;

    final notesRaw = map['notes']?.toString().trim();
    final driverNotes =
        (notesRaw == null || notesRaw.isEmpty) ? null : notesRaw;

    int? carYear;
    final cy = map['carYear'];
    if (cy is int) {
      carYear = cy;
    } else if (cy is num) {
      carYear = cy.toInt();
    } else {
      carYear = int.tryParse(cy?.toString() ?? '');
    }

    final rideStatusRaw = map['rideStatus']?.toString().trim();
    final rideStatus =
        (rideStatusRaw == null || rideStatusRaw.isEmpty) ? null : rideStatusRaw;

    final startTs = _ts(map['startTimestamp']);
    final endTs = _ts(map['endTimestamp']);

    return RideDocument(
      id: id,
      driverId: map['driverId']?.toString(),
      driverName: map['driverName']?.toString() ?? '',
      driverPhotoURL: map['driverPhotoURL']?.toString(),
      fromLocation: map['from']?.toString() ?? '',
      toLocation: map['to']?.toString() ?? '',
      otherStops: otherStops,
      carName: map['carName']?.toString() ?? '',
      carId: map['carId']?.toString(),
      carYear: carYear,
      totalSeats: _int(map['totalSeats'], 4),
      availableSeats: _int(map['availableSeats'], 4),
      rideFare: map['rideFare']?.toString() ?? '',
      driverNotes: driverNotes,
      whatsappPhone: map['whatsappPhone']?.toString(),
      startTimeWall: RideFirestoreUtils.timeStrFromJson(
        map['startTime'],
        map['startTimestamp'],
      ),
      endTimeWall: RideFirestoreUtils.timeStrFromJson(
        map['endTime'],
        map['endTimestamp'],
      ),
      startTimestamp: startTs,
      endTimestamp: endTs,
      createdAt: _ts(map['createdAt']),
      updatedAt: _ts(map['updatedAt']),
      rideStatus: rideStatus,
      isEnable: map['isEnable'] != false,
      isActive: map['isActive'] is bool ? map['isActive'] as bool : null,
      driverVerificationStatus:
          RideDriverVerificationStatus.fromFirestore(map),
      requestCount: requestCount,
    );
  }

  factory RideDocument.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return RideDocument.fromMap(doc.data() ?? {}, id: doc.id);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'driverId': driverId,
        'driverName': driverName,
        'driverPhotoURL': driverPhotoURL,
        'from': fromLocation,
        'to': toLocation,
        'otherStops': otherStops,
        'carName': carName,
        'carId': carId,
        'carYear': carYear,
        'totalSeats': totalSeats,
        'availableSeats': availableSeats,
        'rideFare': rideFare,
        'notes': driverNotes,
        'whatsappPhone': whatsappPhone,
        'startTime': startTimeWall,
        'endTime': endTimeWall,
        'startTimestamp': startTimestamp?.millisecondsSinceEpoch,
        'endTimestamp': endTimestamp?.millisecondsSinceEpoch,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'rideStatus': rideStatus,
        'isEnable': isEnable,
        'isActive': isActive,
        'driverVerificationStatus': driverVerificationStatus,
        'requestCount': requestCount,
      };
}

class RideWithDriver {
  const RideWithDriver({required this.ride, this.driver});

  final RideDocument ride;
  final UserDocument? driver;

  bool get driverIsVerified => driver?.isDriverApproved ?? false;
}
