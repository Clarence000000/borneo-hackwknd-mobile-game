import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/widgets/book_ui.dart';

/// Visual-first handbook with illustrations, animations, and minimal text.
class HandbookWidget extends StatelessWidget {
  const HandbookWidget({super.key});

  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      pageBuilder: (dialogCtx, anim1, anim2) => const HandbookWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BookUI(
      title: '📖 Farmer\'s Handbook',
      pages: _buildPages(),
    );
  }

  List<Widget> _buildPages() {
    return [
      // ── Page 1: Welcome ─────────────────────────────────────
      _VisualPage(
        image: 'assets/images/handbook/welcome_guide.png',
        heading: '🌾 Welcome, Farmer!',
        chips: const [
          _InfoChip(icon: Icons.monetization_on, label: 'Start: RM 1,000'),
          _InfoChip(icon: Icons.flag, label: 'Goal: Get Rich!'),
          _InfoChip(icon: Icons.warning, label: 'Pay Rent or Game Over'),
        ],
        hint: 'Build your farm 🌱 → Earn money 💰 → Survive rent day! 🏠',
      ),

      // ── Page 2: How to Farm (Visual Steps) ──────────────────
      _StepByStepPage(
        heading: '🌱 How to Farm',
        steps: const [
          _VisualStep(icon: Icons.directions_walk, emoji: '🚶', title: 'Walk to farmland', sub: 'Brown tiles on the map'),
          _VisualStep(icon: Icons.touch_app, emoji: '👆', title: 'Tap the tile', sub: 'Opens planting menu'),
          _VisualStep(icon: Icons.eco, emoji: '🌿', title: 'Choose a crop', sub: 'Need seeds in inventory'),
          _VisualStep(icon: Icons.skip_next, emoji: '⏩', title: 'Next Day to grow', sub: 'Use toolbar button'),
          _VisualStep(icon: Icons.agriculture, emoji: '🎉', title: 'Harvest!', sub: 'Tap mature golden crops'),
          _VisualStep(icon: Icons.sell, emoji: '💰', title: 'Sell at Merchant', sub: 'Cash goes to wallet'),
        ],
      ),

      // ── Page 3: Crops Visual Guide (Custom Layout) ──────────
      const _CropGuidePage(),

      // ── Page 4: Banking (Custom Credit Bar Layout) ────────
      const _BankingGuidePage(),

      // ── Page 5: BNPL (Custom Debt Warning) ──────────────────
      const _BnplGuidePage(),

      // ── Page 6: Disasters (Custom Detail Cards) ─────────────
      const _DisasterGuidePage(),

      // ── Page 7: Loan Shark Warning ──────────────────────────
      _StepByStepPage(
        heading: '🦈 Danger Zone!',
        steps: const [
          _VisualStep(icon: Icons.dangerous, emoji: '🦈', title: 'Loan Shark', sub: 'Instant RM1,200 cash'),
          _VisualStep(icon: Icons.trending_up, emoji: '📈', title: '35% interest/month', sub: 'Way higher than bank!'),
          _VisualStep(icon: Icons.timer, emoji: '⏰', title: '3 month deadline', sub: 'Or face consequences'),
          _VisualStep(icon: Icons.check_circle, emoji: '✅', title: 'Better: Bank Loan', sub: 'Only 5% interest'),
          _VisualStep(icon: Icons.star, emoji: '⭐', title: 'Best: Save & Earn', sub: 'Farm profits + deposits'),
        ],
      ),

      // ── Page 8: Pro Tips ────────────────────────────────────
      _StepByStepPage(
        heading: '💡 Pro Tips',
        steps: const [
          _VisualStep(icon: Icons.savings, emoji: '💰', title: 'Keep RM500+ reserve', sub: 'Emergency rent fund'),
          _VisualStep(icon: Icons.account_balance, emoji: '🏦', title: 'Register bank ASAP', sub: 'Earn interest daily'),
          _VisualStep(icon: Icons.shield, emoji: '🛡️', title: 'Always insure crops', sub: 'Flood = total loss'),
          _VisualStep(icon: Icons.agriculture, emoji: '🚜', title: 'Buy Tractor early', sub: 'Auto-harvest saves time'),
          _VisualStep(icon: Icons.psychology, emoji: '🔮', title: 'Talk to Lyra Oracle', sub: 'AI financial advisor'),
          _VisualStep(icon: Icons.emoji_events, emoji: '🏆', title: 'Climb Leaderboard!', sub: 'Compete with others'),
        ],
      ),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════
//  Visual Page — Image + Chips + Hint
// ═══════════════════════════════════════════════════════════════

class _VisualPage extends StatelessWidget {
  final String image;
  final String heading;
  final List<_InfoChip> chips;
  final String hint;

  const _VisualPage({
    required this.image,
    required this.heading,
    required this.chips,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return SingleChildScrollView(
      child: Column(
        children: [
          // Heading
          Text(heading, style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 12),

          // Illustration
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              image,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF5D4037).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Icon(Icons.image, size: 64, color: Color(0xFF5D4037))),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Info Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
          const SizedBox(height: 16),

          // Animated Hint Banner
          _AnimatedHintBanner(text: hint),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Step-by-Step Page — Numbered visual steps
// ═══════════════════════════════════════════════════════════════

class _StepByStepPage extends StatelessWidget {
  final String heading;
  final List<_VisualStep> steps;

  const _StepByStepPage({required this.heading, required this.steps});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text(heading, style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w900, color: textColor))),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) => _AnimatedStepCard(step: steps[i], index: i, total: steps.length)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Animated Step Card — enters with staggered animation
// ═══════════════════════════════════════════════════════════════

class _VisualStep {
  final IconData icon;
  final String emoji;
  final String title;
  final String sub;
  const _VisualStep({required this.icon, required this.emoji, required this.title, required this.sub});
}

class _AnimatedStepCard extends StatefulWidget {
  final _VisualStep step;
  final int index;
  final int total;
  const _AnimatedStepCard({required this.step, required this.index, required this.total});

  @override
  State<_AnimatedStepCard> createState() => _AnimatedStepCardState();
}

class _AnimatedStepCardState extends State<_AnimatedStepCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    Future.delayed(Duration(milliseconds: 100 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    final isLast = widget.index == widget.total - 1;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step number + connector line
              Column(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF5D4037),
                      border: Border.all(color: const Color(0xFFC5A059), width: 2),
                    ),
                    child: Center(child: Text('${widget.index + 1}', style: GoogleFonts.cinzel(color: const Color(0xFFF4E4BC), fontWeight: FontWeight.w900, fontSize: 14))),
                  ),
                  if (!isLast) Container(width: 3, height: 30, color: const Color(0xFF5D4037).withValues(alpha: 0.3)),
                ],
              ),
              const SizedBox(width: 12),
              // Content card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF5D4037).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(widget.step.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.step.title, style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)),
                            Text(widget.step.sub, style: GoogleFonts.almendra(fontSize: 13, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7))),
                          ],
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Info Chip — Colorful icon + short label
// ═══════════════════════════════════════════════════════════════

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFC5A059).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF5D4037).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF5D4037)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: GoogleFonts.almendra(fontSize: 13, fontWeight: FontWeight.bold, color: textColor))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Animated Hint Banner — pulsing golden tip
// ═══════════════════════════════════════════════════════════════

