import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.bestTimeSec,
    required this.bestDistanceKm,
    required this.lastUpdated,
  });

  final String uid;
  final String displayName;
  final int bestTimeSec;
  final double bestDistanceKm;
  final DateTime? lastUpdated;

  factory LeaderboardEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final updated = data['lastUpdated'];
    return LeaderboardEntry(
      uid: document.id,
      displayName: data['displayName'] as String? ?? 'Runner',
      bestTimeSec: (data['bestTime'] as num?)?.toInt() ?? 0,
      bestDistanceKm: (data['bestDistance'] as num?)?.toDouble() ?? 0,
      lastUpdated: updated is Timestamp ? updated.toDate() : null,
    );
  }
}
