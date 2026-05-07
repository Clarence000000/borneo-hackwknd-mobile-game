import 'package:cloud_firestore/cloud_firestore.dart';

/// BNPL installment plan model.
class BnplPlan {
  final String id;
  final String itemName;
  final double totalAmount;
  final int installments;
  int paidInstallments;
  final double monthlyAmount;
  DateTime nextDueDate;
  int? nextDueDay;
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
    this.nextDueDay,
    this.lateFees = 0,
    this.status = BnplStatus.active,
  });

  double get remainingAmount =>
      (installments - paidInstallments) * monthlyAmount + lateFees;

  bool get isOverdue =>
      status == BnplStatus.active && DateTime.now().isAfter(nextDueDate);

  bool isOverdueAtGameDay(int currentDay) {
    if (nextDueDay != null) {
      return status == BnplStatus.active && currentDay > nextDueDay!;
    }
    return isOverdue;
  }

  Map<String, dynamic> toMap() => {
    'itemName': itemName,
    'totalAmount': totalAmount,
    'installments': installments,
    'paidInstallments': paidInstallments,
    'monthlyAmount': monthlyAmount,
    'nextDueDate': nextDueDate.millisecondsSinceEpoch,
    'nextDueDay': nextDueDay,
    'lateFees': lateFees,
    'status': status.name,
  };

  factory BnplPlan.fromMap(String id, Map<String, dynamic> map) => BnplPlan(
    id: id,
    itemName: (map['itemName'] ?? map['description'] ?? map['merchant'] ?? 'BNPL Item') as String,
    totalAmount: (map['totalAmount'] as num).toDouble(),
    installments: map['installments'] as int,
    paidInstallments: map['paidInstallments'] as int? ?? 0,
    monthlyAmount: (map['monthlyAmount'] as num).toDouble(),
    nextDueDate: map['nextDueDate'] is int
        ? DateTime.fromMillisecondsSinceEpoch(map['nextDueDate'] as int)
        : map['nextDueDate'] is DateTime
        ? map['nextDueDate'] as DateTime
        : map['nextDueDate'] is Timestamp
        ? (map['nextDueDate'] as Timestamp).toDate()
        : DateTime.now(),
    nextDueDay: map['nextDueDay'] as int?,
    lateFees: (map['lateFees'] as num?)?.toDouble() ?? 0,
    status: BnplStatus.values.byName(map['status'] as String),
  );
}

enum BnplStatus { active, paid, defaulted }
