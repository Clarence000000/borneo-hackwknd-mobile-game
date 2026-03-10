/// Bank loan model.
class Loan {
  final String id;
  final double principal;
  final double interestRate;
  final double monthlyPayment;
  double remainingBalance;
  LoanStatus status;

  Loan({
    required this.id,
    required this.principal,
    required this.interestRate,
    required this.monthlyPayment,
    required this.remainingBalance,
    this.status = LoanStatus.active,
  });

  Map<String, dynamic> toMap() => {
        'principal': principal,
        'interestRate': interestRate,
        'monthlyPayment': monthlyPayment,
        'remainingBalance': remainingBalance,
        'status': status.name,
      };

  factory Loan.fromMap(String id, Map<String, dynamic> map) => Loan(
        id: id,
        principal: (map['principal'] as num).toDouble(),
        interestRate: (map['interestRate'] as num).toDouble(),
        monthlyPayment: (map['monthlyPayment'] as num).toDouble(),
        remainingBalance: (map['remainingBalance'] as num).toDouble(),
        status: LoanStatus.values.byName(map['status'] as String),
      );
}

enum LoanStatus { active, paid, defaulted }
