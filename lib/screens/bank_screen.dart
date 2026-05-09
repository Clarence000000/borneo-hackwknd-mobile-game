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
import 'package:farm_fintech/models/financial/loan.dart';
import 'package:farm_fintech/models/financial/fixed_deposit.dart';
import 'package:farm_fintech/models/financial/insurance.dart';
import 'dart:math';

/// In-game Bank screen — register, deposit/withdraw, loans, insurance, credit score.
class BankScreen extends StatefulWidget {
  const BankScreen({super.key});

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  double _loanAmount = 500;
  double _loanMonths = 6;
  double _depositAmount = 0;
  double _withdrawAmount = 0;
  double _fdAmount = 100;
  int _fdMonths = 1;
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
      textColor: const Color(0xFF2D1B10),
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

  Future<void> _confirmPurchase(BuildContext context, String name, double price, Future<bool> Function() onConfirm, bool isExtension) async {
    final action = isExtension ? 'Extend' : 'Purchase';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        title: Text('$action Policy', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
        content: Text(
          'Would you like to $action $name for 1 month (30 days)?\n\n'
          'Cost: ${CurrencyUtil.format(price, 'MY')}', 
          style: GoogleFonts.almendra(color: const Color(0xFF2D1B10)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.almendra(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Confirm', style: GoogleFonts.almendra(color: Colors.blue.shade900, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (result == true) {
      final success = await onConfirm();
      if (success && context.mounted) {
        DialogPopup.show(
          context,
          title: isExtension ? 'Policy Extended!' : 'Policy Purchased!',
          message: isExtension ? 'Your coverage has been extended by 30 days.' : 'You are now covered for 1 month.',
          icon: Icons.check_circle,
          iconColor: GameColors.uiGreen,
          textColor: const Color(0xFF2D1B10),
        );
      }
    }
  }

  Future<void> _confirmDrop(BuildContext context, String name, VoidCallback onConfirm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        title: Text('Drop Policy', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
        content: Text(
          'Are you sure you want to drop your $name insurance?\n\n'
          'IMPORTANT: No refund will be given.', 
          style: GoogleFonts.almendra(color: const Color(0xFF2D1B10)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep It', style: GoogleFonts.almendra(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Drop Policy', style: GoogleFonts.almendra(color: Colors.red.shade900, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (result == true) {
      onConfirm();
      if (context.mounted) {
        DialogPopup.show(
          context,
          title: 'Policy Dropped',
          message: 'Your coverage for $name has been cancelled.',
          icon: Icons.delete_forever,
          iconColor: Colors.red,
          textColor: const Color(0xFF2D1B10),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final player = state.player;
        if (player == null) return const SizedBox();
        final pages = <Widget>[];

        // ── Page 1: Credit Score & Breakdown ───────────
        pages.add(Column(
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
        ));

        // ── Page 2: Balance & Registration ──────────────
        pages.add(Column(
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
                    textColor: const Color(0xFF2D1B10),
                  );
                },
              )
            else ...[
              _BalanceCard(player: player),
              const SizedBox(height: 16),
              
              Text('Deposit to Savings', 
                  style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _depositAmount.clamp(0, max(0, (min(player.cashBalance, 5000) ~/ 100) * 100.0)),
                      min: 0,
                      max: max(0, (min(player.cashBalance, 5000) ~/ 100) * 100.0),
                      divisions: max(1, (min(player.cashBalance, 5000) ~/ 100)),
                      activeColor: GameColors.uiGreen,
                      onChanged: player.cashBalance >= 100 ? (v) => setState(() => _depositAmount = v.roundToDouble()) : null,
                    ),
                  ),
                  Text(CurrencyUtil.format(_depositAmount, player.country), 
                      style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
                ],
              ),
              _QuickActionButton(
                label: 'Deposit',
                icon: Icons.arrow_downward,
                color: GameColors.uiGreen,
                onPressed: player.cashBalance >= _depositAmount && _depositAmount > 0
                    ? () {
                        player.pay(_depositAmount, method: PaymentMethod.cash);
                        player.deposit(_depositAmount, method: PaymentMethod.bank);
                        FirestoreService().logTransaction(
                          player.uid,
                          amount: _depositAmount,
                          paymentType: 'bank',
                          category: 'deposit',
                        );
                        state.refresh();
                      }
                    : null,
              ),

              const SizedBox(height: 20),

              Text('Withdraw from Savings', 
                  style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _withdrawAmount.clamp(0, max(0, (min(player.bankBalance, 5000) ~/ 100) * 100.0)),
                      min: 0,
                      max: max(0, (min(player.bankBalance, 5000) ~/ 100) * 100.0),
                      divisions: max(1, (min(player.bankBalance, 5000) ~/ 100)),
                      activeColor: GameColors.uiHighlight,
                      onChanged: player.bankBalance >= 100 ? (v) => setState(() => _withdrawAmount = v.roundToDouble()) : null,
                    ),
                  ),
                  Text(CurrencyUtil.format(_withdrawAmount, player.country), 
                      style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
                ],
              ),
              _QuickActionButton(
                label: 'Withdraw',
                icon: Icons.arrow_upward,
                color: GameColors.uiHighlight,
                onPressed: player.bankBalance >= _withdrawAmount && _withdrawAmount > 0
                    ? () {
                        player.pay(_withdrawAmount, method: PaymentMethod.bank);
                        player.deposit(_withdrawAmount, method: PaymentMethod.cash);
                        FirestoreService().logTransaction(
                          player.uid,
                          amount: _withdrawAmount,
                          paymentType: 'bank',
                          category: 'withdrawal',
                        );
                        state.refresh();
                      }
                    : null,
              ),
              
              const SizedBox(height: 12),
              Text(
                '* Max 5,000 per transaction. Savings earn 1% daily interest.',
                style: GoogleFonts.almendra(
                  color: const Color(0xFF2D1B10).withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ));

        // ── Page 3: Fixed Deposits (Optional) ──────────────
        if (player.bankRegistered) {
          pages.add(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fixed Deposits',
                  style: GoogleFonts.cinzel(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2D1B10))),
              const SizedBox(height: 8),
              Text('High interest, but funds are locked until maturity.',
                  style: GoogleFonts.almendra(fontSize: 16, color: const Color(0xFF2D1B10).withOpacity(0.8))),
              const SizedBox(height: 16),
              
              Text('Amount to Lock (Min 100)', 
                  style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
              Slider(
                value: _fdAmount.clamp(100, max(100, ((player.cashBalance + player.bankBalance) ~/ 100) * 100.0)),
                min: 100,
                max: max(100, ((player.cashBalance + player.bankBalance) ~/ 100) * 100.0),
                divisions: max(1, (((player.cashBalance + player.bankBalance) ~/ 100) - 1)),
                activeColor: const Color(0xFF5D4037),
                onChanged: (player.cashBalance + player.bankBalance) >= 100 
                    ? (v) => setState(() => _fdAmount = v.roundToDouble()) 
                    : null,
              ),
              Center(child: Text(CurrencyUtil.format(_fdAmount, player.country), style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10)))),
              
              const SizedBox(height: 16),
              Text('Duration', 
                  style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _FDDurationChip(label: '1M (5%)', selected: _fdMonths == 1, onTap: () => setState(() => _fdMonths = 1)),
                  _FDDurationChip(label: '3M (10%)', selected: _fdMonths == 3, onTap: () => setState(() => _fdMonths = 3)),
                  _FDDurationChip(label: '6M (15%)', selected: _fdMonths == 6, onTap: () => setState(() => _fdMonths = 6)),
                ],
              ),
              
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (player.cashBalance >= _fdAmount || player.bankBalance >= _fdAmount)
                      ? () async {
                          final success = await state.createFixedDeposit(_fdAmount, _fdMonths);
                          if (success && mounted) {
                            DialogPopup.show(
                              context,
                              title: 'Fixed Deposit Created!',
                              message: 'Your funds are now working for you.',
                              icon: Icons.lock,
                              iconColor: GameColors.uiGreen,
                              textColor: const Color(0xFF2D1B10),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: const Color(0xFFF4E4BC),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Create Fixed Deposit', style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              if (player.fixedDeposits.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Active Deposits', style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
                const SizedBox(height: 8),
                ...player.fixedDeposits.map((fd) => _FixedDepositItem(fd: fd, currentDay: state.currentDay, country: player.country)),
              ]
            ],
          ));
        }

        // ── Page 4: Loan Planner (Always Shown) ───────────
        pages.add(Column(
          children: [
            _LoanPlannerCard(
              amount: _loanAmount,
              months: _loanMonths.toInt(),
              country: player.country,
              score: player.creditScore,
              onAmountChanged: (value) => setState(() => _loanAmount = value),
              onMonthsChanged: (value) => setState(() => _loanMonths = value),
              onApply: player.bankRegistered && player.creditScore >= kMinLoanCreditScore
                  ? () async {
                      final selectedMonths = _loanMonths.toInt();
                      final monthlyPayment = _loanAmount * (1 + kLoanInterestRate) / selectedMonths;
                      final proceed = await FinancialAdvisor.warnLoan(context, player, monthlyPayment, 300);
                      if (!proceed || !context.mounted) return;
                      final result = await CloudFunctionsService().evaluateLoan(_loanAmount, selectedMonths);
                      if (!context.mounted) return;
                      if (result['approved'] == true) {
                        final updatedPlayer = await FirestoreService().getPlayer(player.uid);
                        if (updatedPlayer != null) state.player = updatedPlayer;
                        state.refresh();
                        if (!context.mounted) return;
                        DialogPopup.show(
                          context,
                          title: '✅ Loan Approved!',
                          message: result['message'] ?? '${CurrencyUtil.format(_loanAmount, player.country)} deposited.',
                          icon: Icons.check_circle,
                          iconColor: GameColors.uiGreen,
                          textColor: const Color(0xFF2D1B10),
                        );
                      } else {
                        DialogPopup.show(
                          context,
                          title: '❌ Loan Denied',
                          message: result['reason'] ?? 'Credit score too low.',
                          icon: Icons.cancel,
                          iconColor: GameColors.uiRed,
                          textColor: const Color(0xFF2D1B10),
                        );
                      }
                    }
                  : null,
            ),
            if (!player.bankRegistered)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text('Register to apply for loans.', 
                    style: GoogleFonts.almendra(fontSize: 16, color: Colors.red.shade900, fontStyle: FontStyle.italic)),
              ),
            if (state.loans.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Active Loans', style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
              const SizedBox(height: 8),
              ...state.loans.where((l) => l.status == LoanStatus.active).map((l) => _ActiveLoanItem(loan: l, country: player.country)),
            ]
          ],
        ));

        // ── Page 5 & 6: Insurance (Optional) ──────────────
        if (player.bankRegistered) {
          pages.add(SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Insurance Shop',
                      style: GoogleFonts.cinzel(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2D1B10))),
                  const SizedBox(height: 8),
                  Text('Get repaid if disaster strikes. Policies last 30 days.',
                      style: GoogleFonts.almendra(fontSize: 16, color: const Color(0xFF2D1B10).withOpacity(0.8))),
                  const SizedBox(height: 16),
  
                  _InsuranceOptionRow(
                    title: 'Flood Insurance',
                    price: 100,
                    type: InsuranceType.flood,
                    onBuy: () => _confirmPurchase(context, 'Flood', 100, () => state.buyInsurance(InsuranceType.flood, 100), player.insurances.any((i) => i.type == InsuranceType.flood)),
                    country: player.country,
                    isExtension: player.insurances.any((i) => i.type == InsuranceType.flood),
                  ),
                  _InsuranceOptionRow(
                    title: 'Storm Insurance',
                    price: 75,
                    type: InsuranceType.storm,
                    onBuy: () => _confirmPurchase(context, 'Storm', 75, () => state.buyInsurance(InsuranceType.storm, 75), player.insurances.any((i) => i.type == InsuranceType.storm)),
                    country: player.country,
                    isExtension: player.insurances.any((i) => i.type == InsuranceType.storm),
                  ),
                  _InsuranceOptionRow(
                    title: 'Drought Insurance',
                    price: 50,
                    type: InsuranceType.drought,
                    onBuy: () => _confirmPurchase(context, 'Drought', 50, () => state.buyInsurance(InsuranceType.drought, 50), player.insurances.any((i) => i.type == InsuranceType.drought)),
                    country: player.country,
                    isExtension: player.insurances.any((i) => i.type == InsuranceType.drought),
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    icon: Icons.auto_awesome,
                    title: 'Comprehensive Bundle',
                    subtitle: '80% of total price.',
                    buttonText: 'Buy Bundle (${CurrencyUtil.format(180, player.country)})',
                    buttonColor: Colors.purple.shade700,
                    onPressed: (player.insurances.isEmpty && (player.cashBalance >= 180 || player.bankBalance >= 180))
                        ? () => _confirmPurchase(context, 'Bundle', 180, () => state.buyComprehensiveInsurance(180), false)
                        : null,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ));

          pages.add(SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Policies',
                      style: GoogleFonts.cinzel(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF2D1B10))),
                  const SizedBox(height: 8),
                  Text('Review your current disaster coverage.',
                      style: GoogleFonts.almendra(fontSize: 16, color: const Color(0xFF2D1B10).withOpacity(0.8))),
                  const SizedBox(height: 16),
                  
