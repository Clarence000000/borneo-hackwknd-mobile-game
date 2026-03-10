/// Weather/disaster event model.
class WeatherEvent {
  final String id;
  final DisasterType type;
  final double severity; // 0.0 - 1.0
  final int cropsDestroyed;
  final double insurancePayout;
  final DateTime timestamp;

  const WeatherEvent({
    required this.id,
    required this.type,
    required this.severity,
    this.cropsDestroyed = 0,
    this.insurancePayout = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'severity': severity,
        'cropsDestroyed': cropsDestroyed,
        'insurancePayout': insurancePayout,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory WeatherEvent.fromMap(String id, Map<String, dynamic> map) =>
      WeatherEvent(
        id: id,
        type: DisasterType.values.byName(map['type'] as String),
        severity: (map['severity'] as num).toDouble(),
        cropsDestroyed: map['cropsDestroyed'] as int? ?? 0,
        insurancePayout:
            (map['insurancePayout'] as num?)?.toDouble() ?? 0,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      );
}

enum DisasterType { flood, drought, storm, none }
