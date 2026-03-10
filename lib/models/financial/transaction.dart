/// Financial transaction record.
class Transaction {
  final String id;
  final TransactionType paymentType;
  final TransactionCategory category;
  final double amount;
  final DateTime timestamp;

  const Transaction({
    required this.id,
    required this.paymentType,
    required this.category,
    required this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'paymentType': paymentType.name,
        'category': category.name,
        'amount': amount,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory Transaction.fromMap(String id, Map<String, dynamic> map) =>
      Transaction(
        id: id,
        paymentType:
            TransactionType.values.byName(map['paymentType'] as String),
        category:
            TransactionCategory.values.byName(map['category'] as String),
        amount: (map['amount'] as num).toDouble(),
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      );
}

enum TransactionType { cash, bank }

enum TransactionCategory {
  cropSale,
  seedPurchase,
  equipment,
  bnplPayment,
  loanPayment,
  insurancePremium,
  bankDeposit,
  bankWithdrawal,
}
