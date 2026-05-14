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
  bool get isApproved => verificationStatus == 'approved';
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
  final UserVerification? verification;

  bool get hasPhoto => photoURL != null && photoURL!.trim().isNotEmpty;

  bool get hasSubmittedDocs => verification?.isComplete == true;

  String get displayName {
    final t = fullName.trim();
    if (t.isNotEmpty) return t;
    final fn = firstName?.trim() ?? '';
    final ln = lastName?.trim() ?? '';
    if (fn.isNotEmpty || ln.isNotEmpty) return '$fn $ln'.trim();
    return 'Unknown User';
  }

  String get verificationStatusLabel {
    final s = verification?.verificationStatus;
    if (s == 'approved') return 'Approved';
    if (s == 'rejected') return 'Rejected';
    if (verification?.isComplete == true) return 'Pending Review';
    return 'Not Submitted';
  }

  static DateTime? _timestamp(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  factory UserDocument.fromMap(Map<String, dynamic> map, {String? id}) {
    UserVerification? verification;
    final verMap = map['verification'];
    if (verMap is Map<String, dynamic>) {
      verification = UserVerification.fromMap(verMap);
    }
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
      verification: verification,
    );
  }

  factory UserDocument.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserDocument.fromMap(doc.data() ?? {}, id: doc.id);
  }
}
