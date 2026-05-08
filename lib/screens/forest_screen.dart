import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/forest_game.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/widgets/forest_npc_dialogue_panel.dart';

/// Full-screen view of the Wild Forest area.
///
/// Interaction model mirrors game_screen.dart:
///   proximity → parchment overlay button → [ForestNpcDialoguePanel] slide-up
///   tap on NPC sprite → same dialogue panel
class ForestScreen extends StatefulWidget {
  const ForestScreen({super.key});

  @override
  State<ForestScreen> createState() => _ForestScreenState();
}

class _ForestScreenState extends State<ForestScreen> {
  late final ForestGame _game;

  String? _nearNpcName;
  bool _dialogueOpen = false;
  String? _activeDialogueNpc;
  String? _activeDialogueMessage;

  static const Map<String, String> _messages = {
    'oracle':
        'Ah, a visitor from the farm! The forest spirits sense your financial struggles. '
        'Remember: plant wisely, repay promptly, and the land will reward you.',
    'trader':
        'Psst! I trade rare seeds from distant lands. Come back when your pockets are fuller...',
  };

  static const Map<String, String> _displayNames = {
    'oracle': 'The Oracle',
    'trader': 'Mysterious Trader',
  };

  @override
  void initState() {
    super.initState();
    _game = ForestGame();
    _game.onExit = _exitToFarm;
    _game.onNearNpcChanged = (name) {
      if (mounted) setState(() => _nearNpcName = name);
    };
    _game.onNpcTapped = _onNpcTapped;
  }

  void _exitToFarm() {
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _onNpcTapped(String npcName) {
    if (_dialogueOpen || !mounted) return;
    context.read<GameState>().visitLocation('wild_forest');
    setState(() {
      _dialogueOpen = true;
      _activeDialogueNpc = npcName;
      _activeDialogueMessage =
          _messages[npcName] ?? 'Greetings, traveler from the farm.';
    });
  }

  void _closeDialogue() {
    if (!mounted) return;
    setState(() {
      _dialogueOpen = false;
      _activeDialogueNpc = null;
      _activeDialogueMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      body: Stack(
        children: [
          // ── Flame game (tap forwarded to world-space hit-test) ──
          GestureDetector(
            onTapUp: (details) => _game.handleTap(details.localPosition),
            child: GameWidget(game: _game),
          ),

          // ── Back button ──────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton.icon(
                  onPressed: _exitToFarm,
                  icon: const Icon(Icons.arrow_back,
                      color: GameColors.uiText, size: 18),
                  label: const Text(
                    'Farm',
                    style: TextStyle(color: GameColors.uiText, fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: GameColors.uiPanel.withValues(alpha: 0.85),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

          // ── Location label ───────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3320).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF4A7C59).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Text(
                    '🌲 The Wild Forest',
                    style: TextStyle(
                      color: Color(0xFFD4C99A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── NPC proximity overlay ────────────────────────────
          if (_nearNpcName != null && !_dialogueOpen)
            _buildInteractionOverlay(_nearNpcName!),

          // ── NPC dialogue panel ───────────────────────────────
          if (_dialogueOpen && _activeDialogueNpc != null)
            ForestNpcDialoguePanel(
              npcName: _activeDialogueNpc!,
              message: _activeDialogueMessage!,
              onClose: _closeDialogue,
            ),
        ],
      ),
    );
  }

  Widget _buildInteractionOverlay(String npcName) {
    const parchmentColor = Color(0xFFF4E4BC);
    const leatherBorder = Color(0xFF5D4037);
    const highlightColor = Color(0xFFC5A021);
    const textColor = Color(0xFF2D1B10);

    final label = _displayNames[npcName] ?? npcName;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 110,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 200),
          builder: (context, value, child) => Transform.scale(
            scale: 0.8 + 0.2 * value,
            child: Opacity(opacity: value, child: child),
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: parchmentColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: leatherBorder, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned(
                  top: 0,
                  left: 0,
                  child: Icon(Icons.auto_awesome,
                      size: 8, color: leatherBorder),
                ),
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: Icon(Icons.auto_awesome,
                      size: 8, color: leatherBorder),
                ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: InkWell(
                    onTap: () => _onNpcTapped(npcName),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: leatherBorder.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'F',
                            style: GoogleFonts.cinzel(
                              color: highlightColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Speak with $label',
                          style: GoogleFonts.almendra(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
