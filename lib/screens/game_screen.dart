import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/components/building_component.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';
import 'package:farm_fintech/models/tile.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';
import 'package:farm_fintech/widgets/hud_overlay.dart';
import 'package:farm_fintech/widgets/interaction_overlay.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/services/seed_service.dart';
import 'package:farm_fintech/screens/bank_screen.dart';
import 'package:farm_fintech/screens/merchant_screen.dart';
import 'package:farm_fintech/widgets/lyra_dialog_box.dart';
import 'package:farm_fintech/services/gemini_service.dart';

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
  bool _lyraDangerous = false;
  int _lyraTrustScore = 75;
  String _lyraWarning = '';
  Timer? _lyraAnalysisTimer;
  final GeminiService _lyraGemini = GeminiService();
  String? _lastLyraKey;

  @override
  void initState() {
    super.initState();
    _gameFocusNode = FocusNode();
    final state = context.read<GameState>();
    _game = RichiFarmGame(gameState: state);
    state.game = _game; // Wire up so GameState can sync crop sprites

    // Navigate to Bank/Merchant when the player taps a building.
    _game.onBuildingTapped = (BuildingType type) {
      if (!mounted) return;
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        pageBuilder: (context, anim1, anim2) {
          switch (type) {
            case BuildingType.bank:
              return const BankScreen();
            case BuildingType.merchant:
              return const MerchantScreen();
          }
        },
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
      // Start periodic danger analysis (5s delay for state load)
      Future.delayed(const Duration(seconds: 5), _startLyraAnalysis);
    });
  }

  void _startLyraAnalysis() {
    if (!mounted) return;
    _runLyraAnalysis();
    _lyraAnalysisTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _runLyraAnalysis();
    });
  }

  Future<void> _runLyraAnalysis() async {
    final state = context.read<GameState>();
    final player = state.player;
    if (player == null) return;
    final key = '${player.cashBalance.toInt()}_${player.creditScore}_'
        '${state.bnplPlans.length}_${state.loans.length}_${state.activeDisaster}';
    if (key == _lastLyraKey) return;
    _lastLyraKey = key;
    final result = await _lyraGemini.analyzeFinancialDanger(
      player: player,
      activeBnplCount: state.bnplPlans.length,
      activeLoanCount: state.loans.length,
      currentDay: state.currentDay,
      activeDisaster: state.activeDisaster.toString(),
    );
    if (!mounted) return;
    setState(() {
      _lyraDangerous = result.isDangerous;
      _lyraTrustScore = result.trustScore;
      _lyraWarning = result.warningMessage;
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
    _lyraAnalysisTimer?.cancel();
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
          return Stack(
            children: [
              // ── Layer 0: Flame Game (Tiled map + camera) ────
              GestureDetector(
                onTapUp: (details) {
                  _game.handleTap(details.localPosition);
                },
                child: GameWidget(
                  game: _game,
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

              // ── Layer 5: Lyra danger badge (bottom-left corner) ──
              if (_lyraDangerous == true && _lyraDialogOpen == false)
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: _LyraDangerBadge(
                    onTap: () => setState(() => _lyraDialogOpen = true),
                  ),
                ),

              // ── Layer 6: Lyra VN dialog box ───────────────────
              if (_lyraDialogOpen == true)
                LyraDialogBox(
                  initialTrustScore: _lyraTrustScore,
                  initialWarning: _lyraWarning,
                  isDangerous: _lyraDangerous,
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

      DialogPopup.show(
        context,
        title: 'Monthly P&L Report',
        message:
            'Y${report.year} M${report.month}\n\n'
            'Income: ${CurrencyUtil.format(report.income, country)}\n'
            'Expenses: ${CurrencyUtil.format(report.totalExpense, country)}\n'
            'Net: ${CurrencyUtil.format(report.netProfit, country)}\n\n'
            'Seed Cost: ${CurrencyUtil.format(seed, country)}\n'
            'Interest & Fees: ${CurrencyUtil.format(interest, country)}\n\n'
            'Top expense this month: ${report.topExpenseLabel}',
        icon: Icons.assessment,
        iconColor: GameColors.uiGold,
        buttonText: 'Continue',
      ).then((_) {
        if (!mounted) return;
        state.acknowledgeMonthlyReport();
        _showingMonthlyReport = false;
      });
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

/// Pulsing danger badge shown at bottom-left when Lyra detects financial peril.
/// Hints the player to go tap Lyra on the map and speak with her.
class _LyraDangerBadge extends StatefulWidget {
  final VoidCallback onTap;
  const _LyraDangerBadge({required this.onTap});

  @override
  State<_LyraDangerBadge> createState() => _LyraDangerBadgeState();
}

class _LyraDangerBadgeState extends State<_LyraDangerBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Transform.scale(
          scale: _pulse.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A0D2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF3D00), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3D00).withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'Lyra warns you!',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFFF6B35),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
