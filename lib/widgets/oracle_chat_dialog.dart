import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/gemini_service.dart';

/// Visual-novel style chat dialog for Lyra the Oracle.
/// Opens as a modal bottom sheet with animated character portrait,
/// chat bubbles, trust score bar, and a text input.
class OracleChatDialog extends StatefulWidget {
  final int initialTrustScore;
  final String initialWarning;
  final bool isDangerous;
  final bool isWarningMode;
  final String? warningButtonText;

  const OracleChatDialog({
    super.key,
    required this.initialTrustScore,
    required this.initialWarning,
    required this.isDangerous,
    this.isWarningMode = false,
    this.warningButtonText,
  });

  @override
  State<OracleChatDialog> createState() => _OracleChatDialogState();
}

class _OracleChatDialogState extends State<OracleChatDialog>
    with TickerProviderStateMixin {
  // ── Sprite ────────────────────────────────────────────────────
  static const int _frameCount = 4;
  static const int _frameSize = 32;
  static const double _portraitScale = 2.0;

  int _currentFrame = 0;
  Timer? _animTimer;
  ui.Image? _spriteSheet;

  // ── Chat ──────────────────────────────────────────────────────
  final GeminiService _gemini = GeminiService();
  final List<Map<String, String>> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // ── Trust score ───────────────────────────────────────────────
  late int _trustScore;

  // ── Typing animation ──────────────────────────────────────────
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _trustScore = widget.initialTrustScore;
    _loadSprite();
    _startAnimation();

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    // Add Lyra's greeting or warning as the first message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final greeting = widget.isDangerous && widget.initialWarning.isNotEmpty
          ? widget.initialWarning
          : "Greetings, dear farmer! I am Lyra, Oracle of the Realm. Speak thy questions freely — be they of harvest, coin, or destiny itself.";
      setState(() {
        _messages.add({'role': 'lyra', 'content': greeting});
      });
    });
  }

  Future<void> _loadSprite() async {
    try {
      final data = await rootBundle.load('assets/images/character_14_frame32x32.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _spriteSheet = frame.image);
    } catch (_) {}
  }

  void _startAnimation() {
    _animTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _currentFrame = (_currentFrame + 1) % _frameCount);
    });
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _dotController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _scrollToBottom();

    final state = context.read<GameState>();
    final player = state.player!;

    final reply = await _gemini.chatWithOracle(
      player: player,
      activeBnplCount: state.bnplPlans.length,
      activeLoanCount: state.loans.length,
      currentDay: state.currentDay,
      activeDisaster: state.activeDisaster.toString(),
      chatHistory: List.from(_messages.where((m) => m['role'] != 'loading')),
      userMessage: text,
      trustScore: _trustScore,
    );

    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'lyra', 'content': reply});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Trust score color ─────────────────────────────────────────
  Color get _trustColor {
    if (_trustScore >= 70) return const Color(0xFF4CAF50);
    if (_trustScore >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFFF3D00);
  }

  String get _trustLabel {
    if (_trustScore >= 70) return 'Prosperous';
    if (_trustScore >= 40) return 'Wavering';
    return 'In Peril';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0520),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── Drag handle ──────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header: character + name + trust score ────────────
          _buildHeader(),

          // ── Decorative divider ────────────────────────────────
          _buildDivider(),

          // ── Chat messages ─────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                return _buildMessageBubble(msg['role']!, msg['content']!);
              },
            ),
          ),

          // ── Decorative divider ────────────────────────────────
          _buildDivider(),

          // ── Input area ────────────────────────────────────────
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Portrait
          Container(
            width: _frameSize * _portraitScale + 8,
            height: _frameSize * _portraitScale + 8,
            decoration: BoxDecoration(
              color: const Color(0xFF1A0D2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isDangerous
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF9B59B6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B59B6).withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _spriteSheet != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomPaint(
                      size: Size(
                        _frameSize * _portraitScale,
                        _frameSize * _portraitScale,
                      ),
                      painter: _DialogSpritePainter(
                        image: _spriteSheet!,
                        frame: _currentFrame,
                        row: 0,
                        frameSize: _frameSize,
                        displayScale: _portraitScale,
                      ),
                    ),
                  )
                : const Center(child: Text('🧙', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '✨ Lyra the Oracle',
                      style: GoogleFonts.cinzel(
                        color: const Color(0xFFE0C3FC),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (widget.isDangerous) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3D00).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFF3D00), width: 1),
                        ),
                        child: Text(
                          '⚠ ALERT',
                          style: GoogleFonts.cinzel(
                            color: const Color(0xFFFF6B35),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                // Trust score bar
                Row(
                  children: [
                    Text(
                      'Financial Aura: ',
                      style: GoogleFonts.almendra(
                        color: const Color(0xFF9B59B6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$_trustScore/100',
                      style: GoogleFonts.cinzel(
                        color: _trustColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($_trustLabel)',
                      style: GoogleFonts.almendra(
                        color: _trustColor.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _trustScore / 100,
                    backgroundColor: const Color(0xFF2D1B4E),
                    valueColor: AlwaysStoppedAnimation<Color>(_trustColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Color(0xFF9B59B6), size: 20),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const SizedBox(width: 16),
        const Icon(Icons.auto_awesome, size: 10, color: Color(0xFF9B59B6)),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9B59B6).withValues(alpha: 0.1),
                  const Color(0xFF9B59B6).withValues(alpha: 0.6),
                  const Color(0xFF9B59B6).withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
        ),
        const Icon(Icons.auto_awesome, size: 10, color: Color(0xFF9B59B6)),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMessageBubble(String role, String content) {
    final isLyra = role == 'lyra';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isLyra ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isLyra) ...[
            // Lyra avatar dot
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2D1B4E),
                border: Border.all(color: const Color(0xFF9B59B6), width: 1.5),
              ),
              child: const Center(
                child: Text('✨', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isLyra
                    ? const Color(0xFF1A0D2E)
                    : const Color(0xFF0F3460),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isLyra ? 4 : 16),
                  bottomRight: Radius.circular(isLyra ? 16 : 4),
                ),
                border: Border.all(
                  color: isLyra
                      ? const Color(0xFF9B59B6).withValues(alpha: 0.4)
                      : const Color(0xFF3498DB).withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isLyra ? const Color(0xFF9B59B6) : const Color(0xFF3498DB))
                        .withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                content,
                style: GoogleFonts.almendra(
                  color: isLyra ? const Color(0xFFE0C3FC) : const Color(0xFFBDD6F5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (!isLyra) ...[
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F3460),
                border: Border.all(color: const Color(0xFF3498DB), width: 1.5),
              ),
              child: const Center(
                child: Text('🌾', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2D1B4E),
              border: Border.all(color: const Color(0xFF9B59B6), width: 1.5),
            ),
            child: const Center(child: Text('✨', style: TextStyle(fontSize: 10))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0D2E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: const Color(0xFF9B59B6).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (_, child) {
                final t = _dotController.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final offset = (t - i * 0.2).clamp(0.0, 1.0);
                    final opacity = (offset < 0.5 ? offset : 1 - offset) * 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF9B59B6).withValues(alpha: opacity.clamp(0.2, 1.0)),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    if (widget.isWarningMode) {
      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0520),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E44AD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE0C3FC), width: 1.5),
              ),
              elevation: 8,
              shadowColor: const Color(0xFF9B59B6).withValues(alpha: 0.6),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(
              widget.warningButtonText ?? 'I UNDERSTAND',
              style: GoogleFonts.cinzel(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0520),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A0D2E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF9B59B6).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !_isLoading,
                style: GoogleFonts.almendra(
                  color: const Color(0xFFE0C3FC),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask the Oracle...',
                  hintStyle: GoogleFonts.almendra(
                    color: const Color(0xFF9B59B6).withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
                maxLines: 3,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isLoading
                      ? [const Color(0xFF2D1B4E), const Color(0xFF2D1B4E)]
                      : [const Color(0xFF8E44AD), const Color(0xFF6C3483)],
                ),
                boxShadow: _isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF9B59B6).withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_empty : Icons.send,
                color: _isLoading
                    ? const Color(0xFF9B59B6).withValues(alpha: 0.5)
                    : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sprite painter for the chat dialog portrait.
class _DialogSpritePainter extends CustomPainter {
  final ui.Image image;
  final int frame;
  final int row;
  final int frameSize;
  final double displayScale;

  const _DialogSpritePainter({
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
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(covariant _DialogSpritePainter old) =>
      old.frame != frame || old.row != row;
}
