/// Crop disaster insurance model.
class Insurance {
  final String id;
  final String plotId;
  final double premium;
  final double coverageAmount;
  final DateTime expiresAt;
  InsuranceStatus status;

  Insurance({
    required this.id,
    required this.plotId,
    required this.premium,
    required this.coverageAmount,
    required this.expiresAt,
    this.status = InsuranceStatus.active,
  });

  bool get isExpired =>
      status == InsuranceStatus.active && DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toMap() => {
        'plotId': plotId,
        'premium': premium,
        'coverageAmount': coverageAmount,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'status': status.name,
      };

  factory Insurance.fromMap(String id, Map<String, dynamic> map) => Insurance(
        id: id,
        plotId: map['plotId'] as String,
        premium: (map['premium'] as num).toDouble(),
        coverageAmount: (map['coverageAmount'] as num).toDouble(),
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int),
        status: InsuranceStatus.values.byName(map['status'] as String),
      );
}

enum InsuranceStatus { active, expired, claimed }
