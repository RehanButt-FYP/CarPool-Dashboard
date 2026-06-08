import 'package:cloud_firestore/cloud_firestore.dart';

class UserVerification {
  const UserVerification({
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.licenseFrontUrl,
    this.licenseBackUrl,
    this.vehicleDocFrontUrl,
    this.vehicleDocBackUrl,
    this.verificationStatus,
  });

  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? licenseFrontUrl;
  final String? licenseBackUrl;
  final String? vehicleDocFrontUrl;
  final String? vehicleDocBackUrl;
  final String? verificationStatus;

  bool get isComplete =>
      _hasUrl(cnicFrontUrl) &&
      _hasUrl(cnicBackUrl) &&
      _hasUrl(licenseFrontUrl) &&
      _hasUrl(licenseBackUrl) &&
      _hasUrl(vehicleDocFrontUrl) &&
      _hasUrl(vehicleDocBackUrl);

  bool get isPending => verificationStatus == 'pending';
  bool get isApproved {
    final s = verificationStatus?.toLowerCase();
    return s == 'approved' || s == 'verified';
  }

  bool get isRejected => verificationStatus == 'rejected';

  static bool _hasUrl(String? v) => v != null && v.trim().isNotEmpty;

  factory UserVerification.fromMap(Map<String, dynamic> map) {
    return UserVerification(
      cnicFrontUrl: map['cnicFrontUrl']?.toString(),
      cnicBackUrl: map['cnicBackUrl']?.toString(),
      licenseFrontUrl: map['licenseFrontUrl']?.toString(),
      licenseBackUrl: map['licenseBackUrl']?.toString(),
      vehicleDocFrontUrl: map['vehicleDocFrontUrl']?.toString(),
      vehicleDocBackUrl: map['vehicleDocBackUrl']?.toString(),
      verificationStatus: map['verificationStatus']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'cnicFrontUrl': cnicFrontUrl ?? '',
        'cnicBackUrl': cnicBackUrl ?? '',
        'licenseFrontUrl': licenseFrontUrl ?? '',
        'licenseBackUrl': licenseBackUrl ?? '',
        'vehicleDocFrontUrl': vehicleDocFrontUrl ?? '',
        'vehicleDocBackUrl': vehicleDocBackUrl ?? '',
        'verificationStatus': verificationStatus,
      };
}

class UserDocument {
  const UserDocument({
    this.id,
    required this.fullName,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.gender,
    this.photoURL,
    this.createdAt,
    this.updatedAt,
    this.lastSeen,
    this.carIds = const [],
    this.isEnabled = true,
    this.verification,
  });

  final String? id;
  final String fullName;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? gender;
  final String? photoURL;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeen;
  final List<String> carIds;
  /// When false, admin has disabled this account (`isEnabled` on Firestore user doc).
  final bool isEnabled;
  final UserVerification? verification;

  bool get hasPhoto => photoURL != null && photoURL!.trim().isNotEmpty;

  bool get hasSubmittedDocs => verification?.isComplete == true;

  /// Admin approved this user as a driver (`approved` or `verified` on verification).
  bool get isDriverApproved {
    final s = verification?.verificationStatus?.toLowerCase();
    return s == 'approved' || s == 'verified';
  }

  /// Uploaded vehicle registration doc (original admin “drivers” metric).
  bool get hasVehicleVerificationDoc {
    final vehicleFront = verification?.vehicleDocFrontUrl?.trim() ?? '';
    return vehicleFront.isNotEmpty;
  }

  bool get hasRegisteredCar => carIds.isNotEmpty;

  /// Has a car in the app and/or vehicle verification doc.
  bool get isRegisteredDriver =>
      hasVehicleVerificationDoc || hasRegisteredCar;

  /// Show “Driver” tag in lists.
  bool get isDriver => isRegisteredDriver || isDriverApproved;

  /// Submitted all docs and still waiting for admin (not approved/rejected).
  bool get isPendingAdminReview {
    if (!hasSubmittedDocs) return false;
    if (isDriverApproved) return false;
    final s = verification?.verificationStatus?.toLowerCase();
    return s != 'rejected';
  }

  /// Admin approved after document review.
  bool get isAdminApprovedDriver =>
      isDriverApproved && hasSubmittedDocs;

  /// Opened the app within [window] (uses Firestore `lastSeen`).
  bool wasActiveWithin(Duration window) {
    final seen = lastSeen;
    if (seen == null) return false;
    return DateTime.now().difference(seen) <= window;
  }

  String get displayName {
    final t = fullName.trim();
    if (t.isNotEmpty) return t;
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isNotEmpty || ln.isNotEmpty) return '$fn $ln'.trim();
    return 'Unknown User';
  }

  String get verificationStatusLabel {
    final s = verification?.verificationStatus?.toLowerCase();
    if (s == 'approved' || s == 'verified') return 'Approved';
    if (s == 'rejected') return 'Rejected';
    if (verification?.isComplete == true) return 'Pending Review';
    return 'Not Submitted';
  }

  static DateTime? _timestamp(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  factory UserDocument.fromMap(Map<String, dynamic> map, {String? id}) {
    UserVerification? verification;
    final verMap = map['verification'];
    if (verMap is Map<String, dynamic>) {
      verification = UserVerification.fromMap(verMap);
    }

    final carIdsRaw = map['carIds'];
    final carIds = carIdsRaw is List
        ? carIdsRaw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return UserDocument(
      id: id,
      fullName: map['fullName']?.toString() ?? '',
      firstName: map['firstName']?.toString(),
      lastName: map['lastName']?.toString(),
      phoneNumber: map['phoneNumber']?.toString(),
      gender: map['gender']?.toString(),
      photoURL: map['photoURL']?.toString(),
      createdAt: _timestamp(map['createdAt']),
      updatedAt: _timestamp(map['updatedAt']),
      lastSeen: _timestamp(map['lastSeen']),
      carIds: carIds,
      isEnabled: map['isEnabled'] != false,
      verification: verification,
    );
  }

  factory UserDocument.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserDocument.fromMap(doc.data() ?? {}, id: doc.id);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fullName': fullName,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'gender': gender,
        'photoURL': photoURL,
        'createdAt': createdAt?.millisecondsSinceEpoch,
        'updatedAt': updatedAt?.millisecondsSinceEpoch,
        'lastSeen': lastSeen?.millisecondsSinceEpoch,
        'carIds': carIds,
        'isEnabled': isEnabled,
        if (verification != null) 'verification': verification!.toMap(),
      };

  UserDocument copyWith({
    UserVerification? verification,
    DateTime? updatedAt,
    DateTime? lastSeen,
    List<String>? carIds,
    bool? isEnabled,
    String? fullName,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? gender,
    String? photoURL,
  }) {
    return UserDocument(
      id: id,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeen: lastSeen ?? this.lastSeen,
      carIds: carIds ?? this.carIds,
      isEnabled: isEnabled ?? this.isEnabled,
      verification: verification ?? this.verification,
    );
  }
}
