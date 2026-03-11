import 'package:flutter/material.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/services/gemini_service.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';

/// Financial Advisor NPC that pops up with warnings.
class FinancialAdvisor {
  static final GeminiService _gemini = GeminiService();
  FinancialAdvisor._();

  /// Warn about taking a loan they can't afford.
  static Future<void> warnLoan(BuildContext context, Player player, double monthlyPayment, double monthlyIncome) async {
    final ratio = monthlyPayment / monthlyIncome;
    if (ratio < 0.3 && player.creditScore >= 650) return Future.value(); // Not dangerous
    
    // Call Gemini!
    final msg = await _gemini.getFinancialAdvice(player, 'Taking a loan that is ${(ratio*100).toInt()}% of my income, and my credit score is ${player.creditScore}. Is this smart?');
    if (!context.mounted) return;

    return DialogPopup.show(
      context,
      title: '🤖 Ai Advisor',
      message: msg,
      icon: Icons.psychology,
      iconColor: GameColors.uiAccent,
      buttonText: 'I understand the risk',
    );
  }

  /// Warn about BNPL overcommitment.
  static Future<void> warnBnpl(BuildContext context, Player player, int activePlans) async {
    if (activePlans < 2 && player.cashBalance > 500) return Future.value();

    // Call Gemini!
    final msg = await _gemini.getFinancialAdvice(player, 'I am taking out BNPL installment plan #${activePlans+1}. My cash is ${player.cashBalance}.');
    if (!context.mounted) return;

    return DialogPopup.show(
      context,
      title: '🤖 Ai Advisor',
      message: msg,
      icon: Icons.psychology,
      iconColor: GameColors.uiAccent,
      buttonText: 'I\'ll be careful',
    );
  }

  /// Suggest buying insurance.
  static Future<void> suggestInsurance(BuildContext context, Player player, int uninsuredCrops) async {
    if (uninsuredCrops < 3) return Future.value();

    // Call Gemini!
    final msg = await _gemini.getFinancialAdvice(player, 'I have $uninsuredCrops uninsured crops. The weather looks somewhat suspicious. Should I buy crop insurance?');
    if (!context.mounted) return;

    return DialogPopup.show(
      context,
      title: '🤖 Ai Advisor',
      message: msg,
      icon: Icons.psychology,
      iconColor: GameColors.uiAccent,
      buttonText: 'Good idea!',
    );
  }
}
