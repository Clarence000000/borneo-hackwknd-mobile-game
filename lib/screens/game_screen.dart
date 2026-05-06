import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!(state.player?.tutorialCompleted ?? true)) {
        _showTutorial(state);
      }

      // Auto-seed leaderboard once in background if needed
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
                  overlayBuilderMap: {
                    'ShadyLenderMenu': (context, game) {
                      return Center(
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            width: 360,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: GameColors.uiPanel.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: GameColors.uiGold.withValues(alpha: 0.6),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 24,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🦈 Shady Lender',
                                  style: TextStyle(
                                    color: GameColors.uiGold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Need quick cash? I can help...\nbut it\'ll cost you.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: GameColors.uiText,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: GameColors.uiGold,
                                    foregroundColor: GameColors.uiBackground,
                                  ),
                                  onPressed: () {
                                    _game.overlays.remove('ShadyLenderMenu');
                                  },
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  },
                ),
              ),

              // ── Layer 1: HUD Overlay ────────────────────────
              const HudOverlay(),

              // ── Layer 2: Loan Shark Threat Tint ─────────────
              if (state.loanSharkThreatActive)
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
              InteractionOverlay(game: _game),
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
