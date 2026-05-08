import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Slide-up dialogue panel for forest NPCs (Oracle / Trader).
///
/// Mirrors [ShadyDialoguePanel]: same cream / inkBrown / borderBrown palette,
/// NPC portrait on the left, typewriter-animated text, SlideTransition entrance,
/// and a 'Farewell' ghost button that fires [onClose].
class ForestNpcDialoguePanel extends StatefulWidget {
  final String npcName;
  final String message;
  final VoidCallback onClose;

  const ForestNpcDialoguePanel({
    super.key,
    required this.npcName,
    required this.message,
    required this.onClose,
  });

  @override
  State<ForestNpcDialoguePanel> createState() => _ForestNpcDialoguePanelState();
}

class _ForestNpcDialoguePanelState extends State<ForestNpcDialoguePanel>
    with SingleTickerProviderStateMixin {
  // ── Typewriter ──────────────────────────────────────────────
  String _displayedText = '';
  int _charIndex = 0;
  Timer? _typeTimer;
  bool _textComplete = false;

  // ── Slide-up animation ──────────────────────────────────────
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  static const Map<String, String> _titles = {
    'oracle': 'THE ORACLE',
    'trader': 'MYSTERIOUS TRADER',
  };

  static const Map<String, String> _portraits = {
    'oracle': 'assets/images/oracle.png',
    'trader': 'assets/images/trader.png',
  };

  @override
  void initState() {
    super.initState();

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

    _typeTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (_charIndex < widget.message.length) {
        setState(() {
          _charIndex++;
          _displayedText = widget.message.substring(0, _charIndex);
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
      _charIndex = widget.message.length;
      _displayedText = widget.message;
      _textComplete = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFF9F4E8);
    const inkBrown = Color(0xFF2D1B10);
    const borderBrown = Color(0xFF8B7355);

    final title = _titles[widget.npcName] ??
        (widget.npcName[0].toUpperCase() + widget.npcName.substring(1)).toUpperCase();
    final portraitPath = _portraits[widget.npcName] ?? _portraits['oracle']!;

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
                    child: Image.asset(
                      portraitPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),

                  // ── Text content ──────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '§  $title',
                          style: GoogleFonts.cinzel(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: borderBrown.withValues(alpha: 0.7),
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 8),

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

                        AnimatedOpacity(
                          opacity: _textComplete ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: _textComplete
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _ghostButton(
                                      label: 'Farewell',
                                      color: inkBrown,
                                      onTap: widget.onClose,
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),

                  // ── Skip / Close icons ────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_textComplete)
                        _iconButton(Icons.play_arrow, _skipTypewriter)
                      else
                        const SizedBox(width: 24),
                      const SizedBox(height: 4),
                      _iconButton(Icons.close, widget.onClose),
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

  Widget _ghostButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.almendra(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
