/// Game constants and configuration
library;

// ─── Grid & Tile ───────────────────────────────────────────────
const int kGridCols = 8;
const int kGridRows = 8;
const double kTileWidth = 64.0;
const double kTileHeight = 32.0;

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
    'name': 'Rice',
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
