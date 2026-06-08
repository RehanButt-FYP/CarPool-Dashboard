import 'package:cloud_firestore/cloud_firestore.dart';

class CarDocument {
  const CarDocument({
    required this.id,
    required this.name,
    this.year,
    this.registrationNumber,
    this.seats = 4,
    this.ownerId,
    this.isFavourite = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int? year;
  final String? registrationNumber;
  final int seats;
  final String? ownerId;
  final bool isFavourite;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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

  factory CarDocument.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final map = doc.data() ?? {};
    return CarDocument(
      id: doc.id,
      name: map['name']?.toString() ?? '',
      year: _int(map['year'], 0) == 0 ? null : _int(map['year'], 0),
      registrationNumber: map['registrationNumber']?.toString(),
      seats: _int(map['seats'], 4).clamp(2, 10),
      ownerId: map['ownerId']?.toString(),
      isFavourite: map['isFavourite'] == true,
      createdAt: _ts(map['createdAt']),
      updatedAt: _ts(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'seats': seats.clamp(2, 10),
      'isFavourite': isFavourite,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (year != null) map['year'] = year;
    if (registrationNumber != null && registrationNumber!.trim().isNotEmpty) {
      map['registrationNumber'] = registrationNumber!.trim();
    }
    if (ownerId != null && ownerId!.isNotEmpty) {
      map['ownerId'] = ownerId;
    }
    return map;
  }
}

class SavedRideReference {
  const SavedRideReference({required this.rideId, this.savedAt});

  final String rideId;
  final DateTime? savedAt;

  static DateTime? _ts(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  factory SavedRideReference.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SavedRideReference(
      rideId: doc.id,
      savedAt: _ts(data['savedAt']) ?? _ts(data['createdAt']),
    );
  }
}
