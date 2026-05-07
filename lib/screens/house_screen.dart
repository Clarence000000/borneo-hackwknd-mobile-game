import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/house_interior_game.dart';

/// Full-screen view of the house interior.
///
/// Renders [HouseInteriorGame] and returns to the farm when the player
/// steps onto the Door exit or taps the back button.
class HouseScreen extends StatefulWidget {
  const HouseScreen({super.key});

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen> {
  late final HouseInteriorGame _game;

  @override
  void initState() {
    super.initState();
    _game = HouseInteriorGame();
    _game.onExitDoor = _exitToFarm;
  }

  void _exitToFarm() {
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      body: Stack(
        children: [
          // Interior Flame game
          GameWidget(game: _game),

          // Back button — top-left fallback exit
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: _exitToFarm,
                  icon: const Icon(Icons.arrow_back, color: GameColors.uiText, size: 18),
                  label: const Text(
                    'Farm',
                    style: TextStyle(color: GameColors.uiText, fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: GameColors.uiPanel.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: GameColors.uiAccent.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
