import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_document.dart';

class AdminFirestoreService {
  static final _db = FirebaseFirestore.instance;
  static final _users = _db.collection('users');

  // ── Stats ──────────────────────────────────────────────────────────────

  /// Stream of the total user count.
  Stream<int> totalUsersStream() {
    return _users.snapshots().map((s) => s.size);
  }

  /// Number of users who registered today (createdAt >= start of today).
  Future<int> newUsersToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _users
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    return snap.size;
  }

  /// Users who have a car added (have submitted at least the vehicle doc).
  Future<int> usersWithCars() async {
    final snap = await _users
        .where('verification.vehicleDocFrontUrl', isNotEqualTo: '')
        .get();
    return snap.docs
        .where((d) {
          final url = d.data()['verification']?['vehicleDocFrontUrl'];
          return url != null && (url as String).trim().isNotEmpty;
        })
        .length;
  }

  /// Users who submitted all 6 docs (pending review or any status).
  Future<int> usersWithPendingDocs() async {
    final snap = await _users
        .where('verification.verificationStatus', isEqualTo: 'pending')
        .get();
    return snap.size;
  }

  // ── User Lists ─────────────────────────────────────────────────────────

  /// Stream of all users, ordered by createdAt descending.
  Stream<List<UserDocument>> allUsersStream() {
    return _users
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(UserDocument.fromFirestore).toList());
  }

  /// Stream of users who have submitted docs (status = pending).
  Stream<List<UserDocument>> pendingVerificationStream() {
    return _users
        .where('verification.verificationStatus', isEqualTo: 'pending')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(UserDocument.fromFirestore).toList());
  }

  /// Stream of approved drivers.
  Stream<List<UserDocument>> approvedDriversStream() {
    return _users
        .where('verification.verificationStatus', isEqualTo: 'approved')
        .snapshots()
        .map((s) => s.docs.map(UserDocument.fromFirestore).toList());
  }

  // ── Verification Actions ───────────────────────────────────────────────

  Future<void> approveDriver(String userId) async {
    await _users.doc(userId).update({
      'verification.verificationStatus': 'verified',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectDriver(String userId, {String? reason}) async {
    await _users.doc(userId).update({
      'verification.verificationStatus': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resetVerification(String userId) async {
    await _users.doc(userId).update({
      'verification.verificationStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Stats snapshot (combined) ──────────────────────────────────────────

  Future<DashboardStats> getDashboardStats() async {
    final results = await Future.wait([
      _users.get(),
      newUsersToday(),
      usersWithPendingDocs(),
    ]);

    final allSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final today = results[1] as int;
    final pending = results[2] as int;

    int withCars = 0;
    int approved = 0;
    for (final doc in allSnap.docs) {
      final ver = doc.data()['verification'];
      if (ver is Map<String, dynamic>) {
        final vehicleFront = ver['vehicleDocFrontUrl']?.toString() ?? '';
        if (vehicleFront.isNotEmpty) withCars++;
        if (ver['verificationStatus'] == 'approved') approved++;
      }
    }

    return DashboardStats(
      totalUsers: allSnap.size,
      newUsersToday: today,
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
