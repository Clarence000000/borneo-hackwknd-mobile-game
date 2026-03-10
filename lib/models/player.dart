/// Player profile and wallet model.
class Player {
  String uid;
  String displayName;
  String country; // e.g. "MY", "ID"
  String currency; // e.g. "XMYR", "XIDR"
  double gpsLat;
  double gpsLng;
  bool tutorialCompleted;
  DateTime createdAt;

  // Wallet
  double cashBalance;
  double bankBalance;
  bool bankRegistered;

  // Credit
  int creditScore;

  Player({
    required this.uid,
    required this.displayName,
    required this.country,
    required this.currency,
    this.gpsLat = 0,
    this.gpsLng = 0,
    this.tutorialCompleted = false,
    DateTime? createdAt,
    this.cashBalance = 1000.0,
    this.bankBalance = 0,
    this.bankRegistered = false,
    this.creditScore = 500,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalNetWorth => cashBalance + bankBalance; // minus debts added later

  /// Pay from the specified method. Returns true if sufficient balance.
  bool pay(double amount, {required PaymentMethod method}) {
    switch (method) {
      case PaymentMethod.cash:
        if (cashBalance < amount) return false;
        cashBalance -= amount;
        return true;
      case PaymentMethod.bank:
        if (!bankRegistered) return false;
        if (bankBalance < amount) return false;
        bankBalance -= amount;
        return true;
    }
  }

  /// Deposit money into wallet.
  void deposit(double amount, {required PaymentMethod method}) {
    switch (method) {
      case PaymentMethod.cash:
        cashBalance += amount;
      case PaymentMethod.bank:
        bankBalance += amount;
    }
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'country': country,
        'currency': currency,
        'gpsLat': gpsLat,
        'gpsLng': gpsLng,
        'tutorialCompleted': tutorialCompleted,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'cashBalance': cashBalance,
        'bankBalance': bankBalance,
        'bankRegistered': bankRegistered,
        'creditScore': creditScore,
      };

  factory Player.fromMap(String uid, Map<String, dynamic> map) => Player(
        uid: uid,
        displayName: map['displayName'] as String? ?? '',
        country: map['country'] as String? ?? 'MY',
        currency: map['currency'] as String? ?? 'XMYR',
        gpsLat: (map['gpsLat'] as num?)?.toDouble() ?? 0,
        gpsLng: (map['gpsLng'] as num?)?.toDouble() ?? 0,
        tutorialCompleted: map['tutorialCompleted'] as bool? ?? false,
        createdAt: map['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
            : null,
        cashBalance: (map['cashBalance'] as num?)?.toDouble() ?? 1000.0,
        bankBalance: (map['bankBalance'] as num?)?.toDouble() ?? 0,
        bankRegistered: map['bankRegistered'] as bool? ?? false,
        creditScore: map['creditScore'] as int? ?? 500,
      );
}

enum PaymentMethod { cash, bank }
