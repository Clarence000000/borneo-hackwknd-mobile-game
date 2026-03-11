import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/cloud_functions_service.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';
import 'package:farm_fintech/widgets/financial_advisor.dart';

/// In-game Bank screen — register, deposit/withdraw, loans, insurance, credit score.
class BankScreen extends StatelessWidget {
  const BankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      appBar: AppBar(
        title: const Text('🏦 Bank'),
        backgroundColor: GameColors.bankRoof,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<GameState>(
        builder: (context, state, _) {
          final player = state.player;
          if (player == null) return const SizedBox();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Credit Score Card ──────────────────────
                _CreditScoreCard(score: player.creditScore),
                const SizedBox(height: 16),

                // ── Bank Registration ─────────────────────
                if (!player.bankRegistered)
                  _ActionCard(
                    icon: Icons.account_balance,
                    title: 'Register Bank Account',
                    subtitle: 'Open a digital bank account to unlock loans, insurance, and build your credit score.',
                    buttonText: 'Register (Free)',
                    buttonColor: GameColors.uiGreen,
                    onPressed: () {
                      player.bankRegistered = true;
                      player.bankBalance = 0;
                      state.refresh();
                      DialogPopup.show(context,
                        title: '🎉 Bank Account Opened!',
                        message: 'You now have a digital bank account. Use it to:\n\n'
                            '• Make digital payments (builds credit score)\n'
                            '• Apply for loans\n'
                            '• Buy crop insurance\n\n'
                            'Deposit cash to get started!',
                        icon: Icons.check_circle,
                        iconColor: GameColors.uiGreen,
                      );
                    },
                  ),

                // ── Deposit / Withdraw ────────────────────
                if (player.bankRegistered) ...[
                  _BalanceCard(player: player),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionButton(
                          label: 'Deposit ${CurrencyUtil.format(100, player.country)}',
                          icon: Icons.arrow_downward,
                          color: GameColors.uiGreen,
                          onPressed: player.cashBalance >= 100
                              ? () {
                                  player.pay(100, method: PaymentMethod.cash);
                                  player.deposit(100, method: PaymentMethod.bank);
                                  FirestoreService().logTransaction(player.uid, amount: 100, paymentType: 'bank', category: 'deposit');
                                  state.refresh();
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuickActionButton(
                          label: 'Withdraw ${CurrencyUtil.format(100, player.country)}',
                          icon: Icons.arrow_upward,
                          color: GameColors.uiHighlight,
                          onPressed: player.bankBalance >= 100
                              ? () {
                                  player.pay(100, method: PaymentMethod.bank);
                                  player.deposit(100, method: PaymentMethod.cash);
                                  FirestoreService().logTransaction(player.uid, amount: 100, paymentType: 'bank', category: 'withdrawal');
                                  state.refresh();
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Apply for Loan ────────────────────
                  _ActionCard(
                    icon: Icons.real_estate_agent,
                    title: 'Apply for Land Loan',
                    subtitle: 'Borrow ${CurrencyUtil.format(500, player.country)} to buy more farmland.\n'
                        'Interest: ${(kLoanInterestRate * 100).toStringAsFixed(0)}% monthly | '
                        'Min credit score: $kMinLoanCreditScore',
                    buttonText: player.creditScore >= kMinLoanCreditScore
                        ? 'Apply for ${CurrencyUtil.format(500, player.country)} Loan'
                        : 'Score too low (${player.creditScore}/$kMinLoanCreditScore)',
                    buttonColor: player.creditScore >= kMinLoanCreditScore
                        ? GameColors.uiGold
                        : GameColors.uiTextDim,
                    onPressed: player.creditScore >= kMinLoanCreditScore
                        ? () async {
                            await FinancialAdvisor.warnLoan(context, player, 500 * (1 + kLoanInterestRate) / 6, 300);
                            if (!context.mounted) return;

                            // Call Cloud Function to evaluate loan (this modifies Firestore if approved)
                            final result = await CloudFunctionsService().evaluateLoan(500.0, 6);
                            if (!context.mounted) return;
                            
                            if (result['approved'] == true) {
                                // Refresh player from Firestore to get updated balances
                                final updatedPlayer = await FirestoreService().getPlayer(player.uid);
                                if (updatedPlayer != null) {
                                  state.player = updatedPlayer;
                                }
                                state.refresh();

                                if (!context.mounted) return;
                                DialogPopup.show(context,
                                  title: '✅ Loan Approved!',
                                  message: result['message'] ?? '${CurrencyUtil.format(500, player.country)} deposited to your bank.',
                                  icon: Icons.check_circle,
                                  iconColor: GameColors.uiGreen,
                                );
                            } else {
                                DialogPopup.show(context,
                                  title: '❌ Loan Denied',
                                  message: result['reason'] ?? 'Your credit score is too low.',
                                  icon: Icons.cancel,
                                  iconColor: GameColors.uiRed,
                                );
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // ── Buy Insurance ─────────────────────
                  _ActionCard(
                    icon: Icons.shield,
                    title: 'Crop Insurance',
                    subtitle: 'Protect your crops against natural disasters.\n'
                        'Premium: ${(kInsurancePremiumRate * 100).toStringAsFixed(0)}% of coverage value.',
                    buttonText: 'Buy Insurance (${CurrencyUtil.format(50, player.country)})',
                    buttonColor: GameColors.uiAccent,
                    onPressed: (player.cashBalance >= 50 || player.bankBalance >= 50)
                        ? () {
                            // Insure all current crops
                            var insuredCount = 0;
                            for (final row in state.grid) {
                              for (final tile in row) {
                                if (tile.hasCrop && !tile.insured) {
                                  tile.insured = true;
                                  insuredCount++;
                                }
                              }
                            }

                            if (insuredCount == 0) {
                              DialogPopup.show(context,
                                title: 'No Crops to Insure',
                                message: 'Plant some crops first, then come back to insure them!',
                                icon: Icons.info_outline,
                              );
                              return;
                            }

                            // Deduct premium
                            if (player.bankBalance >= 50) {
                              player.pay(50, method: PaymentMethod.bank);
                              FirestoreService().logTransaction(player.uid, amount: 50, paymentType: 'bank', category: 'insurancePremium');
                            } else {
                              player.pay(50, method: PaymentMethod.cash);
                              FirestoreService().logTransaction(player.uid, amount: 50, paymentType: 'cash', category: 'insurancePremium');
                            }
                            state.refresh();

                            DialogPopup.show(context,
                              title: '🛡️ Crops Insured!',
                              message: '$insuredCount crops are now protected against disasters.\n\n'
                                  'If a natural disaster hits, you\'ll receive a payout '
                                  'instead of losing everything.',
                              icon: Icons.shield,
                              iconColor: GameColors.uiGreen,
                            );
                          }
                        : null,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────

class _CreditScoreCard extends StatelessWidget {
  final int score;
  const _CreditScoreCard({required this.score});

  Color get _scoreColor {
    if (score >= 700) return GameColors.uiGreen;
    if (score >= 550) return GameColors.uiGold;
    return GameColors.uiRed;
  }

  String get _scoreLabel {
    if (score >= 700) return 'Excellent';
    if (score >= 600) return 'Good';
    if (score >= 500) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [GameColors.uiPanel, _scoreColor.withValues(alpha: 0.15)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _scoreColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _scoreColor, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              '$score',
              style: TextStyle(
                color: _scoreColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Credit Score', style: TextStyle(color: GameColors.uiTextDim, fontSize: 12)),
                Text(_scoreLabel, style: TextStyle(color: _scoreColor, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Based on bank payment history', style: TextStyle(color: GameColors.uiTextDim, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Player player;
  const _BalanceCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.uiPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameColors.uiAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Icon(Icons.money, color: GameColors.uiGold, size: 28),
              const SizedBox(height: 4),
              Text('Cash', style: TextStyle(color: GameColors.uiTextDim, fontSize: 12)),
              Text(CurrencyUtil.format(player.cashBalance, player.country),
                  style: const TextStyle(color: GameColors.uiGold, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          Container(width: 1, height: 50, color: GameColors.uiAccent.withValues(alpha: 0.3)),
          Column(
            children: [
              const Icon(Icons.account_balance, color: GameColors.uiGreen, size: 28),
              const SizedBox(height: 4),
              Text('Bank', style: TextStyle(color: GameColors.uiTextDim, fontSize: 12)),
              Text(CurrencyUtil.format(player.bankBalance, player.country),
                  style: const TextStyle(color: GameColors.uiGreen, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback? onPressed;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.buttonColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.uiPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameColors.uiAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: GameColors.uiGold, size: 24),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: GameColors.uiText, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: GameColors.uiTextDim, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: onPressed != null ? buttonColor : GameColors.uiTextDim.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onPressed,
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : color.withValues(alpha: 0.3),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
