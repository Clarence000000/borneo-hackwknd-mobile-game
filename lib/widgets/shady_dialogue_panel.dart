import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';

/// A Lyra-style dialogue panel anchored to the bottom of the screen.
///
/// Shows a typewriter-animated message from the Shady Lender NPC.
/// Displays borrow options when debt-free, or repay options when indebted.
class ShadyDialoguePanel extends StatefulWidget {
  final RichiFarmGame game;

  const ShadyDialoguePanel({super.key, required this.game});

  @override
  State<ShadyDialoguePanel> createState() => _ShadyDialoguePanelState();
}

class _ShadyDialoguePanelState extends State<ShadyDialoguePanel>
    with SingleTickerProviderStateMixin {
  // ── Typewriter state ───────────────────────────────────────
  String _fullText = '';
  String _displayedText = '';
  int _charIndex = 0;
  Timer? _typeTimer;
  bool _textComplete = false;

  // ── Animation ──────────────────────────────────────────────
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Slide-up entrance animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();

    // Determine dialogue text based on debt state
    final state = context.read<GameState>();
    final debt = state.sharkDebt;
    final country = state.player?.country ?? 'MY';

    if (debt > 0) {
      _fullText =
          'You owe me ${CurrencyUtil.format(debt, country)}. '
          'I suggest you pay up soon... unless you want things to get unpleasant.';
    } else {
      _fullText =
          'Greetings, farmer! Looking for a way out of your financial mess? '
          'I have ${CurrencyUtil.format(1200, country)} ready for you... '
          'at a very reasonable rate of 35% per month. What do you say?';
    }

    // Start typewriter
    _typeTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (_charIndex < _fullText.length) {
        setState(() {
          _charIndex++;
          _displayedText = _fullText.substring(0, _charIndex);
        });
      } else {
        _typeTimer?.cancel();
        setState(() => _textComplete = true);
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _skipTypewriter() {
    _typeTimer?.cancel();
    setState(() {
      _charIndex = _fullText.length;
      _displayedText = _fullText;
      _textComplete = true;
    });
  }

  void _close() {
    final state = context.read<GameState>();
    state.showShadyDialogue = false;
    state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<GameState>();
    final debt = state.sharkDebt;
    final hasDebt = debt > 0;

    const cream = Color(0xFFF9F4E8);
    const inkBrown = Color(0xFF2D1B10);
    const borderBrown = Color(0xFF8B7355);

    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.28,
          ),
          decoration: BoxDecoration(
            color: cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: borderBrown.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Portrait ──────────────────────────────
                  Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 14, top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE8DCC8),
                      border: Border.all(color: borderBrown, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildPortrait(),
                  ),

                  // ── Text content ─────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Text(
                          '§  FROM THE DESK OF SHADY LENDER',
                          style: GoogleFonts.cinzel(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: borderBrown.withValues(alpha: 0.7),
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Typewriter dialogue text
                        Flexible(
                          child: GestureDetector(
                            onTap: _textComplete ? null : _skipTypewriter,
                            child: Text(
                              _displayedText,
                              style: GoogleFonts.almendra(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: inkBrown,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ── Action buttons (ghost buttons) ──
                        AnimatedOpacity(
                          opacity: _textComplete ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: _textComplete
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: hasDebt
                                      ? _buildRepayButtons(state)
                                      : _buildBorrowButtons(state),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  // ── Skip / Close icons ───────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_textComplete)
                        _iconButton(Icons.play_arrow, _skipTypewriter)
                      else
                        const SizedBox(width: 24),
                      const SizedBox(height: 4),
                      _iconButton(Icons.close, _close),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the NPC portrait from the single-sprite image.
  Widget _buildPortrait() {
    return Image.asset(
      'assets/images/shady_lender.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: const Color(0xFF8B7355)),
      ),
    );
  }

  // ── Borrow mode buttons ────────────────────────────────────
  List<Widget> _buildBorrowButtons(GameState state) {
    final country = state.player?.country ?? 'MY';
    return [
      _ghostButton(
        label: 'Accept Loan',
        color: const Color(0xFFCC0000),
        onTap: () async {
          _close();
          final ok = await state.takeLoanSharkLoan(1200);
          if (!mounted) return;
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
      ),
      const SizedBox(width: 12),
      _ghostButton(
        label: 'Walk Away',
        color: const Color(0xFF2D1B10),
        onTap: _close,
      ),
    ];
  }

  // ── Repay mode buttons ─────────────────────────────────────
  List<Widget> _buildRepayButtons(GameState state) {
    final country = state.player?.country ?? 'MY';
    final player = state.player;
    final debt = state.sharkDebt;
    final canPayFull = player != null && (player.cashBalance + player.bankBalance) >= debt;
    final canPayPartial = player != null && (player.cashBalance + player.bankBalance) >= 500 && debt >= 500;

    return [
      _ghostButton(
        label: 'Repay Full (${CurrencyUtil.format(debt, country)})',
        color: canPayFull ? const Color(0xFF228B22) : const Color(0xFFAAAAAA),
        onTap: canPayFull
            ? () async {
                _close();
                final repaid = await state.repaySharkLoan(debt);
                if (!mounted) return;
                DialogPopup.show(
                  context,
                  title: '✅ Debt Cleared!',
                  message: 'You repaid ${CurrencyUtil.format(repaid, country)}. You are free... for now.',
                  icon: Icons.check_circle,
                  iconColor: GameColors.uiGreen,
                );
              }
            : null,
      ),
      const SizedBox(width: 8),
      _ghostButton(
        label: 'Repay ${CurrencyUtil.format(500, country)}',
        color: canPayPartial ? GameColors.uiGold : const Color(0xFFAAAAAA),
        onTap: canPayPartial
            ? () async {
                _close();
                final repaid = await state.repaySharkLoan(500);
                if (!mounted) return;
                DialogPopup.show(
                  context,
                  title: '💰 Partial Repayment',
                  message: 'You repaid ${CurrencyUtil.format(repaid, country)}. '
                      'Remaining: ${CurrencyUtil.format(state.sharkDebt, country)}',
                  icon: Icons.payments,
                  iconColor: GameColors.uiGold,
                );
              }
            : null,
      ),
      const SizedBox(width: 8),
      _ghostButton(
        label: 'Walk Away',
        color: const Color(0xFF2D1B10),
        onTap: _close,
      ),
    ];
  }

  /// Ghost-style button matching the Lyra screenshot aesthetic.
  Widget _ghostButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (isDisabled ? const Color(0xFFAAAAAA) : color).withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.almendra(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDisabled ? const Color(0xFFAAAAAA) : color,
          ),
        ),
      ),
    );
  }
}
