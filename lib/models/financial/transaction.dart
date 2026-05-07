import 'package:cloud_firestore/cloud_firestore.dart';

/// Financial transaction record.
class Transaction {
  final String id;
  final TransactionType paymentType;
  final TransactionCategory category;
  final double amount;
  final DateTime timestamp;
  final String description;

  const Transaction({
    required this.id,
    required this.paymentType,
    required this.category,
    required this.amount,
    required this.timestamp,
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
    'paymentType': paymentType.name,
    'category': category.name,
    'amount': amount,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'description': description,
  };

  factory Transaction.fromMap(String id, Map<String, dynamic> map) =>
      Transaction(
        id: id,
        paymentType: _parsePaymentType(map['paymentType']),
        category: _parseCategory(map['category']),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        timestamp: _parseTimestamp(map['timestamp']),
        description: map['description'] as String? ?? '',
      );
}

TransactionType _parsePaymentType(dynamic rawValue) {
  final value = rawValue?.toString() ?? '';
  if (value == TransactionType.bank.name) {
    return TransactionType.bank;
  }
  return TransactionType.cash;
}

TransactionCategory _parseCategory(dynamic rawValue) {
  final value = rawValue?.toString() ?? '';
  switch (value) {
    case 'cropSale':
    case 'sale':
      return TransactionCategory.cropSale;
    case 'seedPurchase':
    case 'seed':
      return TransactionCategory.seedPurchase;
    case 'equipment':
      return TransactionCategory.equipment;
    case 'bnplPayment':
      return TransactionCategory.bnplPayment;
    case 'loanPayment':
      return TransactionCategory.loanPayment;
    case 'insurancePremium':
      return TransactionCategory.insurancePremium;
    case 'bankDeposit':
    case 'deposit':
      return TransactionCategory.bankDeposit;
    case 'bankWithdrawal':
    case 'withdrawal':
      return TransactionCategory.bankWithdrawal;
    default:
      return TransactionCategory.equipment;
  }
}

DateTime _parseTimestamp(dynamic rawValue) {
  if (rawValue is Timestamp) {
    return rawValue.toDate();
  }
  if (rawValue is int) {
    return DateTime.fromMillisecondsSinceEpoch(rawValue);
  }
  if (rawValue is String) {
    final parsedInt = int.tryParse(rawValue);
    if (parsedInt != null) {
      return DateTime.fromMillisecondsSinceEpoch(parsedInt);
    }
    final parsedDate = DateTime.tryParse(rawValue);
    if (parsedDate != null) {
      return parsedDate;
    }
  }
  return DateTime.now();
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
  other,
}
