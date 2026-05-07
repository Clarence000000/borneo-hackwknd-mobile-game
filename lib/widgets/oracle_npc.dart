import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/gemini_service.dart';
import 'package:farm_fintech/widgets/oracle_chat_dialog.dart';

/// Animated Oracle NPC character using character_14_frame32x32.png sprite sheet.
/// Sits at the bottom-left of the game screen. Monitors financial health and
/// shows a pulsing warning badge when danger is detected.
class OracleNpc extends StatefulWidget {
  const OracleNpc({super.key});

  @override
  State<OracleNpc> createState() => _OracleNpcState();
}

class _OracleNpcState extends State<OracleNpc> with TickerProviderStateMixin {
  // ── Sprite animation ──────────────────────────────────────────
  static const int _frameCount = 4; // frames per row (idle row = row 0)
  static const int _frameSize = 32;
  static const double _displayScale = 2.5;
  static const double _displaySize = _frameSize * _displayScale; // 80px

  int _currentFrame = 0;
  Timer? _animTimer;
  ui.Image? _spriteSheet;
  bool _spriteLoaded = false;

  // ── Danger / AI state ─────────────────────────────────────────
  final GeminiService _gemini = GeminiService();
  bool _isDangerous = false;
  int _trustScore = 75;
  String _lastWarning = '';
  Timer? _analysisTimer;
  String? _lastAnalyzedKey; // to avoid re-analyzing same state

  // ── Badge pulse animation ─────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Hover glow ────────────────────────────────────────────────
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _loadSprite();
    _startAnimation();
    _setupPulseAnimation();
    // Delay first analysis so game state is fully loaded
    Future.delayed(const Duration(seconds: 5), _startPeriodicAnalysis);
  }

  Future<void> _loadSprite() async {
    try {
      final data = await rootBundle.load('assets/images/character_14_frame32x32.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _spriteSheet = frame.image;
          _spriteLoaded = true;
        });
      }
    } catch (_) {
      // Sprite failed to load — widget will show fallback
    }
  }

  void _startAnimation() {
    _animTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (mounted) {
        setState(() => _currentFrame = (_currentFrame + 1) % _frameCount);
      }
    });
  }

  void _setupPulseAnimation() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startPeriodicAnalysis() {
    if (!mounted) return;
    _runAnalysis();
    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _runAnalysis();
    });
  }

  Future<void> _runAnalysis() async {
    final state = context.read<GameState>();
    final player = state.player;
    if (player == null) return;

    // Build a simple key to avoid redundant API calls for identical state
    final key = '${player.cashBalance.toInt()}_${player.creditScore}_'
        '${state.bnplPlans.length}_${state.loans.length}_${state.activeDisaster}';
    if (key == _lastAnalyzedKey) return;
    _lastAnalyzedKey = key;

    final result = await _gemini.analyzeFinancialDanger(
      player: player,
      activeBnplCount: state.bnplPlans.length,
      activeLoanCount: state.loans.length,
      currentDay: state.currentDay,
      activeDisaster: state.activeDisaster.toString(),
    );

    if (!mounted) return;
    setState(() {
      _isDangerous = result.isDangerous;
      _trustScore = result.trustScore;
      _lastWarning = result.warningMessage;
    });
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _analysisTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _openChat() {
    final state = context.read<GameState>();
    final player = state.player;
    if (player == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => OracleChatDialog(
        initialTrustScore: _trustScore,
        initialWarning: _lastWarning,
        isDangerous: _isDangerous,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-run analysis when relevant game state changes
    context.select<GameState, String>((s) =>
        '${s.player?.cashBalance}_${s.player?.creditScore}_${s.bnplPlans.length}_${s.activeDisaster}');

    return Positioned(
      bottom: 16,
      left: 16,
      child: GestureDetector(
        onTap: _openChat,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Glow base ────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _isDangerous
                          ? const Color(0xFFFF6B35).withValues(alpha: _isHovered ? 0.9 : 0.6)
                          : const Color(0xFF9B59B6).withValues(alpha: _isHovered ? 0.8 : 0.4),
                      blurRadius: _isHovered ? 24 : 14,
                      spreadRadius: _isHovered ? 6 : 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Sprite + border ────────────────────────
                    Container(
                      width: _displaySize + 12,
                      height: _displaySize + 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0D2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isDangerous
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF9B59B6),
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _spriteLoaded
                            ? CustomPaint(
                                size: Size(_displaySize, _displaySize),
                                painter: _SpritePainter(
                                  image: _spriteSheet!,
                                  frame: _currentFrame,
                                  row: 0, // idle row
                                  frameSize: _frameSize,
                                  displayScale: _displayScale,
                                ),
                              )
                            : _buildFallbackCharacter(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ── Name tag ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0D2E).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF9B59B6).withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '✨ Lyra',
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFE0C3FC),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Danger badge ──────────────────────────────────
              if (_isDangerous)
                Positioned(
                  top: -4,
                  right: -4,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, child) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3D00),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3D00).withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('!', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Tap hint ──────────────────────────────────────
              if (_isHovered)
                Positioned(
                  bottom: 52,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0D2E).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF9B59B6).withValues(alpha: 0.7)),
                      ),
                      child: Text(
                        'Speak with Lyra',
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFFE0C3FC),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCharacter() {
    return Container(
      width: _displaySize,
      height: _displaySize,
      color: const Color(0xFF2D1B4E),
      child: const Center(
        child: Text('🧙', style: TextStyle(fontSize: 32)),
      ),
    );
  }
}

/// CustomPainter that draws a single frame from a sprite sheet.
class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final int frame;
  final int row;
  final int frameSize;
  final double displayScale;

  const _SpritePainter({
    required this.image,
    required this.frame,
    required this.row,
    required this.frameSize,
    required this.displayScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      (frame * frameSize).toDouble(),
      (row * frameSize).toDouble(),
      frameSize.toDouble(),
      frameSize.toDouble(),
    );
    final dst = Rect.fromLTWH(
      0,
      0,
      frameSize * displayScale,
      frameSize * displayScale,
    );
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter old) =>
      old.frame != frame || old.row != row;
}
