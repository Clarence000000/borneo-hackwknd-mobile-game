import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/models/weather_event.dart';
import 'package:farm_fintech/engine/crop_image_registry.dart';
import 'package:farm_fintech/screens/bank_screen.dart';
import 'package:farm_fintech/screens/profile_screen.dart';
import 'package:farm_fintech/screens/merchant_screen.dart';
import 'package:farm_fintech/screens/leaderboard_screen.dart';
import 'package:farm_fintech/utils/currency_util.dart';

/// Country flag emoji lookup
const _countryFlags = {
  'MY': '🇲🇾',
  'ID': '🇮🇩',
  'SG': '🇸🇬',
  'TH': '🇹🇭',
  'PH': '🇵🇭',
  'VN': '🇻🇳',
};

// Approximate USD conversion rates for display-only switching in HUD.
const _currencyToUsdRate = {
  'MY': 0.21,
  'ID': 0.000064,
  'SG': 0.74,
  'TH': 0.028,
  'PH': 0.018,
  'VN': 0.000040,
};

const _aseanCountries = ['MY', 'ID', 'SG', 'TH', 'PH', 'VN'];

/// In-game HUD — landscape optimized.
///
/// Layout:
/// ┌─────────────────────────────────────────────────────┐
/// │ [Profile] [Cash] [Bank] [Score]     [Day] [Weather] │
/// │                                                     │
/// │                                        [NextDay]    │
/// │                                        [Bank]       │
/// │                                        [Shop]       │
/// └─────────────────────────────────────────────────────┘
class HudOverlay extends StatefulWidget {
  const HudOverlay({super.key});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  String? _displayCountry;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final player = state.player;
        if (player == null) return const SizedBox();

