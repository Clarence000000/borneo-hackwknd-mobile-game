import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/screens/bank_screen.dart';
import 'package:farm_fintech/screens/merchant_screen.dart';
import 'package:farm_fintech/screens/leaderboard_screen.dart';

/// Country flag emoji lookup
const _countryFlags = {
  'MY': '🇲🇾',
  'ID': '🇮🇩',
  'SG': '🇸🇬',
  'TH': '🇹🇭',
  'PH': '🇵🇭',
  'VN': '🇻🇳',
};

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
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final player = state.player;
        if (player == null) return const SizedBox();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                // ── Top Bar (full width, landscape) ────────────
                Row(
                  children: [
                    // Player profile chip
                    _HudChip(
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
                    const SizedBox(width: 6),

                    // Cash badge
                    _HudBadge(
                      icon: Icons.monetization_on,
                      label: '\$${player.cashBalance.toStringAsFixed(0)}',
                      color: GameColors.uiGold,
                    ),
                    const SizedBox(width: 6),

                    // Bank badge (if registered)
                    if (player.bankRegistered) ...[
                      _HudBadge(
                        icon: Icons.account_balance,
                        label: '\$${player.bankBalance.toStringAsFixed(0)}',
                        color: GameColors.uiGreen,
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Credit score badge
                    _CreditScoreBadge(score: player.creditScore),

                    const Spacer(),

                    // Weather indicator
                    _HudBadge(
                      icon: _weatherIcon(state.activeDisaster),
                      label: _weatherLabel(state.activeDisaster),
                      color: _weatherColor(state.activeDisaster),
                    ),
                    const SizedBox(width: 6),

                    // Day counter
                    _HudBadge(
                      icon: Icons.wb_sunny,
                      label: 'Day ${state.currentDay}',
                      color: GameColors.uiHighlight,
                    ),
                  ],
                ),

                const Spacer(),

                // ── Right-side action buttons (vertical column) ─
                Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HudActionButton(
                        icon: Icons.skip_next,
                        tooltip: 'Next Day',
                        color: GameColors.uiHighlight,
                        onPressed: () => state.advanceDay(),
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
                        icon: Icons.leaderboard,
                        tooltip: 'Leaderboard',
                        color: Colors.amber,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeaderboardScreen(player: player),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: GameColors.uiPanel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed, color: _color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$score',
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
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
