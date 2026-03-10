import 'package:flutter/material.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';

/// Financial Advisor NPC that pops up with warnings.
class FinancialAdvisor {
  FinancialAdvisor._();

  /// Warn about taking a loan they can't afford.
  static Future<void> warnLoan(BuildContext context, double monthlyPayment, double monthlyIncome) {
    final ratio = monthlyPayment / monthlyIncome;
    if (ratio < 0.3) return Future.value(); // Not dangerous

    return DialogPopup.show(
      context,
      title: '⚠️ Financial Advisor',
      message:
          'This loan payment would be ${(ratio * 100).toStringAsFixed(0)}% of your monthly income. '
          'Financial experts recommend keeping debt payments below 30% of income. '
          'Taking this loan could put you in a debt trap!',
      icon: Icons.warning_amber_rounded,
      iconColor: GameColors.uiRed,
      buttonText: 'I understand the risk',
    );
  }

  /// Warn about BNPL overcommitment.
  static Future<void> warnBnpl(BuildContext context, int activePlans) {
    if (activePlans < 2) return Future.value();

    return DialogPopup.show(
      context,
      title: '⚠️ BNPL Warning',
      message:
          'You already have $activePlans active BNPL plans. '
          'Each missed payment incurs RM10 admin fee + RM23 late fee. '
          'Multiple BNPL commitments can quickly spiral into unmanageable debt.',
      icon: Icons.credit_card_off,
      iconColor: GameColors.uiRed,
      buttonText: 'I\'ll be careful',
    );
  }

  /// Suggest buying insurance.
  static Future<void> suggestInsurance(BuildContext context, int uninsuredCrops) {
    if (uninsuredCrops < 3) return Future.value();

    return DialogPopup.show(
      context,
      title: '💡 Advisor Tip',
      message:
          'You have $uninsuredCrops uninsured crops. '
          'If a natural disaster hits, you could lose all your harvest! '
          'Consider buying Crop Insurance at the Bank to protect your income.',
      icon: Icons.shield,
      iconColor: GameColors.uiGold,
      buttonText: 'Good idea!',
    );
  }
}
