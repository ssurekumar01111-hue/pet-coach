import 'package:cloud_firestore/cloud_firestore.dart';

class GpsPoint {
  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  factory GpsPoint.fromMap(Map<String, dynamic> map) => GpsPoint(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        timestamp: (map['timestamp'] as Timestamp).toDate(),
        accuracy: (map['accuracy'] as num?)?.toDouble(),
      );
  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': Timestamp.fromDate(timestamp),
        if (accuracy != null) 'accuracy': accuracy,
      };
}
