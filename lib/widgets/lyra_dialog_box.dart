import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/gemini_service.dart';
import 'package:farm_fintech/models/quest.dart';
import 'package:farm_fintech/models/financial/transaction.dart';
import 'package:farm_fintech/config/constants.dart';

/// Pokemon GBA-style visual novel dialog box.
///
/// A full-width text box that slides up from the bottom of the screen.
/// Shows Lyra's portrait on the left, her name plate, and text that types
/// out character-by-character. The player can type replies in a bottom field.
class LyraDialogBox extends StatefulWidget {
  final int initialTrustScore;
  final String initialWarning;
  final bool isDangerous;
  final String initialMode; // 'chat' or 'quest'
  final VoidCallback onClose;

  const LyraDialogBox({
    super.key,
    required this.initialTrustScore,
    required this.initialWarning,
    required this.isDangerous,
    required this.initialMode,
    required this.onClose,
  });

  @override
  State<LyraDialogBox> createState() => _LyraDialogBoxState();
}

class _LyraDialogBoxState extends State<LyraDialogBox>
    with SingleTickerProviderStateMixin {
  // ── Assets ───────────────────────────────────────────────────
  static const String _uiAssetPath = 'assets/images/letter UI/UI assets pack 2/UI books & more.png';
  ui.Image? _uiAsset;
  ui.Image? _spriteSheet;

  // ── Slide-in animation ────────────────────────────────────────
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // ── Chat / typewriter ─────────────────────────────────────────
  final GeminiService _gemini = GeminiService();
  final List<Map<String, String>> _history = [];
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  String _displayedText = '';
  String _fullText = '';
  Timer? _typeTimer;
  bool _isTyping = false;
  bool _isLoading = false;
  bool _showInput = false;
  bool _showHistory = false;
  int _trustScore = 75;
  Quest? _pendingQuest;
  bool _showingQuest = false;

  @override
  void initState() {
    super.initState();
    _trustScore = widget.initialTrustScore;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5), // slide from further down
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    _loadAssets();
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialMode == 'quest') {
        _startQuestFlow();
      } else {
        final opening = widget.isDangerous && widget.initialWarning.isNotEmpty
            ? widget.initialWarning
            : "Greetings, farmer! I am Lyra, Oracle of the Realm. How can I guide you today?";
        _typeOutText(opening);
      }
    });
  }

  Future<void> _startQuestFlow() async {
    final state = context.read<GameState>();
    
    if (state.activeQuest != null) {
      final q = state.activeQuest!;
      String statusText = "You are currently on the '${q.title}' quest. Progress: ${q.currentProgress.toInt()}/${q.goalAmount.toInt()}.";
      if (q.status == QuestStatus.completed) {
        statusText = "You've completed '${q.title}'! Well done! I've cleared it from your log.";
        state.activeQuest = null; // Clear after showing
      } else if (q.status == QuestStatus.failed) {
        statusText = "Alas, '${q.title}' has expired. Your payment was lost to the winds of time.";
        state.activeQuest = null;
      }
      _typeOutText(statusText);
      return;
    }

    setState(() {
      _isLoading = true;
      _displayedText = 'Lyra is consulting the scrolls...';
    });

    final quest = await _gemini.generateQuest(
      player: state.player!,
      currentDay: state.currentDay,
      activeBnplCount: state.bnplPlans.length,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _pendingQuest = quest;
      _showingQuest = true;
    });

    final text = "I have a challenge for you: '${quest.title}'. ${quest.description} It will cost you ${quest.cost.toInt()} gold to enter, but you could earn ${quest.reward.toInt()}! Do you accept?";
    _typeOutText(text);
  }

  Future<void> _acceptPendingQuest() async {
    if (_pendingQuest == null) return;
    final state = context.read<GameState>();
    final success = await state.acceptQuest(_pendingQuest!);
    
    if (!mounted) return;
    if (success) {
      _typeOutText("Magnificent! The challenge is set. Complete it within ${_pendingQuest!.durationDays} days!");
      setState(() {
        _pendingQuest = null;
        _showingQuest = false;
      });
    } else {
      _typeOutText("You don't have enough gold for this challenge, traveler. Return when you are more prosperous.");
      setState(() {
        _showingQuest = false;
      });
    }
  }

  Future<void> _loadAssets() async {
    try {
      // Load UI Asset pack
      final uiData = await rootBundle.load(_uiAssetPath);
      final uiCodec = await ui.instantiateImageCodec(uiData.buffer.asUint8List());
      final uiFrame = await uiCodec.getNextFrame();
      
      // Load Lyra Sprite
      final spriteData = await rootBundle.load('assets/images/character_14_frame32x32.png');
      final spriteCodec = await ui.instantiateImageCodec(spriteData.buffer.asUint8List());
      final spriteFrame = await spriteCodec.getNextFrame();

      if (mounted) {
        setState(() {
          _uiAsset = uiFrame.image;
          _spriteSheet = spriteFrame.image;
        });
      }
    } catch (e) {
      developer.log('Failed to load Lyra assets: $e', name: 'LyraDialogBox', error: e);
    }
  }

  void _typeOutText(String text) {
    _typeTimer?.cancel();
    _fullText = text;
    _displayedText = '';
    _isTyping = true;
    _showInput = false;

    int charIndex = 0;
    _typeTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (charIndex >= text.length) {
        timer.cancel();
        setState(() {
          _isTyping = false;
          _showInput = true;
        });
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _inputFocus.requestFocus();
        });
        return;
      }
      setState(() => _displayedText = text.substring(0, ++charIndex));
    });
  }

  void _skipTyping() {
    if (!_isTyping) return;
    _typeTimer?.cancel();
    setState(() {
      _displayedText = _fullText;
      _isTyping = false;
      _showInput = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();
    _history.add({'role': 'user', 'content': text});

    setState(() {
      _isLoading = true;
      _showInput = false;
      _displayedText = '...';
    });

    final state = context.read<GameState>();
    final player = state.player!;

    final reply = await _gemini.chatWithOracle(
      player: player,
      activeBnplCount: state.bnplPlans.length,
      activeLoanCount: state.loans.length,
      currentDay: state.currentDay,
      activeDisaster: state.activeDisaster.toString(),
      chatHistory: List.from(state.chatHistory),
      userMessage: text,
      trustScore: _trustScore,
    );

    state.addChatMessage('user', text);
    state.addChatMessage('lyra', reply);

    if (!mounted) return;
    setState(() => _isLoading = false);
    _typeOutText(reply);
  }

  Future<void> _close() async {
    _inputFocus.unfocus();
    await _slideController.reverse();
    widget.onClose();
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _slideController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: _isTyping ? _skipTyping : null,
          child: _buildLetterBox(context),
        ),
      ),
    );
  }

  Widget _buildLetterBox(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFFCF5E5), // Light parchment yellow
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4C4A8), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ── Content Layout ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lyra Sprite Portrait
                _buildLyraPortrait(),
                const SizedBox(width: 20),
                // Text Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderInfo(),
                      const SizedBox(height: 8),
                      Expanded(child: _buildTypewriterText()),
                      if (_showingQuest) _buildQuestButtons()
                      else if (_showInput == true) _buildInputRow(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryLog() {
    final state = context.read<GameState>();
    showDialog(
      context: context,
      builder: (context) => _WisdomLogDialog(
        chatHistory: state.chatHistory,
        uiAsset: _uiAsset,
        spriteSheet: _spriteSheet,
        playerName: state.player?.displayName ?? 'Farmer',
      ),
    );
  }

  Widget _buildLyraPortrait() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFE8D5B0),
        borderRadius: BorderRadius.circular(50), // Circular like the screenshot
        border: Border.all(color: const Color(0xFFD4C4A8), width: 2),
      ),
      child: ClipOval(
        child: _spriteSheet != null
            ? CustomPaint(
                painter: _StaticSpritePainter(image: _spriteSheet!, frameSizePx: 32),
              )
            : const Center(child: Text('🧙‍♀️', style: TextStyle(fontSize: 40))),
      ),
    );
  }

  /// Large RPG-style portrait that overlaps the box.
  Widget _buildLargePortrait() {
    return SizedBox(
      width: 160,
      height: 220,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_spriteSheet != null)
            CustomPaint(
              size: const Size(160, 220),
              painter: _LargePortraitPainter(image: _spriteSheet!, frameSizePx: 32),
            )
          else
            const Center(child: Text('🧙‍♀️', style: TextStyle(fontSize: 80))),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_spriteSheet != null)
              SizedBox(
                width: 16,
                height: 16,
                child: CustomPaint(
                  painter: _StaticSpritePainter(image: _spriteSheet!, frameSizePx: 32),
                ),
              )
            else if (_uiAsset != null)
              SizedBox(
                width: 14,
                height: 14,
                child: CustomPaint(
                  painter: _AssetIconPainter(image: _uiAsset!),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              "FROM THE DESK OF LYRA",
              style: GoogleFonts.cinzel(
                color: const Color(0xFF5D4037).withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            // History Button
            IconButton(
              icon: Icon(Icons.menu_book, size: 16, color: const Color(0xFF5D4037).withValues(alpha: 0.7)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _showHistoryLog,
              tooltip: 'Wisdom Log',
            ),
          ],
        ),
        Container(
          height: 1,
          width: 120,
          color: const Color(0xFF5D4037).withValues(alpha: 0.3),
        ),
      ],
    );
  }

  /// The main text display, aligned to paper lines.
  Widget _buildTypewriterText() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 4), // Tiny adjustment for line alignment
        child: Text(
          _displayedText,
          style: GoogleFonts.indieFlower(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            height: 1.85, // Refined height for better line matching
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFF5D4037).withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocus,
              enabled: !_isLoading,
              style: GoogleFonts.indieFlower(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'thy reply...',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF5D4037), size: 18),
            onPressed: _sendMessage,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFFD32F2F), size: 18),
            onPressed: _close,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC5A021),
              foregroundColor: Colors.white,
              textStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
            ),
            onPressed: _acceptPendingQuest,
            child: const Text("Accept Challenge"),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () {
              _typeOutText("No worries! We can just chat instead.");
              setState(() => _showingQuest = false);
            },
            child: Text("Maybe Later", style: GoogleFonts.cinzel(color: Colors.red.shade800)),
          ),
        ],
      ),
    );
  }
}

