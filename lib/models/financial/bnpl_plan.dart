import 'package:farm_fintech/config/constants.dart';

/// BNPL installment plan model.
///
/// All due-day arithmetic is derived from [startDay]: installment N is due
/// at `startDay + (N - 1) * kGameDaysPerMonth`. Installment 1 is the
/// down-payment (paid at purchase, due day = startDay).
///
/// [monthlyFines] holds a one-time 50% late fee per overdue installment,
/// keyed by 1-based installment index. Fines are sparse: only unpaid months
/// past their due day have entries. Paying an installment removes its fine.
class BnplPlan {
  final String id;
  final String itemName;
  final double totalAmount;
  final int installments;
  int paidInstallments;
  final double monthlyAmount;
  final int startDay;
  Map<int, double> monthlyFines;
  BnplStatus status;

  BnplPlan({
    required this.id,
    required this.itemName,
    required this.totalAmount,
    required this.installments,
    required this.monthlyAmount,
    required this.startDay,
    this.paidInstallments = 1,
    Map<int, double>? monthlyFines,
    this.status = BnplStatus.active,
  }) : monthlyFines = monthlyFines ?? {};

  // ── Per-installment helpers ────────────────────────────────────
  int dueDayOf(int n) => startDay + (n - 1) * kGameDaysPerMonth;

  int get nextUnpaidIndex => paidInstallments + 1;

  double fineFor(int n) => monthlyFines[n] ?? 0;

  // ── Day-relative computations ──────────────────────────────────
  /// How many installments *should* be paid by [currentDay].
  /// Strict: an installment whose due day equals currentDay is NOT yet overdue.
  int expectedPaidByDay(int currentDay) {
    if (currentDay <= startDay) return 1; // down-payment counts as installment 1
    final k = 1 + ((currentDay - startDay - 1) ~/ kGameDaysPerMonth);
    return k.clamp(0, installments);
  }

  int overdueCountAtDay(int day) =>
      (expectedPaidByDay(day) - paidInstallments).clamp(0, installments);

  int prepaidCountAtDay(int day) =>
      (paidInstallments - expectedPaidByDay(day)).clamp(0, installments);

  // ── Amount helpers ─────────────────────────────────────────────
  double get totalOutstandingFines =>
      monthlyFines.values.fold(0.0, (s, v) => s + v);

  double get remainingAmount =>
      (installments - paidInstallments) * monthlyAmount + totalOutstandingFines;

  /// Amount charged on a single Repay click (oldest unpaid month first).
  double oldestUnpaidAmount() {
    if (paidInstallments >= installments) return 0;
    return monthlyAmount + fineFor(nextUnpaidIndex);
  }

  // ── Status label ───────────────────────────────────────────────
  String statusLabelAtDay(int day) {
    if (paidInstallments >= installments) return 'Paid';
    final overdue = overdueCountAtDay(day);
    if (overdue > 0) {
      return overdue == 1 ? 'Overdue by 1 month' : 'Overdue by $overdue months';
    }
    final prepaid = prepaidCountAtDay(day);
    if (prepaid > 0) return 'Overpaid for month $paidInstallments';
    if (day >= dueDayOf(nextUnpaidIndex)) return 'Due by this month';
    return 'Paid';
  }

  // ── Serialization ──────────────────────────────────────────────
  Map<String, dynamic> toMap() => {
    'itemName': itemName,
    'totalAmount': totalAmount,
    'installments': installments,
    'paidInstallments': paidInstallments,
    'monthlyAmount': monthlyAmount,
    'startDay': startDay,
    'monthlyFines': monthlyFines.map((k, v) => MapEntry(k.toString(), v)),
    'status': status.name,
  };

  factory BnplPlan.fromMap(String id, Map<String, dynamic> map) {
    final installments = (map['installments'] ?? map['termMonths'] ?? 0) as int;
    final paid = (map['paidInstallments'] ?? map['paidMonths'] ?? 0) as int;
    final monthly = ((map['monthlyAmount'] ?? map['monthlyPayment']) as num).toDouble();

    // startDay: prefer new field; reconstruct from legacy nextDueDay if available.
    int startDay;
    if (map['startDay'] is int) {
      startDay = map['startDay'] as int;
    } else if (map['nextDueDay'] is int) {
      startDay = (map['nextDueDay'] as int) - paid * kGameDaysPerMonth;
    } else {
      startDay = 0;
    }

    // monthlyFines: read new map, or roll legacy flat lateFees into next-unpaid month.
    final fines = <int, double>{};
    final raw = map['monthlyFines'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final i = int.tryParse(k.toString());
        if (i != null && v is num) fines[i] = v.toDouble();
      });
    } else {
      final legacy = (map['lateFees'] as num?)?.toDouble() ?? 0;
      if (legacy > 0 && paid < installments) fines[paid + 1] = legacy;
    }

    return BnplPlan(
      id: id,
      itemName: (map['itemName'] ?? map['description'] ?? map['merchant'] ?? 'BNPL Item') as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      installments: installments,
      paidInstallments: paid,
      monthlyAmount: monthly,
      startDay: startDay,
      monthlyFines: fines,
      status: BnplStatus.values.byName((map['status'] as String?) ?? 'active'),
    );
  }
}

enum BnplStatus { active, paid, defaulted }
