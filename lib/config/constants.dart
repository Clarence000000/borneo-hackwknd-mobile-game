/// Game constants and configuration
library;

// ─── Grid & Tile ───────────────────────────────────────────────
const int kGridCols = 60; // Matches Tiled map width
const int kGridRows = 40; // Matches Tiled map height
const double kTileWidth = 16.0;
const double kTileHeight = 16.0;

// ─── Currency Map (ASEAN) ──────────────────────────────────────
const Map<String, String> kCountryCurrency = {
  'MY': 'XMYR',
  'ID': 'XIDR',
  'SG': 'XSGD',
  'TH': 'XTHB',
  'PH': 'XPHP',
  'VN': 'XVND',
};

const Map<String, String> kCurrencySymbol = {
  'XMYR': 'RM',
  'XIDR': 'Rp',
  'XSGD': 'S\$',
  'XTHB': '฿',
  'XPHP': '₱',
  'XVND': '₫',
};

// ─── Starting Balance ──────────────────────────────────────────
const double kStartingCash = 1000.0;

// ─── Credit Score ──────────────────────────────────────────────
const int kMinCreditScore = 300;
const int kMaxCreditScore = 850;
const int kStartingCreditScore = 500;

// ─── Crop Config ───────────────────────────────────────────────
enum CropType { wheat, rice, corn }

const Map<CropType, Map<String, dynamic>> kCropConfig = {
  CropType.wheat: {
    'name': 'Wheat',
    'growthDays': 3,
    'seedCost': 10.0,
    'sellPrice': 30.0,
  },
  CropType.rice: {
    'name': 'Paddy',
    'growthDays': 5,
    'seedCost': 20.0,
    'sellPrice': 60.0,
  },
  CropType.corn: {
    'name': 'Corn',
    'growthDays': 4,
    'seedCost': 15.0,
    'sellPrice': 45.0,
  },
};

// ─── BNPL Config ───────────────────────────────────────────────
const double kBnplAdminFee = 10.0;
const double kBnplLateFee = 23.0;
const List<int> kBnplInstallmentOptions = [3, 6];

// ─── Loan Config ───────────────────────────────────────────────
const double kLoanInterestRate = 0.05; // 5% monthly
const int kMinLoanCreditScore = 600;

// ─── Insurance Config ──────────────────────────────────────────
const double kInsurancePremiumRate = 0.10; // 10% of coverage

// ─── Disaster Config ───────────────────────────────────────────
// Fallback client-side disaster roll per in-game day when API reports no disaster.
const double kDailyDisasterChance = 0.10;

// ─── Game Time & Skip-Day Config ───────────────────────────────
const int kGameDayDurationMinutes = 20;
const int kGameDaylightMinutes = 10;
const int kGameNightMinutes = 10;
const int kGameDaysPerMonth = 30;
const int kGameMonthsPerYear = 12;
const int kFreeManualNextDayPerRealDay = 5;
const double kManualNextDayCost = 10.0;

// ─── Admin Test Account ───────────────────────────────────────
const Set<String> kAdminTestEmails = {'admin@farmfintech.test'};
const double kAdminUnlimitedBalance = 999999999.0;
