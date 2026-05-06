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
  bool isAdmin;

  // Equipment effects
  bool tractorOwned;
  bool autoHarvestEnabled;
  int fertilizerPackCount;

  // Inventory: crop key -> quantity (e.g. {'wheat': 5})
  Map<String, int> inventory;

  // Game Day Persistence
  int currentDay;
  int remainingCycleSeconds; // Intra-day time progress (counts down from max)
  int manualNextDayUsedToday;
  DateTime manualNextDayUsageDate;

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
    this.isAdmin = false,
    this.tractorOwned = false,
    this.autoHarvestEnabled = false,
    this.fertilizerPackCount = 0,
    Map<String, int>? inventory,
    this.currentDay = 1,
    this.remainingCycleSeconds = 20 * 60, // Default: kGameDayDurationMinutes * 60
    this.manualNextDayUsedToday = 0,
    DateTime? manualNextDayUsageDate,
  }) : inventory = Map<String, int>.from(inventory ?? {}),
       createdAt = createdAt ?? DateTime.now(),
       manualNextDayUsageDate = manualNextDayUsageDate ?? DateTime.now();

  double get totalNetWorth =>
      cashBalance + bankBalance; // minus debts added later

  int get totalInventoryItems =>
      inventory.values.fold(0, (sum, quantity) => sum + quantity);

  /// Pay from the specified method. Returns true if sufficient balance.
  bool pay(double amount, {required PaymentMethod method}) {
    if (isAdmin) return true;

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
    'isAdmin': isAdmin,
    'tractorOwned': tractorOwned,
    'autoHarvestEnabled': autoHarvestEnabled,
    'fertilizerPackCount': fertilizerPackCount,
    'inventory': inventory,
    'currentDay': currentDay,
    'remainingCycleSeconds': remainingCycleSeconds,
    'manualNextDayUsedToday': manualNextDayUsedToday,
    'manualNextDayUsageDate': manualNextDayUsageDate.millisecondsSinceEpoch,
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
    isAdmin: map['isAdmin'] as bool? ?? false,
    tractorOwned: map['tractorOwned'] as bool? ?? false,
    autoHarvestEnabled: map['autoHarvestEnabled'] as bool? ?? false,
    fertilizerPackCount: map['fertilizerPackCount'] as int? ?? 0,
    inventory:
        (map['inventory'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
        ) ??
        {},
    currentDay: (map['currentDay'] as int?) ?? 1,
    remainingCycleSeconds: (map['remainingCycleSeconds'] as int?) ?? (20 * 60),
    manualNextDayUsedToday: (map['manualNextDayUsedToday'] as int?) ?? 0,
    manualNextDayUsageDate: map['manualNextDayUsageDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['manualNextDayUsageDate'] as int)
        : null,
  );
}

enum PaymentMethod { cash, bank }