class _AnimatedHintBanner extends StatefulWidget {
  final String text;
  const _AnimatedHintBanner({required this.text});

  @override
  State<_AnimatedHintBanner> createState() => _AnimatedHintBannerState();
}

class _AnimatedHintBannerState extends State<_AnimatedHintBanner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final glow = 0.1 + 0.15 * _ctrl.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFC5A059).withValues(alpha: glow),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC5A059).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.text,
                  style: GoogleFonts.almendra(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Crop Guide Page — Custom layout with CropCards + Pipeline
// ═══════════════════════════════════════════════════════════════

class _CropGuidePage extends StatelessWidget {
  const _CropGuidePage();

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    const cyanAccent = Color(0xFF00BCD4); // Lyra cyan

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = constraints.maxHeight * 0.30;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Heading ──────────────────────────────────
              Center(
                child: Text(
                  '🌾 Crop Guide',
                  style: GoogleFonts.cinzel(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Compressed Illustration (30%) ───────────
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/handbook/farming_guide.png',
                  height: imageHeight.clamp(80, 160),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: imageHeight.clamp(80, 160),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5D4037).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.image, size: 48, color: Color(0xFF5D4037)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Lyra-style Cyan Divider ──────────────────
              Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cyanAccent.withValues(alpha: 0),
                      cyanAccent.withValues(alpha: 0.7),
                      cyanAccent.withValues(alpha: 0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 12),

              // ── Three CropCards in a Row ─────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(
                      child: _CropCard(
                        emoji: '🌾',
                        name: 'Wheat',
                        buyCost: 10,
                        sellPrice: 20,
                        growDays: 3,
                        accentColor: Color(0xFFD4A017),
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: _CropCard(
                        emoji: '🌿',
                        name: 'Paddy',
                        buyCost: 20,
                        sellPrice: 40,
                        growDays: 5,
                        accentColor: Color(0xFF4CAF50),
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: _CropCard(
                        emoji: '🌽',
                        name: 'Corn',
                        buyCost: 15,
                        sellPrice: 30,
                        growDays: 4,
                        accentColor: Color(0xFFFF9800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Growth Stage Pipeline ───────────────────
              const _GrowthStagePipeline(),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CropCard — Vertical stat card with monospace data
// ═══════════════════════════════════════════════════════════════

class _CropCard extends StatelessWidget {
  final String emoji;
  final String name;
  final int buyCost;
  final int sellPrice;
  final int growDays;
  final Color accentColor;

  const _CropCard({
    required this.emoji,
    required this.name,
    required this.buyCost,
    required this.sellPrice,
    required this.growDays,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    final mono = GoogleFonts.jetBrainsMono(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: textColor.withValues(alpha: 0.85),
      height: 1.6,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crop icon
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          // Crop name
          Text(
            name,
            style: GoogleFonts.cinzel(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          // Divider line
          Container(
            height: 1,
            color: accentColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          // Monospace stats
          Text('Buy:  RM $buyCost', style: mono),
          Text('Sell: RM $sellPrice', style: mono),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '⏱ ${growDays}d',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Growth Stage Pipeline — Animated horizontal flow
// ═══════════════════════════════════════════════════════════════

class _GrowthStagePipeline extends StatefulWidget {
  const _GrowthStagePipeline();

  @override
  State<_GrowthStagePipeline> createState() => _GrowthStagePipelineState();
}

class _GrowthStagePipelineState extends State<_GrowthStagePipeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _stages = [
    _PipeStage(emoji: '●', label: 'Seed', color: Color(0xFF8D6E63)),
    _PipeStage(emoji: '🌱', label: 'Sprout', color: Color(0xFF7CB342)),
    _PipeStage(emoji: '🌿', label: 'Growing', color: Color(0xFF43A047)),
    _PipeStage(emoji: '🌾', label: 'Harvest', color: Color(0xFFD4A017)),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF5D4037).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF5D4037).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            'GROWTH STAGES',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor.withValues(alpha: 0.5),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_stages.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Arrow connector
                return Expanded(
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      return Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _stages[i ~/ 2].color.withValues(alpha: 0.3 + 0.4 * _ctrl.value),
                              _stages[i ~/ 2 + 1].color.withValues(alpha: 0.3 + 0.4 * _ctrl.value),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      );
                    },
                  ),
                );
              }
              // Stage node
              final stage = _stages[i ~/ 2];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stage.color.withValues(alpha: 0.15),
                      border: Border.all(color: stage.color, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        stage.emoji,
                        style: TextStyle(
                          fontSize: stage.emoji == '●' ? 16 : 20,
                          color: stage.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage.label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PipeStage {
  final String emoji;
  final String label;
  final Color color;
  const _PipeStage({required this.emoji, required this.label, required this.color});
}

// ═══════════════════════════════════════════════════════════════
//  Banking Guide Page — Credit Level Bar + Compact Chips
// ═══════════════════════════════════════════════════════════════

class _BankingGuidePage extends StatelessWidget {
  const _BankingGuidePage();

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    final state = context.watch<GameState>();
    final score = state.player?.creditScore ?? 500;

    return LayoutBuilder(
      builder: (context, constraints) {
        final imgH = (constraints.maxHeight * 0.25).clamp(60.0, 130.0);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Heading + Level Up badge ───────────────
              Stack(
                children: [
                  Center(
                    child: Text(
                      '🏦 Banking Made Easy',
                      style: GoogleFonts.cinzel(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                  // Level Up badge in top-right
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _LevelUpBadge(score: score),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Compressed Illustration ───────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/handbook/finance_guide.png',
                  height: imgH,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: imgH,
                    color: const Color(0xFF5D4037).withValues(alpha: 0.1),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // ── Compact Info Chips (smaller) ───────────
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: const [
                  _CompactChip(icon: Icons.app_registration, label: 'Register FREE'),
                  _CompactChip(icon: Icons.savings, label: '1%/day interest'),
                  _CompactChip(icon: Icons.credit_score, label: 'Score 300–850'),
                  _CompactChip(icon: Icons.lock_open, label: '600+ = Loans'),
                ],
              ),
              const SizedBox(height: 14),

              // ── Credit Level Bar ─────────────────────
              _CreditLevelBar(score: score),
              const SizedBox(height: 14),

              // ── Hint Banner ─────────────────────────
              _AnimatedHintBanner(text: 'Every bank transaction improves your credit! 📈'),
            ],
          ),
        );
      },
    );
  }
}

// ─── Compact Chip (smaller than _InfoChip) ───────────────────

class _CompactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CompactChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC5A059).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5D4037).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF5D4037)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Credit Level Bar — 3-segment with dynamic pointer ──────

class _CreditLevelBar extends StatelessWidget {
  final int score;
  const _CreditLevelBar({required this.score});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    const minScore = 300;
    const maxScore = 850;
    const cyanAccent = Color(0xFF00E5FF);
    const segRed = Color(0xFFEF5350);
    const segYellow = Color(0xFFFFC107);

    // Normalized 0..1 position
    final normalized = ((score - minScore) / (maxScore - minScore)).clamp(0.0, 1.0);

    // Determine current level label
    String levelLabel;
    Color levelColor;
    if (score < 550) {
      levelLabel = 'FRAGILE';
      levelColor = segRed;
    } else if (score < 700) {
      levelLabel = 'ROBUST';
      levelColor = segYellow;
    } else {
      levelLabel = 'ANTIFRAGILE';
      levelColor = cyanAccent;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: levelColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Score + Level label header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CREDIT LEVEL',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: textColor.withValues(alpha: 0.5),
                  letterSpacing: 2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: levelColor.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: levelColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  '$score · $levelLabel',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: levelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Progress Bar with pointer ─────────────
          LayoutBuilder(
            builder: (context, barConstraints) {
              final barW = barConstraints.maxWidth;
              final pointerX = (normalized * barW).clamp(8.0, barW - 8);

              return Column(
                children: [
                  // Pointer triangle
                  SizedBox(
                    height: 14,
                    child: Stack(
                      children: [
                        Positioned(
                          left: pointerX - 6,
                          bottom: 0,
                          child: CustomPaint(
                            size: const Size(12, 8),
                            painter: _PointerPainter(color: levelColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 3-segment bar
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: levelColor.withValues(alpha: 0.15),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Row(
                        children: [
                          // Red: 300-550 = (250/550 = 45.45%)
                          Expanded(
                            flex: 2545, // ~250/550 proportion
                            child: Container(color: segRed.withValues(alpha: 0.7)),
                          ),
                          // Yellow: 550-700 = (150/550 = 27.27%)
                          Expanded(
                            flex: 1500,
                            child: Container(color: segYellow.withValues(alpha: 0.7)),
                          ),
                          // Cyan: 700-850 = (150/550 = 27.27%)
                          Expanded(
                            flex: 1500,
                            child: Container(color: cyanAccent.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Segment labels
                  Row(
                    children: [
                      Expanded(
                        flex: 2545,
                        child: Center(
                          child: Text(
                            'Fragile',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: segRed.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1500,
                        child: Center(
                          child: Text(
                            'Robust',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: segYellow.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1500,
                        child: Center(
                          child: Text(
                            'Antifragile',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: cyanAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          // Hint text
          Text(
            'Higher score = Lower interest & Higher loan limit',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.45),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pointer triangle painter ───────────────────────────

class _PointerPainter extends CustomPainter {
  final Color color;
  const _PointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter old) => old.color != color;
}

// ─── Level Up Badge — pulses when crossing threshold ───────

class _LevelUpBadge extends StatefulWidget {
  final int score;
  const _LevelUpBadge({required this.score});

  @override
  State<_LevelUpBadge> createState() => _LevelUpBadgeState();
}

class _LevelUpBadgeState extends State<_LevelUpBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  // Thresholds that trigger "LEVEL UP"
  static const _thresholds = [550, 700];

  bool get _isAtThreshold {
    for (final t in _thresholds) {
      if (widget.score >= t && widget.score < t + 20) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = Tween<double>(begin: 0.9, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (_isAtThreshold) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _LevelUpBadge old) {
    super.didUpdateWidget(old);
    if (_isAtThreshold && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!_isAtThreshold && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAtThreshold) return const SizedBox.shrink();

    const cyanAccent = Color(0xFF00E5FF);
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: cyanAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cyanAccent.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: cyanAccent.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 14, color: cyanAccent),
            const SizedBox(width: 4),
            Text(
              'LEVEL UP!',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: cyanAccent,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BNPL Guide Page — Debt explosion chart + Lyra alert
// ═══════════════════════════════════════════════════════════════

class _BnplGuidePage extends StatelessWidget {
  const _BnplGuidePage();

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    const cyanAccent = Color(0xFF00E5FF);
    const dangerRed = Color(0xFFEF5350);

    return LayoutBuilder(
      builder: (context, constraints) {
        final imgH = (constraints.maxHeight * 0.22).clamp(55.0, 110.0);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Heading
              Center(
                child: Text(
                  '\u26a0\ufe0f BNPL: Be Careful!',
                  style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
              const SizedBox(height: 6),

              // Compressed illustration
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/handbook/bnpl_guide.png',
                  height: imgH,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: imgH, color: const Color(0xFF5D4037).withValues(alpha: 0.1)),
                ),
              ),
              const SizedBox(height: 6),

              // Compact chips row
              Wrap(
                spacing: 6, runSpacing: 4,
                alignment: WrapAlignment.center,
                children: const [
                  _CompactChip(icon: Icons.shopping_cart, label: 'Installments'),
                  _CompactChip(icon: Icons.calendar_month, label: '3mo = 0%'),
                  _CompactChip(icon: Icons.calendar_today, label: '6mo = 5%'),
                ],
              ),
              const SizedBox(height: 12),

              // ── Debt Explosion Chart ────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dangerRed.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: dangerRed.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEBT COMPARISON',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: textColor.withValues(alpha: 0.5), letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // On-time bar
                    _DebtBar(
                      label: 'On-Time (3mo)',
                      amount: 'RM 140',
                      fraction: 0.45,
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 8),
                    // Late bar
                    _DebtBar(
                      label: '1x Late Payment',
                      amount: 'RM 210+',
                      fraction: 0.85,
                      color: dangerRed,
                    ),
                    const SizedBox(height: 8),
                    // 2x late bar
                    _DebtBar(
                      label: '2x Late = DEFAULT',
                      amount: 'RM 350+',
                      fraction: 1.0,
                      color: const Color(0xFFB71C1C),
                      isFlashing: true,
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Late fee: RM23 + 50% penalty per miss',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: dangerRed.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Lyra System Alert ───────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cyanAccent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cyanAccent.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(color: cyanAccent.withValues(alpha: 0.1), blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, size: 18, color: cyanAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SYSTEM ALERT: BNPL induces artificial liquidity. Late payment triggers exponential debt growth.',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, fontWeight: FontWeight.w600,
                          color: cyanAccent, height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Debt Comparison Bar ────────────────────────────────────

class _DebtBar extends StatefulWidget {
  final String label;
  final String amount;
  final double fraction;
  final Color color;
  final bool isFlashing;

  const _DebtBar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
    this.isFlashing = false,
  });

  @override
  State<_DebtBar> createState() => _DebtBarState();
}

class _DebtBarState extends State<_DebtBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    if (widget.isFlashing) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: textColor.withValues(alpha: 0.7))),
            Text(widget.amount, style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900, color: widget.color)),
          ],
        ),
        const SizedBox(height: 3),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final alpha = widget.isFlashing ? (0.5 + 0.5 * _ctrl.value) : 0.8;
            return Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: const Color(0xFF5D4037).withValues(alpha: 0.08),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widget.fraction,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: widget.color.withValues(alpha: alpha),
                    boxShadow: widget.isFlashing
                        ? [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 6)]
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Disaster Guide Page — Detail cards + danger ratings
// ═══════════════════════════════════════════════════════════════

class _DisasterGuidePage extends StatelessWidget {
  const _DisasterGuidePage();

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    const cyanAccent = Color(0xFF00E5FF);

    return LayoutBuilder(
      builder: (context, constraints) {
        final imgH = (constraints.maxHeight * 0.20).clamp(50.0, 100.0);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  '\ud83c\udf2a\ufe0f Weather Disasters',
                  style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
              const SizedBox(height: 6),

              // Compressed illustration
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/handbook/disaster_guide.png',
                  height: imgH,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(height: imgH, color: const Color(0xFF5D4037).withValues(alpha: 0.1)),
                ),
              ),
              const SizedBox(height: 4),

              // Lyra divider
              Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    cyanAccent.withValues(alpha: 0),
                    cyanAccent.withValues(alpha: 0.5),
                    cyanAccent.withValues(alpha: 0),
                  ]),
                ),
              ),
              const SizedBox(height: 8),

              // ── Disaster Detail Cards ───────────────────
              const _DisasterCard(
                emoji: '\ud83c\udf0a',
                name: 'Flood',
                effect: '100% crops destroyed',
                stars: 5,
                estLoss: 'RM 200+',
                advice: 'High-tier insurance essential',
                color: Color(0xFF1565C0),
              ),
              const SizedBox(height: 6),
              const _DisasterCard(
                emoji: '\u26c8\ufe0f',
                name: 'Storm',
                effect: '70% crops destroyed',
                stars: 3,
                estLoss: 'RM 120+',
                advice: 'Basic insurance recommended',
                color: Color(0xFF7B1FA2),
              ),
              const SizedBox(height: 6),
              const _DisasterCard(
                emoji: '\u2600\ufe0f',
                name: 'Drought',
                effect: 'Growth reset to sprout',
                stars: 2,
                estLoss: 'RM 60+',
                advice: 'Delays harvest by days',
                color: Color(0xFFE65100),
              ),
              const SizedBox(height: 10),

              // ── Glowing Insurance CTA ───────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: cyanAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cyanAccent.withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: cyanAccent.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 1),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield, size: 22, color: cyanAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BUY INSURANCE AT BANK',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11, fontWeight: FontWeight.w900,
                              color: cyanAccent, letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '10% disaster chance/day \u2014 survival depends on coverage',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8, fontWeight: FontWeight.w500,
                              color: textColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Disaster Detail Card ───────────────────────────────────

class _DisasterCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String effect;
  final int stars;
  final String estLoss;
  final String advice;
  final Color color;

  const _DisasterCard({
    required this.emoji,
    required this.name,
    required this.effect,
    required this.stars,
    required this.estLoss,
    required this.advice,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Emoji
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.cinzel(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    const SizedBox(width: 6),
                    // Star rating
                    Text(
                      List.generate(stars, (_) => '\u2b50').join(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                Text(
                  effect,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          // Est. Loss
          Column(
            children: [
              Text(
                'Est. Loss',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8, fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.4),
                ),
              ),
              Text(
                estLoss,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12, fontWeight: FontWeight.w900, color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
