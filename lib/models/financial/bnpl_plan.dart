/// BNPL installment plan model.
class BnplPlan {
  final String id;
  final String itemName;
  final double totalAmount;
  final int installments;
  int paidInstallments;
  final double monthlyAmount;
  DateTime nextDueDate;
  double lateFees;
  BnplStatus status;

  BnplPlan({
    required this.id,
    required this.itemName,
    required this.totalAmount,
    required this.installments,
    this.paidInstallments = 0,
    required this.monthlyAmount,
    required this.nextDueDate,
    this.lateFees = 0,
    this.status = BnplStatus.active,
  });

  double get remainingAmount =>
      (installments - paidInstallments) * monthlyAmount + lateFees;

  bool get isOverdue =>
      status == BnplStatus.active && DateTime.now().isAfter(nextDueDate);

  Map<String, dynamic> toMap() => {
        'itemName': itemName,
        'totalAmount': totalAmount,
        'installments': installments,
        'paidInstallments': paidInstallments,
        'monthlyAmount': monthlyAmount,
        'nextDueDate': nextDueDate.millisecondsSinceEpoch,
        'lateFees': lateFees,
        'status': status.name,
      };

  factory BnplPlan.fromMap(String id, Map<String, dynamic> map) => BnplPlan(
        id: id,
        itemName: map['itemName'] as String,
        totalAmount: (map['totalAmount'] as num).toDouble(),
        installments: map['installments'] as int,
        paidInstallments: map['paidInstallments'] as int? ?? 0,
        monthlyAmount: (map['monthlyAmount'] as num).toDouble(),
        nextDueDate: DateTime.fromMillisecondsSinceEpoch(
            map['nextDueDate'] as int),
        lateFees: (map['lateFees'] as num?)?.toDouble() ?? 0,
        status: BnplStatus.values.byName(map['status'] as String),
      );
}

enum BnplStatus { active, paid, defaulted }
