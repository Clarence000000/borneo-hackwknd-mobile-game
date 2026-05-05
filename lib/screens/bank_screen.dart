import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/cloud_functions_service.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';
import 'package:farm_fintech/widgets/financial_advisor.dart';
import 'package:farm_fintech/widgets/book_ui.dart';

/// In-game Bank screen — register, deposit/withdraw, loans, insurance, credit score.
class BankScreen extends StatefulWidget {
  const BankScreen({super.key});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  double _loanAmount = 500;
  double _loanMonths = 6;
  bool _refreshingCreditScore = false;
  Map<String, int> _creditBreakdown = const {
    'frequency': 0,
    'consistency': 50,
    'amount': 0,
    'onTimePayments': 100,
  };

  Future<void> _refreshCreditScore(GameState state, Player player) async {
    if (_refreshingCreditScore) return;

    setState(() => _refreshingCreditScore = true);
    final result = await CloudFunctionsService().calculateCreditScore();
    if (!mounted) return;

    final previousScore =
        (result['previousScore'] as num?)?.toInt() ?? player.creditScore;
    final newScore = (result['score'] as num?)?.toInt() ?? player.creditScore;
    final delta =
        (result['delta'] as num?)?.toInt() ?? (newScore - previousScore);
    final rawBreakdown = Map<String, dynamic>.from(
      (result['breakdown'] as Map?) ?? const {},
    );

    setState(() {
      _refreshingCreditScore = false;
      _creditBreakdown = {
        'frequency': (rawBreakdown['frequency'] as num?)?.toInt() ?? 0,
        'consistency': (rawBreakdown['consistency'] as num?)?.toInt() ?? 50,
        'amount': (rawBreakdown['amount'] as num?)?.toInt() ?? 0,
        'onTimePayments':
            (rawBreakdown['onTimePayments'] as num?)?.toInt() ?? 100,
      };
      state.player?.creditScore = newScore;
    });
    state.refresh();

    final deltaLabel = delta > 0 ? '+$delta' : '$delta';
    DialogPopup.show(
      context,
      title: 'Credit Score Refreshed',
      message:
          'Previous score: $previousScore\n'
          'New score: $newScore\n'
          'Change: $deltaLabel\n\n'
          '${_scoreChangeExplanation(delta)}',
      icon: delta >= 0 ? Icons.trending_up : Icons.trending_down,
      iconColor: delta >= 0 ? GameColors.uiGreen : GameColors.uiRed,
    );
  }

