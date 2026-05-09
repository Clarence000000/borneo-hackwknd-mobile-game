import 'package:farm_fintech/config/constants.dart';

/// Pure client-side credit score engine.
///
/// Score range: 300 – 850 (mirrors real-world FICO).
/// This replaces the server-only `calculateCreditScore` Cloud Function
/// with a deterministic, event-driven scoring system.
///
/// ## Score Events (positive)
///  +5  Bank deposit (max +5/day)
///  +3  On-time BNPL repayment
///  +3  On-time loan shark repayment
///  +2  Sell crops at merchant
///  +2  Buy insurance
///  +1  Buy seeds (investing in farm)
///  +5  Fixed deposit created
///  +10 Fully repay a BNPL plan
///  +8  Fully repay a loan shark loan
///  +3  Consecutive savings streak (7+ days with bank balance > 0)
///
/// ## Score Events (negative)
///  -15 Take a loan shark loan
///  -10 Late BNPL payment (per missed installment)
///  -8  Loan shark auto-penalty (couldn't pay monthly)
///  -5  BNPL late fee incurred
///  -3  Bank balance hits 0 (broke)
///  -2  Miss rent payment attempt
class CreditScoreService {
  // Track streaks per session
  int _consecutiveSavingsDays = 0;
  int _depositsToday = 0;
  int _lastDepositDay = -1;

  /// Apply a credit score change and clamp to valid range.
  int _apply(int currentScore, int delta) {
    return (currentScore + delta).clamp(kMinCreditScore, kMaxCreditScore);
  }

  /// Reset daily counters when a new day starts.
  void onNewDay(int currentDay, double bankBalance) {
    _depositsToday = 0;

    // Track savings streak
    if (bankBalance > 0) {
      _consecutiveSavingsDays++;
    } else {
      _consecutiveSavingsDays = 0;
    }
  }

  // ─── Positive Events ──────────────────────────────────────

  /// Player deposited money into bank.
  int onBankDeposit(int currentScore, int currentDay) {
    if (_lastDepositDay != currentDay) {
      _depositsToday = 0;
      _lastDepositDay = currentDay;
    }
    if (_depositsToday >= 1) return currentScore; // Max +5 per day
    _depositsToday++;
    return _apply(currentScore, 5);
  }

  /// Player sold crops at merchant (earning income).
  int onSellCrops(int currentScore) {
    return _apply(currentScore, 2);
  }

  /// Player bought seeds (investing in future).
  int onBuySeeds(int currentScore) {
    return _apply(currentScore, 1);
  }

  /// Player paid BNPL installment on time.
  int onBnplRepaidOnTime(int currentScore) {
    return _apply(currentScore, 3);
  }

  /// Player fully completed a BNPL plan.
  int onBnplFullyRepaid(int currentScore) {
    return _apply(currentScore, 10);
  }

  /// Player bought insurance (responsible financial behavior).
  int onBuyInsurance(int currentScore) {
    return _apply(currentScore, 2);
  }

  /// Player created a fixed deposit (long-term saving).
  int onCreateFixedDeposit(int currentScore) {
    return _apply(currentScore, 5);
  }

  /// Player repaid loan shark loan on time.
  int onSharkLoanRepaid(int currentScore) {
    return _apply(currentScore, 3);
  }

  /// Player fully repaid all shark debt.
  int onSharkLoanFullyRepaid(int currentScore) {
    return _apply(currentScore, 8);
  }

  /// Bonus for consecutive savings days (every 7 days).
  int onSavingsStreakCheck(int currentScore) {
    if (_consecutiveSavingsDays > 0 && _consecutiveSavingsDays % 7 == 0) {
      return _apply(currentScore, 3);
    }
    return currentScore;
  }

  /// Player paid rent successfully.
  int onRentPaid(int currentScore) {
    return _apply(currentScore, 2);
  }

  // ─── Negative Events ──────────────────────────────────────

  /// Player took a loan shark loan (risky behavior).
  int onTakeLoanSharkLoan(int currentScore) {
    return _apply(currentScore, -15);
  }

  /// Player missed a BNPL payment (late).
  int onBnplLatePayment(int currentScore) {
    return _apply(currentScore, -10);
  }

  /// BNPL late fee was incurred.
  int onBnplLateFee(int currentScore) {
    return _apply(currentScore, -5);
  }

  /// Loan shark auto-deducted penalty because player couldn't pay.
  int onSharkLoanPenalty(int currentScore) {
    return _apply(currentScore, -8);
  }

  /// Player's bank balance hit zero.
  int onBankBalanceZero(int currentScore) {
    return _apply(currentScore, -3);
  }

  /// Player couldn't pay rent.
  int onRentFailed(int currentScore) {
    return _apply(currentScore, -2);
  }
}