                  if (player.insurances.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text('No active policies.', style: GoogleFonts.almendra(fontSize: 18, color: const Color(0xFF2D1B10).withOpacity(0.5))),
                      ),
                    )
                  else
                    ...player.insurances.map((ins) => _InsuranceItem(ins: ins, currentDay: state.currentDay, country: player.country, onDrop: () => _confirmDrop(context, ins.type.name, () => state.cancelInsurance(ins.id)))),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ));
        }

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
                    foregroundColor: const Color(0xFFF4E4BC),
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
              foregroundColor: const Color(0xFFF4E4BC),
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: const Color(0xFF5D4037).withOpacity(0.3),
              disabledForegroundColor: const Color(0xFF2D1B10).withOpacity(0.6),
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
                  foregroundColor: const Color(0xFFF4E4BC),
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
        foregroundColor: const Color(0xFFF4E4BC),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w900)),
    );
  }
}

class _InsuranceOptionRow extends StatelessWidget {
  final String title;
  final double price;
  final InsuranceType type;
  final Future<void> Function() onBuy;
  final String country;
  final bool isExtension;

  const _InsuranceOptionRow({
    required this.title,
    required this.price,
    required this.type,
    required this.onBuy,
    required this.country,
    this.isExtension = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(_getIcon(type), color: const Color(0xFF2D1B10), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10)))),
          TextButton(
            onPressed: onBuy,
            child: Text(
              isExtension ? 'Extend (${CurrencyUtil.format(price, country)})' : CurrencyUtil.format(price, country), 
              style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(InsuranceType type) {
    switch (type) {
      case InsuranceType.flood: return Icons.water;
      case InsuranceType.storm: return Icons.cyclone;
      case InsuranceType.drought: return Icons.sunny;
    }
  }
}

class _InsuranceItem extends StatelessWidget {
  final Insurance ins;
  final int currentDay;
  final String country;
  final VoidCallback onDrop;

  const _InsuranceItem({required this.ins, required this.currentDay, required this.country, required this.onDrop});

  @override
  Widget build(BuildContext context) {
    final daysLeft = ins.expiryDay - currentDay;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade900.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ins.type.name.toUpperCase()} Coverage', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
                Text('Active Period: $daysLeft days remaining', 
                    style: GoogleFonts.almendra(fontSize: 12, color: const Color(0xFF2D1B10).withOpacity(0.8))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Colors.red),
            tooltip: 'Drop Policy',
            onPressed: onDrop,
          ),
        ],
      ),
    );
  }
}

