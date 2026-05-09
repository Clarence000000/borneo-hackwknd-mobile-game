import 'package:farm_fintech/config/constants.dart';

enum InsuranceType { flood, storm, drought }

class Insurance {
  final String id;
  final InsuranceType type;
  final double premium;
  final int expiryDay; // Game day when it expires
  bool isClaimed;

  Insurance({
    required this.id,
    required this.type,
    required this.premium,
    required this.expiryDay,
    this.isClaimed = false,
  });

  bool isExpired(int currentDay) => currentDay >= expiryDay;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'premium': premium,
        'expiryDay': expiryDay,
        'isClaimed': isClaimed,
      };

  factory Insurance.fromMap(Map<String, dynamic> map) => Insurance(
        id: map['id'] as String,
        type: InsuranceType.values.byName(map['type'] as String),
        premium: (map['premium'] as num).toDouble(),
        expiryDay: map['expiryDay'] as int,
        isClaimed: map['isClaimed'] as bool? ?? false,
      );
}
