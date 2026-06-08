import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore ride time helpers (aligned with carpool [AddRidePayload]).
class RideFirestoreUtils {
  RideFirestoreUtils._();

  static List<String> parseOtherStops(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];
    return trimmed
        .split(RegExp(r'[,\r\n\-]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static (int hour, int minute) timeOfDayFromString(String rideTime) {
    final parts = rideTime.split(':');
    if (parts.length != 2) return (0, 0);
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return (0, 0);
    return (h.clamp(0, 23), m.clamp(0, 59));
  }

  static String timeStrFromJson(dynamic timeVal, dynamic stampVal) {
    if (timeVal is String && timeVal.contains(':')) return timeVal;
    if (stampVal is Timestamp) {
      final d = stampVal.toDate();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    if (timeVal is Timestamp) {
      final d = timeVal.toDate();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '00:00';
  }

  static DateTime rideStartLocal(
    DateTime rideDate,
    int startHour,
    int startMinute,
  ) {
    return DateTime(
      rideDate.year,
      rideDate.month,
      rideDate.day,
      startHour,
      startMinute,
    );
  }

  static DateTime rideEndLocalWithMidnightRollover(
    DateTime rideDate,
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
  ) {
    final start = rideStartLocal(rideDate, startHour, startMinute);
    var end = DateTime(rideDate.year, rideDate.month, rideDate.day, endHour, endMinute);
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  static ({Timestamp start, Timestamp end}) timestampsForDate(
    DateTime rideDate,
    String startTime,
    String endTime,
  ) {
    final (sh, sm) = timeOfDayFromString(startTime);
    final (eh, em) = timeOfDayFromString(endTime);
    final start = rideStartLocal(rideDate, sh, sm);
    final end = rideEndLocalWithMidnightRollover(rideDate, sh, sm, eh, em);
    return (
      start: Timestamp.fromDate(start),
      end: Timestamp.fromDate(end),
    );
  }
}