  String _scoreChangeExplanation(int delta) {
    if (delta > 0) {
      return 'Good progress. Regular bank activity and on-time payments are improving your profile.';
    }
    if (delta < 0) {
      return 'Your profile weakened. Add more consistent bank transactions and repay bills on time.';
    }
    return 'No change yet. Try more regular bank usage or repay insurance / loan costs through the bank.';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final player = state.player;
        if (player == null) return const SizedBox();

        final pages = [
          // ── Page 1: Credit Score & Breakdown ───────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CreditScoreCard(
                score: player.creditScore,
                refreshing: _refreshingCreditScore,
                onRefresh: () => _refreshCreditScore(state, player),
              ),
              const SizedBox(height: 12),
              _CreditImprovementCard(breakdown: _creditBreakdown),
            ],
          ),

          // ── Page 2: Balance & Registration ──────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!player.bankRegistered)
                _ActionCard(
                  icon: Icons.account_balance,
                  title: 'Register Bank Account',
                  subtitle:
                      'Open a digital bank account to unlock loans, insurance, and build your credit score.',
                  buttonText: 'Register (Free)',
                  buttonColor: GameColors.uiGreen,
                  onPressed: () {
                    player.bankRegistered = true;
                    player.bankBalance = 0;
                    state.refresh();
                    DialogPopup.show(
                      context,
                      title: '🎉 Bank Account Opened!',
                      message:
                          'You now have a digital bank account. Use it to:\n\n'
                          '• Make digital payments (builds credit score)\n'
                          '• Apply for loans\n'
                          '• Buy crop insurance\n\n'
                          'Deposit cash to get started!',
                      icon: Icons.check_circle,
                      iconColor: GameColors.uiGreen,
                    );
                  },
                )
              else ...[
                _BalanceCard(player: player),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        label: 'Deposit',
                        icon: Icons.arrow_downward,
                        color: GameColors.uiGreen,
                        onPressed: player.cashBalance >= 100
                            ? () {
                                player.pay(100, method: PaymentMethod.cash);
                                player.deposit(100, method: PaymentMethod.bank);
                                FirestoreService().logTransaction(
                                  player.uid,
                                  amount: 100,
                                  paymentType: 'bank',
                                  category: 'deposit',
                                );
                                state.refresh();
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickActionButton(
                        label: 'Withdraw',
                        icon: Icons.arrow_upward,
                        color: GameColors.uiHighlight,
                        onPressed: player.bankBalance >= 100
                            ? () {
                                player.pay(100, method: PaymentMethod.bank);
                                player.deposit(100, method: PaymentMethod.cash);
                                FirestoreService().logTransaction(
                                  player.uid,
                                  amount: 100,
                                  paymentType: 'bank',
                                  category: 'withdrawal',
                                );
                                state.refresh();
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '* Transactions are in units of ${CurrencyUtil.format(100, player.country)}',
                  style: GoogleFonts.almendra(
                    color: const Color(0xFF2D1B10).withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),

          // ── Page 3: Loan Planner ────────────────────────
          if (player.bankRegistered)
            _LoanPlannerCard(
              amount: _loanAmount,
              months: _loanMonths.toInt(),
              country: player.country,
              score: player.creditScore,
              onAmountChanged: (value) {
                setState(() => _loanAmount = value);
              },
              onMonthsChanged: (value) {
                setState(() => _loanMonths = value);
              },
              onApply: player.creditScore >= kMinLoanCreditScore
                  ? () async {
                      final selectedMonths = _loanMonths.toInt();
                      final monthlyPayment =
                          _loanAmount * (1 + kLoanInterestRate) / selectedMonths;

                      await FinancialAdvisor.warnLoan(
                        context,
                        player,
                        monthlyPayment,
                        300,
                      );
                      if (!context.mounted) return;

                      final result = await CloudFunctionsService()
                          .evaluateLoan(_loanAmount, selectedMonths);
                      if (!context.mounted) return;

                      if (result['approved'] == true) {
                        final updatedPlayer =
                            await FirestoreService().getPlayer(player.uid);
                        if (updatedPlayer != null) {
                          state.player = updatedPlayer;
                        }
                        state.refresh();

                        if (!context.mounted) return;
                        DialogPopup.show(
                          context,
                          title: '✅ Loan Approved!',
                          message: result['message'] ??
                              '${CurrencyUtil.format(_loanAmount, player.country)} deposited to your bank.',
                          icon: Icons.check_circle,
                          iconColor: GameColors.uiGreen,
                        );
                      } else {
                        DialogPopup.show(
                          context,
                          title: '❌ Loan Denied',
                          message: result['reason'] ??
                              'Your credit score is too low.',
                          icon: Icons.cancel,
                          iconColor: GameColors.uiRed,
                        );
                      }
                    }
                  : null,
            )
          else
            Center(
              child: Text(
                'Register to view loans',
                style: GoogleFonts.cinzel(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D1B10),
                ),
              ),
            ),

          // ── Page 4: Shady Lender & Insurance ───────────
          if (player.bankRegistered)
            Column(
              children: [
                _ActionCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Shady Lender',
                  subtitle:
                      'Instant cash, high limit, predatory terms. 35% monthly interest.',
                  buttonText:
                      'Take ${CurrencyUtil.format(1200, player.country)}',
                  buttonColor: GameColors.uiRed,
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('High-Risk Illegal Loan'),
                        content: const Text(
                          'This is NOT a regulated bank product. Defaults trigger threat effects.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Take Risk'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true || !context.mounted) return;

                    final ok = await state.takeLoanSharkLoan(1200);
                    if (!context.mounted) return;

                    DialogPopup.show(
                      context,
                      title: ok ? '⚠️ Cash Received' : 'Loan Failed',
                      message: ok
                          ? 'You got ${CurrencyUtil.format(1200, player.country)} immediately. Repay soon!'
                          : 'Unable to process.',
                      icon: ok ? Icons.dangerous : Icons.error_outline,
                      iconColor: ok ? GameColors.uiRed : GameColors.uiTextDim,
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.shield,
                  title: 'Crop Insurance',
                  subtitle: 'Premium: 5% of coverage value.',
                  buttonText:
                      'Buy (${CurrencyUtil.format(50, player.country)})',
                  buttonColor: GameColors.uiAccent,
                  onPressed:
                      (player.cashBalance >= 50 || player.bankBalance >= 50)
                          ? () {
                              var insuredCount = 0;
                              for (final row in state.grid) {
                                for (final tile in row) {
                                  if (tile.hasCrop && !tile.insured) {
                                    tile.insured = true;
                                    insuredCount++;
                                  }
                                }
                              }
                              if (insuredCount == 0) return;

                              if (player.bankBalance >= 50) {
                                player.pay(50, method: PaymentMethod.bank);
                              } else {
                                player.pay(50, method: PaymentMethod.cash);
                              }
                              state.recordInsuranceExpense(50);
                              state.refresh();
                              DialogPopup.show(
                                context,
                                title: '🛡️ Crops Insured!',
                                message: '$insuredCount crops protected.',
                                icon: Icons.shield,
                                iconColor: GameColors.uiGreen,
                              );
                            }
                          : null,
                ),
              ],
            )
          else
            const SizedBox(),
        ];

        return BookUI(
          title: '🏦 Royal Bank',
          pages: pages,
        );
      },
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────

class _CreditScoreCard extends StatelessWidget {
  final int score;
  final bool refreshing;
  final VoidCallback onRefresh;

  const _CreditScoreCard({
    required this.score,
    required this.refreshing,
    required this.onRefresh,
  });

  Color get _scoreColor {
    if (score >= 700) return Colors.green.shade900;
    if (score >= 550) return Colors.orange.shade900;
    return Colors.red.shade900;
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _scoreColor, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _scoreColor, width: 3),
              color: Colors.white.withOpacity(0.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '$score',
              style: GoogleFonts.cinzel(
                color: _scoreColor,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credit Score',
                  style: GoogleFonts.cinzel(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Status: ${score >= 700 ? 'Excellent' : score >= 550 ? 'Fair' : 'Poor'}',
                  style: GoogleFonts.almendra(
                    color: textColor.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: refreshing ? null : onRefresh,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _scoreColor,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(
                    refreshing ? 'Calculating...' : 'Refresh Score',
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditImprovementCard extends StatelessWidget {
  final Map<String, int> breakdown;

  const _CreditImprovementCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score Improvement',
            style: GoogleFonts.cinzel(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          _ScoreBreakdownBar(
              label: 'Payment Frequency', value: breakdown['frequency'] ?? 0),
          _ScoreBreakdownBar(
              label: 'Habit Consistency', value: breakdown['consistency'] ?? 0),
          _ScoreBreakdownBar(label: 'Transaction Volume', value: breakdown['amount'] ?? 0),
          _ScoreBreakdownBar(
              label: 'On-time Repayment', value: breakdown['onTimePayments'] ?? 100),
        ],
      ),
    );
  }
}

class _ScoreBreakdownBar extends StatelessWidget {
  final String label;
  final int value;

  const _ScoreBreakdownBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.almendra(
                      fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              Text('$value%',
                  style: GoogleFonts.almendra(
                      fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              backgroundColor: Colors.black12,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF5D4037)),
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
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.4), width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BalanceItem(
              label: 'CASH',
              value: player.cashBalance,
              color: Colors.orange.shade900,
              country: player.country),
          Container(width: 2, height: 60, color: const Color(0xFF5D4037).withOpacity(0.3)),
          _BalanceItem(
              label: 'BANK',
              value: player.bankBalance,
              color: Colors.green.shade900,
              country: player.country),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String country;

  const _BalanceItem(
      {required this.label,
      required this.value,
      required this.color,
      required this.country});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.almendra(
                fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        Text(CurrencyUtil.format(value, country),
            style: GoogleFonts.cinzel(
                fontSize: 24, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

class _LoanPlannerCard extends StatelessWidget {
  final double amount;
  final int months;
  final String country;
  final int score;
  final ValueChanged<double> onAmountChanged;
  final ValueChanged<double> onMonthsChanged;
  final VoidCallback? onApply;

  const _LoanPlannerCard({
    required this.amount,
    required this.months,
    required this.country,
    required this.score,
    required this.onAmountChanged,
    required this.onMonthsChanged,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    final totalRepayment = amount * (1 + kLoanInterestRate);
    final monthly = totalRepayment / months;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Land Loan Planner',
            style: GoogleFonts.cinzel(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: textColor)),
        const SizedBox(height: 16),
        Text('Principal: ${CurrencyUtil.format(amount, country)}',
            style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        Slider(
          value: amount,
          min: 300,
          max: 1500,
          divisions: 12,
          activeColor: const Color(0xFF5D4037),
          onChanged: onAmountChanged,
        ),
        Text('Term: $months Months', 
             style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        Slider(
          value: months.toDouble(),
          min: 3,
          max: 12,
          divisions: 9,
          activeColor: const Color(0xFF5D4037),
          onChanged: onMonthsChanged,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              _RowInfo(
                  label: 'Monthly Repayment',
                  value: CurrencyUtil.format(monthly, country),
                  bold: true),
              _RowInfo(
                  label: 'Total with Interest',
                  value: CurrencyUtil.format(totalRepayment, country)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D4037),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(onApply != null ? 'Apply for Loan' : 'Score Too Low',
                style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _RowInfo({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.almendra(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          Text(value,
              style: GoogleFonts.almendra(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.bold)),
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
    const textColor = Color(0xFF2D1B10);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: textColor),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle,
              style: GoogleFonts.almendra(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.9))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Text(buttonText,
                  style: GoogleFonts.cinzel(
                      fontSize: 16, fontWeight: FontWeight.w900)),
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
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w900)),
    );
  }
}

