class FixedDeposit {
  final String id;
  final double principal;
  final double interestRate; // e.g. 0.05 for 5%
  final int durationMonths;
  final int startDay;
  final int endDay;
  bool isMatured;

  FixedDeposit({
    required this.id,
    required this.principal,
    required this.interestRate,
    required this.durationMonths,
    required this.startDay,
    required this.endDay,
    this.isMatured = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'principal': principal,
        'interestRate': interestRate,
        'durationMonths': durationMonths,
        'startDay': startDay,
        'endDay': endDay,
        'isMatured': isMatured,
      };

  factory FixedDeposit.fromMap(Map<String, dynamic> map) => FixedDeposit(
        id: map['id'] as String,
        principal: (map['principal'] as num).toDouble(),
        interestRate: (map['interestRate'] as num).toDouble(),
        durationMonths: map['durationMonths'] as int,
        startDay: map['startDay'] as int,
        endDay: map['endDay'] as int,
        isMatured: map['isMatured'] as bool? ?? false,
      );
}