        _displayCountry ??= player.country;
        final displayCountry = _displayCountry ?? player.country;
        final displayCash = _convertCurrency(
          player.cashBalance,
          fromCountry: player.country,
          toCountry: displayCountry,
        );
        final displayBank = _convertCurrency(
          player.bankBalance,
          fromCountry: player.country,
          toCountry: displayCountry,
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // ── Top Bar (full width, landscape) ────────────
                SizedBox(
                  height: 36,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Player profile chip
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                          child: _HudChip(
                            children: [
                              Text(
                                _countryFlags[player.country] ?? '🌏',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                player.displayName,
                                style: const TextStyle(
                                  color: GameColors.uiText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Cash badge
                        _HudBadge(
                          icon: Icons.monetization_on,
                          label: CurrencyUtil.format(
                            displayCash,
                            displayCountry,
                          ),
                          color: GameColors.uiGold,
                        ),
                        const SizedBox(width: 6),

                        // Bank badge (if registered)
                        if (player.bankRegistered) ...[
                          _HudBadge(
                            icon: Icons.account_balance,
                            label: CurrencyUtil.format(
                              displayBank,
                              displayCountry,
                            ),
                            color: GameColors.uiGreen,
                          ),
                          const SizedBox(width: 6),
                        ],

                        GestureDetector(
                          onTap: () {
                            final currentIndex = _aseanCountries.indexOf(
                              displayCountry,
                            );
                            final nextIndex =
                                (currentIndex + 1) % _aseanCountries.length;
                            setState(() {
                              _displayCountry = _aseanCountries[nextIndex];
                            });
                          },
                          child: _HudChip(
                            children: [
                              Text(
                                _countryFlags[displayCountry] ?? '🌏',
                                style: const TextStyle(fontSize: 15),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                displayCountry,
                                style: const TextStyle(
                                  color: GameColors.uiText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Credit score badge
                        _CreditScoreBadge(score: player.creditScore),
                        const SizedBox(width: 6),

                        _HudBadge(
                          icon: Icons.inventory_2,
                          label: '${player.totalInventoryItems}',
                          color: GameColors.uiAccent,
                        ),
                        const SizedBox(width: 6),

                        _HudBadge(
                          icon: Icons.science,
                          label: 'Fert ${state.fertilizerPackCount}',
                          color: state.fertilizerPackCount > 0
                              ? GameColors.uiHighlight
                              : GameColors.uiTextDim,
                        ),
                        const SizedBox(width: 6),

                        _HudBadge(
                          icon: Icons.agriculture,
                          label: state.tractorOwned
                              ? (state.autoHarvestEnabled
                                    ? 'Tractor Active'
                                    : 'Tractor Paused')
                              : 'No Tractor',
                          color: state.tractorOwned
                              ? (state.autoHarvestEnabled
                                    ? GameColors.uiGreen
                                    : GameColors.uiGold)
                              : GameColors.uiTextDim,
                        ),

                        const SizedBox(width: 12),

                        // Weather indicator
                        _HudBadge(
                          icon: _weatherIcon(state.activeDisaster),
                          label: _weatherLabel(state.activeDisaster),
                          color: _weatherColor(state.activeDisaster),
                        ),
                        const SizedBox(width: 6),

                        _HudBadge(
                          icon: state.isDaytime
                              ? Icons.wb_sunny
                              : Icons.nightlight_round,
                          label:
                              '${state.dayPhaseLabel} ${_formatCountdown(state.remainingCycleSeconds)}',
                          color: state.isDaytime
                              ? GameColors.uiGold
                              : GameColors.uiAccent,
                        ),
                        const SizedBox(width: 6),

                        // Day counter
                        _HudBadge(
                          icon: Icons.wb_sunny,
                          label: state.gameDateLabel,
                          color: GameColors.uiHighlight,
                        ),
                        const SizedBox(width: 8),
                        // Debug: crop image load indicators
                        _HudChip(
                          children: [
                            const Text('W:'),
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < 4; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color:
                                            CropImageRegistry.getLoadedStages(
                                              CropType.wheat,
                                            )[i]
                                            ? GameColors.uiGreen
                                            : GameColors.uiTextDim,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ── Right-side action buttons (vertical column) ─
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HudChip(
                            children: [
                              Text(
                                'Free ${state.freeNextDayRemaining}/$kFreeManualNextDayPerRealDay',
                                style: const TextStyle(
                                  color: GameColors.uiText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Then ${kManualNextDayCost.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: GameColors.uiGold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _HudActionButton(
                            icon: Icons.skip_next,
                            tooltip: 'Next Day',
                            color: GameColors.uiHighlight,
                            onPressed: () {
                              state.advanceDay().then((ok) {
                                if (!ok && context.mounted) {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  messenger
                                    ..hideCurrentSnackBar()
                                    ..clearSnackBars();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      showCloseIcon: true,
                                      dismissDirection: DismissDirection.down,
                                      content: Text(
                                        'No free Next Day left today. Need ${kManualNextDayCost.toStringAsFixed(0)} currency.',
                                      ),
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          if (state.tractorOwned) ...[
                            _HudActionButton(
                              icon: state.autoHarvestEnabled
                                  ? Icons.agriculture
                                  : Icons.agriculture_outlined,
                              tooltip: state.autoHarvestEnabled
                                  ? 'Disable Auto Harvest'
                                  : 'Enable Auto Harvest',
                              color: state.autoHarvestEnabled
                                  ? GameColors.uiGreen
                                  : GameColors.uiGold,
                              onPressed: () {
                                final target = !state.autoHarvestEnabled;
                                state.setAutoHarvestEnabled(target).then((ok) {
                                  if (!ok || !context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 1),
                                      content: Text(
                                        target
                                            ? 'Auto harvest enabled.'
                                            : 'Auto harvest paused.',
                                      ),
                                    ),
                                  );
                                });
                              },
                            ),
                            const SizedBox(height: 6),
                          ],
                          _HudActionButton(
                            icon: Icons.science,
                            tooltip: 'Use Fertilizer Pack',
                            color: state.fertilizerPackCount > 0
                                ? GameColors.uiHighlight
                                : GameColors.uiTextDim,
                            onPressed: () {
                              state.useFertilizerPack().then((boostedCount) {
                                if (!context.mounted) return;
                                final messenger = ScaffoldMessenger.of(context);
                                messenger
                                  ..hideCurrentSnackBar()
                                  ..clearSnackBars();

                                if (boostedCount > 0) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      showCloseIcon: true,
                                      dismissDirection: DismissDirection.down,
                                      content: Text(
                                        'Used 1 Fertilizer Pack. Boosted $boostedCount crops by +1 stage.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (boostedCount == 0) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      showCloseIcon: true,
                                      dismissDirection: DismissDirection.down,
                                      content: Text(
                                        'No growing crops to fertilize right now.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                messenger.showSnackBar(
                                  const SnackBar(
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    showCloseIcon: true,
                                    dismissDirection: DismissDirection.down,
                                    content: Text(
                                      'No Fertilizer Pack available or use failed.',
                                    ),
                                  ),
                                );
                              });
                            },
                          ),
                          const SizedBox(height: 6),
                          _HudActionButton(
                            icon: Icons.account_balance,
                            tooltip: 'Bank',
                            color: GameColors.uiGreen,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BankScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _HudActionButton(
                            icon: Icons.shopping_cart,
                            tooltip: 'Merchant',
                            color: GameColors.uiGold,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MerchantScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _HudActionButton(
                            icon: Icons.warning_amber,
                            tooltip: 'Simulate Disaster',
                            color: Colors.orange,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    title: const Text('Simulate Disaster'),
                                    content: const Text(
                                      'Choose a disaster to trigger immediately.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          state.triggerDisaster(
                                            DisasterType.flood,
                                          );
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Flood'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          state.triggerDisaster(
                                            DisasterType.storm,
                                          );
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Storm'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          state.triggerDisaster(
                                            DisasterType.drought,
                                          );
                                          Navigator.of(context).pop();
                                        },
                                        child: const Text('Drought'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          _HudActionButton(
                            icon: Icons.leaderboard,
                            tooltip: 'Leaderboard',
                            color: Colors.amber,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LeaderboardScreen(player: player),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _convertCurrency(
    double amount, {
    required String fromCountry,
    required String toCountry,
  }) {
    final fromRate = _currencyToUsdRate[fromCountry];
    final toRate = _currencyToUsdRate[toCountry];
    if (fromRate == null || toRate == null || fromRate == 0) return amount;
    final amountInUsd = amount * fromRate;
    return amountInUsd / toRate;
  }

  String _formatCountdown(int seconds) {
    final min = (seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  IconData _weatherIcon(dynamic disaster) {
    switch (disaster.toString()) {
      case 'DisasterType.flood':
        return Icons.water;
      case 'DisasterType.storm':
        return Icons.flash_on;
      case 'DisasterType.drought':
        return Icons.local_fire_department;
      default:
        return Icons.cloud;
    }
  }

  String _weatherLabel(dynamic disaster) {
    switch (disaster.toString()) {
      case 'DisasterType.flood':
        return 'Flood!';
      case 'DisasterType.storm':
        return 'Storm!';
      case 'DisasterType.drought':
        return 'Drought!';
      default:
        return 'Clear';
    }
  }

  Color _weatherColor(dynamic disaster) {
    switch (disaster.toString()) {
      case 'DisasterType.flood':
        return GameColors.rainDrop;
      case 'DisasterType.storm':
        return GameColors.uiRed;
      case 'DisasterType.drought':
        return Colors.orange;
      default:
        return GameColors.uiTextDim;
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────

/// Generic chip wrapper for top bar items.
class _HudChip extends StatelessWidget {
  final List<Widget> children;
  const _HudChip({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: GameColors.uiPanel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GameColors.uiAccent.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _HudBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HudBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: GameColors.uiPanel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact credit score badge with color coding.
class _CreditScoreBadge extends StatelessWidget {
  final int score;
  const _CreditScoreBadge({required this.score});

  Color get _color {
    if (score >= 700) return GameColors.uiGreen;
    if (score >= 550) return GameColors.uiGold;
    return GameColors.uiRed;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = ((score - 300) / 550).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GameColors.uiPanel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 18,
            child: CustomPaint(
              painter: _SemiGaugePainter(progress: normalized, color: _color),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$score',
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _SemiGaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _SemiGaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height - 1);

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      basePaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SemiGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _HudActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _HudActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Min 44x44pt touch target (mobile-games skill)
    return Tooltip(
      message: tooltip,
      child: Material(
        color: GameColors.uiPanel.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}