class _FDDurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FDDurationChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF5D4037) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF5D4037)),
        ),
        child: Text(label, style: GoogleFonts.almendra(color: selected ? Colors.white : const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _FixedDepositItem extends StatelessWidget {
  final FixedDeposit fd;
  final int currentDay;
  final String country;

  const _FixedDepositItem({required this.fd, required this.currentDay, required this.country});

  @override
  Widget build(BuildContext context) {
    final daysLeft = fd.endDay - currentDay;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${fd.durationMonths}M Fixed Deposit', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(CurrencyUtil.format(fd.principal, country), style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Interest: ${(fd.interestRate * 100).round()}% | Maturity in $daysLeft day(s)', 
               style: GoogleFonts.almendra(fontSize: 14)),
        ],
      ),
    );
  }
}

class _ActiveLoanItem extends StatelessWidget {
  final Loan loan;
  final String country;

  const _ActiveLoanItem({required this.loan, required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GameColors.uiRed.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active Loan', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Due: ${CurrencyUtil.format(loan.remainingBalance, country)}', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: GameColors.uiRed)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Interest Rate: ${(loan.interestRate * 100).round()}% | Monthly Repay: ${CurrencyUtil.format(loan.monthlyPayment, country)}', 
               style: GoogleFonts.almendra(fontSize: 14)),
        ],
      ),
    );
  }
}