/// Paints the lined paper from the "Paper tiles" section of the asset.
class _LetterPaperPainter extends CustomPainter {
  final ui.Image image;
  const _LetterPaperPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinate estimation for the lined paper in "Paper tiles"
    // Usually these are 48x48 or 64x64 blocks.
    // Based on the image, "Paper tiles" starts around middle right.
    // Let's use the one at ~ (544, 32) with size ~ 64x64 or similar
    
    // Notebook paper with lines source rect
    final src = Rect.fromLTWH(544, 32, 64, 64); 
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Draw the main paper background (stretched to fit)
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints a "stamp" frame from the "postage stamps" section.
class _StampFramePainter extends CustomPainter {
  final ui.Image image;
  const _StampFramePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    // Postage stamps section is around middle.
    // Using one of the stamp frames.
    final src = Rect.fromLTWH(448, 400, 32, 32); 
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LargePortraitPainter extends CustomPainter {
  final ui.Image image;
  final int frameSizePx;
  const _LargePortraitPainter({required this.image, required this.frameSizePx});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Lyra frame 0 (idle front)
    final src = Rect.fromLTWH(0, 0, frameSizePx.toDouble(), frameSizePx.toDouble());
    
    // Position it slightly offset and large
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Draw with high quality but pixelated look
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AssetIconPainter extends CustomPainter {
  final ui.Image image;
  const _AssetIconPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    // Picking a "crystal/magical" icon from the icons section
    // Coordinate estimation: roughly x=752, y=368 for a small icon
    final src = Rect.fromLTWH(752, 368, 16, 16); 
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StaticSpritePainter extends CustomPainter {
  final ui.Image image;
  final int frameSizePx;
  const _StaticSpritePainter({required this.image, required this.frameSizePx});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, frameSizePx.toDouble(), frameSizePx.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = ui.FilterQuality.none);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BookPainter extends CustomPainter {
  final ui.Image image;
  _BookPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    // Open book in UI books & more.png is at top left (0,0 to 128,64 roughly)
    final src = Rect.fromLTWH(0, 0, 128, 64);
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = ui.FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WisdomLogDialog extends StatelessWidget {
  final List<Map<String, String>> chatHistory;
  final ui.Image? uiAsset;
  final ui.Image? spriteSheet;
  final String playerName;

  const _WisdomLogDialog({
    required this.chatHistory,
    this.uiAsset,
    this.spriteSheet,
    required this.playerName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 600,
        height: 450,
        decoration: BoxDecoration(
          color: const Color(0xFFF4E4BC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF5D4037), width: 4),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            // Removed book background overlay
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'WISDOM LOG',
                        style: GoogleFonts.cinzel(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: const Color(0xFF5D4037),
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF5D4037), size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF5D4037), thickness: 2),
                  const SizedBox(height: 10),
                  Expanded(
                    child: chatHistory.isEmpty
                      ? Center(
                          child: Text(
                            "The pages are yet blank... ask Lyra for guidance.",
                            style: GoogleFonts.almendra(fontSize: 18, fontStyle: FontStyle.italic),
                          ),
                        )
                      : ListView.builder(
                          itemCount: chatHistory.length,
                          itemBuilder: (context, index) {
                            final msg = chatHistory[index];
                            final isUser = msg['role'] == 'user';
                            return _buildMessageRow(isUser, msg['content'] ?? '', playerName);
                          },
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(bool isUser, String content, String playerName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(isUser),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? playerName.toUpperCase() : 'LYRA',
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.bold, 
                    color: const Color(0xFFC5A021),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.indieFlower(
                    fontSize: 17, 
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(bool isUser) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE8D5B0), 
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF5D4037), width: 1),
      ),
      child: isUser
        ? ClipOval(
            child: FutureBuilder<ui.Image>(
              future: _loadCatAsset(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return CustomPaint(painter: _StaticSpritePainter(image: snapshot.data!, frameSizePx: 32));
                }
                return const Center(child: Text('🐱', style: TextStyle(fontSize: 22)));
              },
            ),
          )
        : ClipOval(
            child: spriteSheet != null
              ? CustomPaint(painter: _StaticSpritePainter(image: spriteSheet!, frameSizePx: 32))
              : const Center(child: Text('Lyra', style: TextStyle(fontSize: 10))),
          ),
    );
  }

  Future<ui.Image> _loadCatAsset() async {
    final data = await rootBundle.load('assets/images/cat_walk.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
