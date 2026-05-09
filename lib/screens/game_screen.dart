import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/components/interactive_building_component.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';
import 'package:farm_fintech/models/tile.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';
import 'package:farm_fintech/widgets/hud_overlay.dart';
import 'package:farm_fintech/widgets/interaction_overlay.dart';
import 'package:farm_fintech/widgets/oracle_chat_dialog.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/services/seed_service.dart';
import 'package:farm_fintech/screens/bank_screen.dart';
import 'package:farm_fintech/screens/house_screen.dart';
import 'package:farm_fintech/screens/forest_screen.dart';
import 'package:farm_fintech/screens/merchant_screen.dart';
import 'package:farm_fintech/widgets/shady_dialogue_panel.dart';
import 'package:farm_fintech/widgets/lyra_dialog_box.dart';


/// Main game screen — landscape farm view powered by Flame engine.
///
/// Layered rendering:
///   Flame GameWidget (Tiled map + camera) → Flutter overlays (HUD, action bar)
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late RichiFarmGame _game;
  bool _showingMonthlyReport = false;
  bool _wasLoanSharkThreatActive = false;
  Timer? _threatHapticTimer;

  // ── Lyra Oracle dialog state ─────────────────────────────────
  bool _lyraDialogOpen = false;
  String _lyraMode = 'chat'; // 'chat' or 'quest'
  late final FocusNode _gameFocusNode;

  @override
  void initState() {
    super.initState();
    _gameFocusNode = FocusNode();
    final state = context.read<GameState>();
    _game = RichiFarmGame(gameState: state);
    state.game = _game; // Wire up so GameState can sync crop sprites

    bool isBuildingDialogOpen = false;

    // Navigate to the appropriate screen when the player taps a building.
    _game.onBuildingTapped = (String type) {
      if (!mounted || isBuildingDialogOpen) return;
      isBuildingDialogOpen = true;

      Future<void> showBuildingDialog(Widget screen) async {
        await showGeneralDialog(
          context: context,
          barrierDismissible: false, // BookUI has its own X button — avoid double-pop
          barrierLabel: '',
          barrierColor: Colors.transparent, // BookUI provides its own dark overlay
          pageBuilder: (dialogCtx, anim1, anim2) => screen,
        );
        isBuildingDialogOpen = false;
      }

      switch (type) {
        case 'house':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HouseScreen()),
          ).then((_) => isBuildingDialogOpen = false);
          break;
        case 'bank':
          showBuildingDialog(const BankScreen());
          break;
        case 'merchant':
          showBuildingDialog(const MerchantScreen());
          break;
      }
    };


    _game.onForestEntry = () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ForestScreen()),
      );
    };

    // Lyra: show dialog when tapped on the map
    _game.onLyraTapped = () {
      if (!mounted || _lyraDialogOpen) return;
      setState(() {
        _lyraDialogOpen = true;
        _lyraMode = 'chat';
      });
    };

    _game.onLyraQuestTapped = () {
      if (!mounted || _lyraDialogOpen) return;
      setState(() {
        _lyraDialogOpen = true;
        _lyraMode = 'quest';
      });
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!(state.player?.tutorialCompleted ?? true)) {
        _showTutorial(state);
      }
      SeedService.seedLeaderboard();
    });
  }




  void _showTutorial(GameState state) {
    DialogPopup.show(
      context,
      title: '🌾 Welcome to Richi Farm!',
      message:
          'Welcome, farmer! Here\'s how to play:\n\n'
          '1. TAP a brown farmland tile to plant crops\n'
          '2. TAP "Next Day" ☀️ to advance time and grow crops\n'
          '3. HARVEST mature crops to store in inventory\n'
          '4. Visit the BANK for loans and insurance\n'
          '5. Use the MERCHANT market to sell crops and buy equipment\n\n'
          'Watch out for real-world weather disasters!',
      icon: Icons.agriculture,
      buttonText: 'Let\'s Farm! 🚜',
    ).then((_) {
      if (!mounted) return;
      state.player?.tutorialCompleted = true;
      if (state.player != null) {
        FirestoreService().savePlayer(state.player!);
      }
    });
  }

  @override
  void dispose() {
    _threatHapticTimer?.cancel();
    _gameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      body: Consumer<GameState>(
        builder: (context, state, _) {
          if (state.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: GameColors.uiGold),
                  SizedBox(height: 24),
                  Text(
                    'Loading Farm Data...',
                    style: TextStyle(
                      color: GameColors.uiText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            );
          }

          _scheduleMonthlyReportDialog(state);
          _handleLoanSharkThreatEffects(state);
          _scheduleRentCollectionDialog(state);
          _scheduleGameOverDialog(state);
          return Stack(
            children: [
              // ── Layer 0: Flame Game (Tiled map + camera) ────
              GestureDetector(
                onTapUp: (details) {
                  _game.handleTap(details.localPosition);
                },
                child: GameWidget(
                  game: _game,
                  overlayBuilderMap: {
                    'ShadyLenderMenu': (context, game) {
                      final state = context.read<GameState>();
                      final player = state.player;
                      final country = player?.country ?? 'MY';
                      final debt = state.sharkDebt;
                      final hasDebt = debt > 0;

                      return Center(
                        child: Material(
                          color: Colors.black54,
                          child: Center(
                            child: Container(
                              width: 380,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFCC0000).withValues(alpha: 0.7),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: hasDebt
                                  // ── REPAYMENT MODE ──
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🦈 Underground Lending',
                                          style: TextStyle(
                                            color: Color(0xFFFF4444),
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              const Text(
                                                'Current Balance Owed',
                                                style: TextStyle(
                                                  color: Color(0xFFAAAAAA),
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                CurrencyUtil.format(debt, country),
                                                style: const TextStyle(
                                                  color: Color(0xFFFF4444),
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                          ),
                                          child: const Text(
                                            '⚠️ Pay up before things get ugly...',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFFFF6666),
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        // Repay Full Amount
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF228B22),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              disabledBackgroundColor: const Color(0xFF333333),
                                              disabledForegroundColor: const Color(0xFF666666),
                                            ),
                                            onPressed: (player != null && (player.cashBalance + player.bankBalance) >= debt)
                                                ? () async {
                                                    _game.overlays.remove('ShadyLenderMenu');
                                                    final repaid = await state.repaySharkLoan(debt);
                                                    if (!context.mounted) return;
                                                    DialogPopup.show(
                                                      context,
                                                      title: '✅ Debt Cleared!',
                                                      message: 'You repaid ${CurrencyUtil.format(repaid, country)}. You are free... for now.',
                                                      icon: Icons.check_circle,
                                                      iconColor: GameColors.uiGreen,
                                                    );
                                                  }
                                                : null,
                                            child: Text(
                                              'Repay Full Amount (${CurrencyUtil.format(debt, country)})',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Repay Partial
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: GameColors.uiGold,
                                              side: BorderSide(color: GameColors.uiGold.withValues(alpha: 0.5)),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                            onPressed: (player != null && (player.cashBalance + player.bankBalance) >= 500 && debt >= 500)
                                                ? () async {
                                                    _game.overlays.remove('ShadyLenderMenu');
                                                    final repaid = await state.repaySharkLoan(500);
                                                    if (!context.mounted) return;
                                                    DialogPopup.show(
                                                      context,
                                                      title: '💰 Partial Repayment',
                                                      message: 'You repaid ${CurrencyUtil.format(repaid, country)}. Remaining: ${CurrencyUtil.format(state.sharkDebt, country)}',
                                                      icon: Icons.payments,
                                                      iconColor: GameColors.uiGold,
                                                    );
                                                  }
                                                : null,
                                            child: Text(
                                              'Repay Partial (${CurrencyUtil.format(500, country)})',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Leave
                                        SizedBox(
                                          width: double.infinity,
                                          child: TextButton(
                                            onPressed: () {
                                              _game.overlays.remove('ShadyLenderMenu');
                                            },
                                            child: const Text(
                                              'Leave',
                                              style: TextStyle(color: Color(0xFFAAAAAA)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  // ── BORROW MODE ──
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '🦈 Underground Lending',
                                          style: TextStyle(
                                            color: Color(0xFFFF4444),
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                'Instant cash: ${CurrencyUtil.format(1200, country)}',
                                                style: const TextStyle(
                                                  color: GameColors.uiGold,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Interest: 35% / month\nRepay in 3 months or face consequences',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Color(0xFFAAAAAA),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                          ),
                                          child: const Text(
                                            '⚠️ By signing this contract, you gain instant liquidity, but do not forget the hidden costs...',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFFFF6666),
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFFAAAAAA),
                                                  side: const BorderSide(color: Color(0xFF555555)),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                                onPressed: () {
                                                  _game.overlays.remove('ShadyLenderMenu');
                                                },
                                                child: const Text('Leave'),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFCC0000),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                                onPressed: () async {
                                                  _game.overlays.remove('ShadyLenderMenu');

                                                  final ok = await state.takeLoanSharkLoan(1200);
                                                  if (!context.mounted) return;

                                                  DialogPopup.show(
                                                    context,
                                                    title: ok ? '⚠️ Cash Received' : 'Loan Failed',
                                                    message: ok
                                                        ? 'You got ${CurrencyUtil.format(1200, country)} in cash. Repay soon — or else!'
                                                        : 'Unable to process the loan.',
                                                    icon: ok ? Icons.dangerous : Icons.error_outline,
                                                    iconColor: ok ? GameColors.uiRed : GameColors.uiTextDim,
                                                  );
                                                },
                                                child: Text(
                                                  'Accept ${CurrencyUtil.format(1200, country)} (35%/mo)',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      );
                    },
                  },
                  focusNode: _gameFocusNode,
                ),
              ),

              // ── Layer 1: HUD Overlay ────────────────────────
              const HudOverlay(),

              // ── Layer 2: Loan Shark Threat Tint ─────────────
              if (state.loanSharkThreatActive == true)
                IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.10, end: 0.18),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, _) {
                      return Container(
                        color: GameColors.uiRed.withValues(alpha: value),
                      );
                    },
                  ),
                ),

              // ── Layer 3: Tile Action Bar (bottom sheet) ─────
              if (state.selectedTile != null) _buildTileActionBar(state),

              // ── Layer 4: Interaction Overlay ────────────────
              if (!_lyraDialogOpen) InteractionOverlay(game: _game),

              // ── Layer 5: Shady Lender Dialogue ─────
              if (state.showShadyDialogue)
                ShadyDialoguePanel(game: _game),

              // ── Layer 6: Lyra VN dialog box ───────────────────
              if (_lyraDialogOpen == true)
                LyraDialogBox(
                  initialTrustScore: 75,
                  initialWarning: '',
                  isDangerous: false,
                  initialMode: _lyraMode,
                  onClose: () {
                    setState(() => _lyraDialogOpen = false);
                    _gameFocusNode.requestFocus();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  void _handleLoanSharkThreatEffects(GameState state) {
    final active = state.loanSharkThreatActive;
    if (active && !_wasLoanSharkThreatActive) {
      HapticFeedback.heavyImpact();
      _threatHapticTimer?.cancel();
      _threatHapticTimer = Timer.periodic(const Duration(milliseconds: 900), (
        timer,
      ) {
        if (!mounted || !state.loanSharkThreatActive) {
          timer.cancel();
          return;
        }
        HapticFeedback.mediumImpact();
      });
    }

    if (!active && _wasLoanSharkThreatActive) {
      _threatHapticTimer?.cancel();
      _threatHapticTimer = null;
    }
    _wasLoanSharkThreatActive = active;
  }

  void _scheduleMonthlyReportDialog(GameState state) {
    final report = state.pendingMonthlyReport;
    if (_showingMonthlyReport || report == null || !mounted) return;

    _showingMonthlyReport = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _showingMonthlyReport = false;
        return;
      }

      final country = state.player?.country ?? 'MY';
      final seed = report.expenses['seed'] ?? 0;
      final interest = report.expenses['interest'] ?? 0;

      final reportText = 'Y${report.year} M${report.month}\n\n'
          'Income: ${CurrencyUtil.format(report.income, country)}\n'
          'Expenses: ${CurrencyUtil.format(report.totalExpense, country)}\n'
          'Net: ${CurrencyUtil.format(report.netProfit, country)}\n\n'
          'Seed Cost: ${CurrencyUtil.format(seed, country)}\n'
          'Interest & Fees: ${CurrencyUtil.format(interest, country)}\n\n'
          'Top expense this month: ${report.topExpenseLabel}';

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (_) => OracleChatDialog(
          initialTrustScore: (state.player?.creditScore ?? 300) ~/ 8.5,
          initialWarning: reportText,
          isDangerous: false,
          isReportMode: true,
        ),
      ).then((_) {
        if (!mounted) return;
        _showingMonthlyReport = false;
        state.acknowledgeMonthlyReport();
      });
    });
  }

  bool _showingRentDialog = false;
  bool _showingGameOver = false;

  void _scheduleRentCollectionDialog(GameState state) {
    if (_showingRentDialog || !state.pendingRentCollection || !mounted) return;
    if (_showingMonthlyReport) return; // Wait for monthly report to close first

    _showingRentDialog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _showingRentDialog = false;
        return;
      }

      final country = state.player?.country ?? 'MY';
      final rent = state.currentRentAmount;
      final overdue = state.totalOverdueBnplDebt;
      final totalDue = rent + overdue;
      final totalBalance = (state.player?.cashBalance ?? 0) + (state.player?.bankBalance ?? 0);
      final canPay = totalBalance >= totalDue;
      final paymentNumber = (state.player?.rentPaymentCount ?? 0) + 1;

      // Build overdue BNPL breakdown
      final overduePlans = state.bnplPlans.where((p) =>
          p.nextDueDay != null && p.nextDueDay! <= state.currentDay).toList();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A0A0A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.red.shade900,
                width: 3,
              ),
            ),
            title: Row(
              children: [
                Image.asset(
                  'assets/images/shady_lender.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.red.shade400, size: 48),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🦈 RENT COLLECTION',
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFFF4444),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Payment #$paymentNumber',
                        style: GoogleFonts.almendra(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shady lender dialogue
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      paymentNumber <= 1
                          ? '"Time to pay up, farmer. This land ain\'t free. You\'ve been here 3 months — rent is due."'
                          : '"Back again... Rent goes up every time, you know that. Pay up or get out."',
                      style: GoogleFonts.almendra(
                        color: const Color(0xFFFF6666),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Room Rental
                  _rentLineItem('🏠 Room Rental', rent, country),

                  // Overdue BNPL debts
                  if (overduePlans.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '⚠️ OUTSTANDING DEBTS',
                      style: GoogleFonts.cinzel(
                        color: Colors.orange.shade400,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...overduePlans.map((plan) => _rentLineItem(
                      '📦 ${plan.itemName}',
                      plan.monthlyAmount + plan.lateFees,
                      country,
                    )),
                  ],

                  const Divider(color: Colors.red, height: 32),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL DUE',
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        CurrencyUtil.format(totalDue, country),
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFFF4444),
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Balance info
                  Text(
                    'Your balance: ${CurrencyUtil.format(totalBalance, country)}',
                    style: GoogleFonts.almendra(
                      color: canPay ? Colors.green.shade400 : Colors.red.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (!canPay) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade700, width: 2),
                      ),
                      child: Text(
                        '💀 YOU CANNOT AFFORD THIS.\nYour farm will be seized.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          color: Colors.red.shade300,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canPay) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF228B22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          _showingRentDialog = false;
                          final success = await state.payRent();
                          if (success && mounted) {
                            DialogPopup.show(
                              context,
                              title: '✅ Rent Paid',
                              message: 'You paid ${CurrencyUtil.format(totalDue, country)}. Next rent in 3 months — it will cost more.',
                              icon: Icons.check_circle,
                              iconColor: Colors.green,
                            );
                          }
                        },
                        child: Text(
                          'PAY ${CurrencyUtil.format(totalDue, country)}',
                          style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showingRentDialog = false;
                        state.isGameOver = true;
                        state.pendingRentCollection = false;
                        state.refresh();
                      },
                      child: Text(
                        '💀 GIVE UP',
                        style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _rentLineItem(String label, double amount, String country) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.almendra(color: Colors.grey.shade300, fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            CurrencyUtil.format(amount, country),
            style: GoogleFonts.cinzel(color: const Color(0xFFFF8888), fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _scheduleGameOverDialog(GameState state) {
    if (_showingGameOver || !state.isGameOver || !mounted) return;

    _showingGameOver = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _showingGameOver = false;
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0A0000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF8B0000), width: 4),
            ),
            title: Text(
              '💀 GAME OVER',
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w900,
                fontSize: 28,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dangerous, color: Colors.red.shade700, size: 80),
                const SizedBox(height: 16),
                Text(
                  'The Shady Lender has seized your farm.\nYou couldn\'t pay your debts.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.almendra(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '"Should have managed your money better, farmer..."',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.almendra(
                    color: Colors.red.shade300,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showingGameOver = false;
                    state.isGameOver = false;
                    state.devResetGame();
                  },
                  child: Text(
                    'START OVER',
                    style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Bottom action bar for the selected tile.
  /// Compact horizontal layout for landscape.
  Widget _buildTileActionBar(GameState state) {
    final (col, row) = state.selectedTile!;
    final tile = state.grid[row][col];

    return Positioned(
      bottom: 8,
      left: MediaQuery.of(context).size.width * 0.15,
      right: MediaQuery.of(context).size.width * 0.15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: GameColors.uiPanel.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border.all(color: GameColors.uiAccent.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            // Tile info
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tile.type.name.toUpperCase()} ($col, $row)',
                  style: const TextStyle(
                    color: GameColors.uiText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (tile.hasCrop && !tile.isHarvestable)
                  Text(
                    '${tile.crop!.name.toUpperCase()} — Stage ${tile.growthStage}/3',
                    style: const TextStyle(
                      color: GameColors.uiGold,
                      fontSize: 12,
                    ),
                  ),
                if (tile.type == TileType.grass)
                  const Text(
                    'Buy land at Bank to farm here',
                    style: TextStyle(color: GameColors.uiTextDim, fontSize: 11),
                  ),
              ],
            ),
            const Spacer(),
            // Action buttons (horizontal)
            if (tile.isFarmland && !tile.hasCrop) ..._buildPlantChips(state),
            if (tile.isHarvestable) _buildHarvestChip(state),
            // Close button
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.close,
                color: GameColors.uiTextDim,
                size: 18,
              ),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () {
                state.selectedTile = null;
                state.refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlantChips(GameState state) {
    return CropType.values.map((crop) {
      final config = kCropConfig[crop]!;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ActionChip(
          avatar: const Icon(Icons.grass, size: 14, color: GameColors.uiGreen),
          label: Text(
            '${config['name']} ${CurrencyUtil.format(config['seedCost'] as double, state.player?.country ?? 'MY')}',
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: GameColors.uiAccent,
          labelStyle: const TextStyle(color: GameColors.uiText),
          side: BorderSide.none,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () async {
            final success = await state.plantCrop(crop);
            if (!mounted) return;
            if (!success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not enough money!')),
              );
            }
          },
        ),
      );
    }).toList();
  }

  Widget _buildHarvestChip(GameState state) {
    return ActionChip(
      avatar: const Icon(
        Icons.agriculture,
        size: 14,
        color: GameColors.uiBackground,
      ),
      label: const Text(
        'HARVEST',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
      backgroundColor: GameColors.uiGold,
      labelStyle: const TextStyle(color: GameColors.uiBackground),
      side: BorderSide.none,
      onPressed: () async {
        final harvested = await state.harvestCrop();
        if (harvested == null || !mounted) return;

        final config = kCropConfig[harvested]!;
        final cropName = config['name'] as String;
        final sellPrice = config['sellPrice'] as double;

        final action = await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text('$cropName Harvested'),
              content: Text(
                'Store it in inventory or sell it now for ${CurrencyUtil.format(sellPrice, state.player?.country ?? 'MY')}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('store'),
                  child: const Text('Store'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop('sell'),
                  child: const Text('Sell Now'),
                ),
              ],
            );
          },
        );

        if (!mounted) return;

        if (action == 'sell') {
          final revenue = await state.sellInventoryCrop(
            harvested.name,
            quantity: 1,
          );
          if (!mounted || revenue == null) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sold $cropName for ${CurrencyUtil.format(revenue, state.player?.country ?? 'MY')}.',
              ),
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stored $cropName in inventory.')),
        );
      },
    );
  }
}

