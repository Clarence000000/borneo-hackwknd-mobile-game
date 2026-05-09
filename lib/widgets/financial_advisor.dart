import 'package:flutter/material.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/services/gemini_service.dart';
import 'package:farm_fintech/widgets/oracle_chat_dialog.dart';

/// Financial Advisor NPC that pops up with warnings.
class FinancialAdvisor {
  static final GeminiService _gemini = GeminiService();
  FinancialAdvisor._();

  /// Warn about taking a loan they can't afford. Returns true if they proceed.
  static Future<bool> warnLoan(BuildContext context, Player player, double monthlyPayment, double monthlyIncome) async {
    final ratio = monthlyPayment / monthlyIncome;
    if (ratio < 0.3 && player.creditScore >= 650) return true; // Not dangerous
    
    // Call Gemini!
    final msg = await _gemini.getFinancialAdvice(player, 'Taking a loan that is ${(ratio*100).toInt()}% of my income, and my credit score is ${player.creditScore}. Is this smart?');
    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OracleChatDialog(
        initialTrustScore: (player.creditScore / 850 * 100).toInt(),
        initialWarning: msg,
        isDangerous: true,
        isWarningMode: true,
      ),
    );
    return result ?? false;
  }

  /// Warn about BNPL overcommitment. Returns true if they proceed.
  static Future<bool> warnBnpl(BuildContext context, Player player, int activePlans) async {
    if (activePlans < 2 && player.cashBalance > 500) return true;

    // Call Gemini!
    final msg = await _gemini.getFinancialAdvice(player, 'I am taking out BNPL installment plan #${activePlans+1}. My cash is ${player.cashBalance}.');
    if (!context.mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OracleChatDialog(
        initialTrustScore: (player.creditScore / 850 * 100).toInt(),
        initialWarning: msg,
        isDangerous: true,
        isWarningMode: true,
      ),
    );
    return result ?? false;
  }

  /// Suggest buying insurance. Returns true if they proceed.
  static Future<bool> suggestInsurance(BuildContext context, Player player, int uninsuredCrops) async {
    if (uninsuredCrops < 3) return true;

    // Call Gemini!
    final msg = await _gemini.getFinancialAdvice(player, 'I have $uninsuredCrops uninsured crops. The weather looks somewhat suspicious. Should I buy crop insurance?');
    if (!context.mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OracleChatDialog(
        initialTrustScore: (player.creditScore / 850 * 100).toInt(),
        initialWarning: msg,
        isDangerous: false,
        isWarningMode: true,
      ),
    );
    return result ?? false;
  }

  // ── Debug / AI Testing methods (bypass threshold checks) ──────

  /// Debug: Always trigger loan warning regardless of thresholds.
  static Future<void> forceWarnLoan(BuildContext context, Player player) async {
    final msg = await _gemini.getFinancialAdvice(
      player,
      'Taking a loan that is 50% of my income, and my credit score is ${player.creditScore}. Is this smart?',
    );
    if (!context.mounted) return;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OracleChatDialog(
        initialTrustScore: (player.creditScore / 850 * 100).toInt(),
        initialWarning: msg,
        isDangerous: true,
        isWarningMode: true,
        warningButtonText: 'I UNDERSTAND THE RISK',
      ),
    );
  }

  /// Debug: Always trigger BNPL warning regardless of thresholds.
  static Future<void> forceWarnBnpl(BuildContext context, Player player) async {
    final msg = await _gemini.getFinancialAdvice(
      player,
      'I am taking out BNPL installment plan #4. My cash is ${player.cashBalance}. I already have 3 active plans.',
    );
    if (!context.mounted) return;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OracleChatDialog(
        initialTrustScore: (player.creditScore / 850 * 100).toInt(),
        initialWarning: msg,
        isDangerous: true,
        isWarningMode: true,
        warningButtonText: 'I\'LL BE CAREFUL',
      ),
    );
  }

  /// Debug: Always trigger insurance suggestion regardless of thresholds.
  static Future<void> forceSuggestInsurance(BuildContext context, Player player) async {
    final msg = await _gemini.getFinancialAdvice(
      player,
      'I have 5 uninsured crops. The weather looks very suspicious. Should I buy crop insurance?',
    );
    if (!context.mounted) return;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OracleChatDialog(
        initialTrustScore: (player.creditScore / 850 * 100).toInt(),
        initialWarning: msg,
        isDangerous: false,
        isWarningMode: true,
        warningButtonText: 'GOOD IDEA!',
      ),
    );
  }

  /// Debug: Force a danger analysis and show the result.
  static Future<void> forceDangerAnalysis(BuildContext context, Player player, {
    required int bnplCount,
    required int loanCount,
    required int currentDay,
    required String activeDisaster,
  }) async {
    final result = await _gemini.analyzeFinancialDanger(
      player: player,
      activeBnplCount: bnplCount,
      activeLoanCount: loanCount,
      currentDay: currentDay,
      activeDisaster: activeDisaster,
    );
    if (!context.mounted) return;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OracleChatDialog(
        initialTrustScore: result.trustScore,
        initialWarning: result.warningMessage,
        isDangerous: result.isDangerous,
        isWarningMode: true,
        warningButtonText: 'I SEE...',
      ),
    );
  }
}
