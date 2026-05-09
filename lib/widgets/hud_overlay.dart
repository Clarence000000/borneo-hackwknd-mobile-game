import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/models/weather_event.dart';
import 'package:farm_fintech/screens/bank_screen.dart';
import 'package:farm_fintech/screens/profile_screen.dart';
import 'package:farm_fintech/screens/merchant_screen.dart';
import 'package:farm_fintech/screens/leaderboard_screen.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/widgets/financial_advisor.dart';
import 'package:farm_fintech/widgets/oracle_chat_dialog.dart';
import 'package:farm_fintech/services/gemini_service.dart';
import 'package:farm_fintech/widgets/handbook_widget.dart';

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

class HudOverlay extends StatefulWidget {
  final bool showTools;
  const HudOverlay({super.key, this.showTools = true});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  String? _displayCountry;
  bool _isToolsExpanded = false;
  bool _isTopUiHidden = false;

  void _showMessage(String title, String message, {String? highlight}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 100, left: 40, right: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF4E4BC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5D4037), width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                const Positioned(top: 4, left: 4, child: Icon(Icons.auto_awesome, size: 12, color: Color(0xFF5D4037))),
                const Positioned(top: 4, right: 4, child: Icon(Icons.auto_awesome, size: 12, color: Color(0xFF5D4037))),
                const Positioned(bottom: 4, left: 4, child: Icon(Icons.auto_awesome, size: 12, color: Color(0xFF5D4037))),
                const Positioned(bottom: 4, right: 4, child: Icon(Icons.auto_awesome, size: 12, color: Color(0xFF5D4037))),
                
                Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF5D4037)),
                        ),
                        const Divider(color: Color(0xFF5D4037), thickness: 2),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10)),
                            children: _buildHighlightedMessage(message, highlight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  List<InlineSpan> _buildHighlightedMessage(String message, String? highlight) {
    if (highlight == null || !message.contains(highlight)) {
      return [TextSpan(text: message)];
    }
    final parts = message.split(highlight);
    return [
      TextSpan(text: parts[0]),
      TextSpan(text: highlight, style: const TextStyle(color: Color(0xFFC5A021), fontWeight: FontWeight.w900, fontSize: 20)),
      TextSpan(text: parts[1]),
    ];
  }

  void _showNextDayNotification(String message) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopRightNotification(
        message: message,
        onFinished: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    const parchmentColor = Color(0xFFF4E4BC);
    const goldColor = Color(0xFFC5A021); // Darker, rich gold

    return Consumer<GameState>(
      builder: (context, state, _) {
        final player = state.player;
        if (player == null) return const SizedBox();

        _displayCountry ??= player.country;
        final displayCountry = _displayCountry ?? player.country;
        final displayCash = _convertCurrency(player.cashBalance, fromCountry: player.country, toCountry: displayCountry);
        final displayBank = _convertCurrency(player.bankBalance, fromCountry: player.country, toCountry: displayCountry);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Stack(
              children: [
                // ── Top UI (Centered & Hidable) ──────────────────
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutBack,
                  top: _isTopUiHidden ? -100 : 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: parchmentColor,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        border: Border.all(color: const Color(0xFF5D4037), width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                              child: _HudChip(
                                children: [
                                  Text(_countryFlags[player.country] ?? '🌏', style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(player.displayName, style: GoogleFonts.cinzel(color: textColor, fontWeight: FontWeight.w900, fontSize: 14)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _HudBadge(
                              icon: Icons.calendar_month,
                              label: 'Month: ${(state.currentDay - 1) ~/ 30 + 1}',
                              color: Colors.brown.shade800,
                            ),
                            const SizedBox(width: 8),
                            _HudBadge(
                              icon: Icons.today,
                              label: 'Day: ${(state.currentDay - 1) % 30 + 1}',
                              color: Colors.brown.shade800,
                            ),
                            const SizedBox(width: 8),
                            _HudBadge(
                              icon: Icons.access_time,
                              label: 'Rent in ${state.daysUntilNextRent}d',
                              color: Colors.red.shade900,
                            ),
                            const SizedBox(width: 12),
                            _HudBadge(icon: Icons.monetization_on, label: CurrencyUtil.format(displayCash, displayCountry), color: Colors.orange.shade900),
                            const SizedBox(width: 8),
                            if (player.bankRegistered)
                              _HudBadge(icon: Icons.account_balance, label: CurrencyUtil.format(displayBank, displayCountry), color: Colors.green.shade900),
                            const SizedBox(width: 12),
                            _CreditScoreBadge(score: player.creditScore),
                            const SizedBox(width: 12),
                            _HudBadge(icon: _weatherIcon(state.activeDisaster), label: _weatherLabel(state.activeDisaster), color: _weatherColor(state.activeDisaster)),
                            const SizedBox(width: 8),
                            _HudBadge(
                              icon: state.isDaytime ? Icons.wb_sunny : Icons.nightlight_round,
                              label: '${state.dayPhaseLabel} ${_formatCountdown(state.remainingCycleSeconds)}',
                              color: state.isDaytime ? Colors.orange.shade800 : Colors.blue.shade900,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Top UI Toggle Button
                Positioned(
                  top: _isTopUiHidden ? 0 : 65,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTopUiHidden = !_isTopUiHidden),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: parchmentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF5D4037), width: 2),
                        ),
                        child: Icon(
                          _isTopUiHidden ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                          color: const Color(0xFF5D4037),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Bottom Right: Unified Tools Menu ──────────
                if (widget.showTools)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Expanded Tools Bar (Vertical Extension)
                      if (_isToolsExpanded)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          width: 100,
                          decoration: BoxDecoration(
                            color: parchmentColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: textColor, width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(4, 4)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Next Day with Count
                              _ToolIcon(
                                icon: Icons.skip_next,
                                label: 'Next Day',
                                sublabel: 'Free ${state.freeNextDayRemaining}/$kFreeManualNextDayPerRealDay',
                                sublabel2: 'Then ',
                                sublabelValue: '${kManualNextDayCost.toStringAsFixed(0)}',
                                sublabelColor: goldColor,
                                color: Colors.brown.shade800,
                                onTap: () {
                                  state.advanceDay().then((ok) {
                                    if (ok) {
                                      _showNextDayNotification('Day ${state.currentDay} Begins');
                                    } else if (context.mounted) {
                                      final cost = kManualNextDayCost.toStringAsFixed(0);
                                      _showMessage('Exhausted', 'No free Next Day left today. Need $cost currency.', highlight: cost);
                                    }
                                  });
                                },
                              ),
                              _toolDivider(horizontal: true),
                              // 2. Fertilizer (Below Next Day)
                              _ToolIcon(
                                icon: Icons.science,
                                label: 'Fertilize',
                                sublabel: '${state.fertilizerPackCount} packs',
                                color: Colors.blue.shade900,
                                onTap: () {
                                  state.useFertilizerPack().then((boostedCount) {
                                    if (boostedCount > 0) {
                                      _showMessage('Alchemy!', 'Used 1 Fertilizer Pack. Boosted $boostedCount crops by +1 stage.');
                                    } else if (boostedCount == 0) {
                                      _showMessage('Patience', 'No growing crops to fertilize right now.');
                                    } else {
                                      _showMessage('Empty', 'No Fertilizer Pack available in your scroll.');
                                    }
                                  });
                                },
                              ),
                              _toolDivider(horizontal: true),
                              _ToolIcon(
                                icon: Icons.workspace_premium, // Rank Icon
                                label: 'Rank',
                                color: Colors.amber.shade900,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaderboardScreen(player: player))),
                              ),
                              _toolDivider(horizontal: true),
                              _ToolIcon(
                                icon: Icons.menu_book,
                                label: 'Handbook',
                                color: Colors.amber.shade800,
                                onTap: () => HandbookWidget.show(context),
                              ),
                              _toolDivider(horizontal: true),
                              _ToolIcon(
                                icon: Icons.auto_fix_high,
                                label: 'Teleport',
                                color: Colors.indigo.shade900,
                                onTap: () => _showTeleportDialog(context, state),
                              ),
                              if (state.tractorOwned) ...[
                                _toolDivider(horizontal: true),
                                _ToolIcon(
                                  icon: state.autoHarvestEnabled ? Icons.agriculture : Icons.agriculture_outlined,
                                  label: 'Tractor',
                                  color: state.autoHarvestEnabled ? Colors.green.shade700 : Colors.grey.shade700,
                                  onTap: () => state.setAutoHarvestEnabled(!state.autoHarvestEnabled),
                                ),
                              ],
                              _toolDivider(horizontal: true),
                              _ToolIcon(
                                icon: state.isCameraFollow ? Icons.zoom_in : Icons.fullscreen,
                                label: state.isCameraFollow ? 'Zoom' : 'Full',
                                color: Colors.teal.shade900,
                                onTap: () => state.toggleCameraFollow(),
                              ),
                              _toolDivider(horizontal: true),
                                _ToolIcon(
                                  icon: Icons.warning_amber,
                                  label: 'Chaos',
                                  color: Colors.deepPurple.shade600, // Brighter purple
                                  onTap: () => _showDisasterDialog(context, state),
                                ),
                                _toolDivider(horizontal: true),
                                _ToolIcon(
                                  icon: Icons.terminal,
                                  label: 'Dev Tools',
                                  color: Colors.blueGrey.shade800,
                                  onTap: () => _showDevToolsDialog(context, state),
                                ),
                                _toolDivider(horizontal: true),
                                _ToolIcon(
                                  icon: Icons.psychology,
                                  label: 'AI Test',
                                  color: Colors.purple.shade800,
                                  onTap: () => _showAiTestDialog(context, state),
                                ),
                            ],
                          ),
                        ),

                      // Toggle Button
                      GestureDetector(
                        onTap: () => setState(() => _isToolsExpanded = !_isToolsExpanded),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5D4037),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFF4E4BC), width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(2, 2)),
                            ],
                          ),
                          child: Icon(_isToolsExpanded ? Icons.close : Icons.handyman, color: const Color(0xFFF4E4BC), size: 32),
                        ),
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

  Widget _toolDivider({bool horizontal = false}) {
    if (horizontal) return Container(height: 2, width: 60, color: Colors.brown.withOpacity(0.2), margin: const EdgeInsets.symmetric(vertical: 8));
    return Container(width: 2, height: 30, color: Colors.brown.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 12));
  }

  void _showTeleportDialog(BuildContext context, GameState state) {
    const textColor = Color(0xFF2D1B10);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF5D4037), width: 4)),
        title: Text('Teleportation', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Where shall the winds carry you?', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
            const SizedBox(height: 16),
            _teleportOption('City Hall', Icons.location_city, () => state.game?.teleport('city_hall')),
            _teleportOption('My Home', Icons.home, () => state.game?.teleport('home')),
            _teleportOption('Farmland', Icons.agriculture, () => state.game?.teleport('farmland')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.cinzel(color: Colors.grey.shade700, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _teleportOption(String label, IconData icon, VoidCallback onSelected) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF5D4037)),
      title: Text(label, style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
      onTap: () {
        onSelected();
        Navigator.pop(context);
        _showMessage('Teleport', 'You have arrived at $label.');
      },
    );
  }

  void _showDisasterDialog(BuildContext context, GameState state) {
    const textColor = Color(0xFF2D1B10);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF5D4037), width: 4)),
        title: Text('Trigger Chaos', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, color: textColor)),
        content: Text(
          'Choose a disaster to test your farm:\n'
          '• Flood: 100% destruction\n'
          '• Storm: 70% destruction\n'
          '• Drought: Downgrade to sprout stage',
          style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
        ),
        actions: [
          _disasterButton('Flood', Colors.blue.shade900, () => state.triggerDisaster(DisasterType.flood)),
          _disasterButton('Storm', Colors.red.shade900, () => state.triggerDisaster(DisasterType.storm)),
          _disasterButton('Drought', Colors.orange.shade900, () => state.triggerDisaster(DisasterType.drought)),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.cinzel(color: Colors.grey.shade700, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showDevToolsDialog(BuildContext context, GameState state) {
    const textColor = Color(0xFF2D1B10);
    int skipDays = 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFFF4E4BC),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF5D4037), width: 3)),
          title: Text('Developer Tools', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, color: textColor)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Realm administration options.', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
                const Divider(color: Color(0xFF5D4037)),
                
                // --- Skip Days Section ---
                Text('Skip Game Days: $skipDays', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                Slider(
                  value: skipDays.toDouble(),
                  min: 1,
                  max: 90,
                  divisions: 89,
                  activeColor: const Color(0xFF5D4037),
                  inactiveColor: const Color(0xFF5D4037).withOpacity(0.2),
                  onChanged: (val) => setState(() => skipDays = val.toInt()),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      state.devSkipDays(skipDays);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: const Color(0xFFF4E4BC)),
                    child: Text('SKIP $skipDays DAYS', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Balance Section ---
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => state.devAddMoney(1000),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade900, foregroundColor: const Color(0xFFF4E4BC)),
                        child: Text('+1000 CASH', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => state.devRemoveMoney(1000),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade900, foregroundColor: const Color(0xFFF4E4BC)),
                        child: Text('-1000 CASH', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => state.devRemoveAllPlants(),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade700, foregroundColor: const Color(0xFFF4E4BC)),
                        child: Text('CLEAR ALL', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => state.devGrowAllCrops(),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: const Color(0xFFF4E4BC)),
                        child: Text('GROW ALL', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => state.devRandomlyPlant(),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade900, foregroundColor: const Color(0xFFF4E4BC)),
                        child: Text('RANDOM PLANT', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => state.devHarvestAll(),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade900, foregroundColor: const Color(0xFFF4E4BC)),
                        child: Text('HARVEST ALL', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => state.devSetMaxCredit(),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: const Color(0xFFF4E4BC)),
                    child: Text('MAX CREDIT SCORE', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),

                // --- Reset Section ---
                const Divider(color: Color(0xFF5D4037)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _confirmReset(context, state),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: const Color(0xFFF4E4BC)),
                    child: Text('RESET GAME (WIPE ALL)', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiTestDialog(BuildContext context, GameState state) {
    const textColor = Color(0xFF2D1B10);
    final player = state.player;
    if (player == null) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF5D4037), width: 3),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/character_14_frame32x32.png',
              width: 32,
              height: 32,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, __, ___) => const Text('🧙', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 10),
            Text('AI Testing', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, color: textColor)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trigger any AI popup for debugging. Each calls Gemini in real-time.',
                style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
              ),
              const Divider(color: Color(0xFF5D4037)),
              const SizedBox(height: 8),
              _aiTestButton(
                context,
                icon: 'assets/images/character_14_frame32x32.png',
                label: '🏦 Warn Loan',
                subtitle: 'Lyra warns about risky loan',
                onTap: () {
                  Navigator.pop(context);
                  FinancialAdvisor.forceWarnLoan(context, player);
                },
              ),
              _aiTestButton(
                context,
                icon: 'assets/images/character_14_frame32x32.png',
                label: '📦 Warn BNPL',
                subtitle: 'Lyra warns about BNPL overuse',
                onTap: () {
                  Navigator.pop(context);
                  FinancialAdvisor.forceWarnBnpl(context, player);
                },
              ),
              _aiTestButton(
                context,
                icon: 'assets/images/character_14_frame32x32.png',
                label: '🛡️ Suggest Insurance',
                subtitle: 'Lyra suggests crop insurance',
                onTap: () {
                  Navigator.pop(context);
                  FinancialAdvisor.forceSuggestInsurance(context, player);
                },
              ),
              _aiTestButton(
                context,
                icon: 'assets/images/character_14_frame32x32.png',
                label: '🔮 Danger Analysis',
                subtitle: 'Full financial danger scan',
                onTap: () {
                  Navigator.pop(context);
                  FinancialAdvisor.forceDangerAnalysis(
                    context,
                    player,
                    bnplCount: state.bnplPlans.length,
                    loanCount: state.loans.length,
                    currentDay: state.currentDay,
                    activeDisaster: state.activeDisaster.toString(),
                  );
                },
              ),
              _aiTestButton(
                context,
                icon: 'assets/images/character_14_frame32x32.png',
                label: '💬 Oracle Chat',
                subtitle: 'Open freeform chat with Lyra',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    barrierColor: Colors.black.withValues(alpha: 0.5),
                    builder: (_) => OracleChatDialog(
                      initialTrustScore: (player.creditScore / 850 * 100).toInt(),
                      initialWarning: '',
                      isDangerous: false,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _aiTestButton(BuildContext context, {
    required String icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8D5B0).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4C4A8)),
            ),
            child: Row(
              children: [
                Image.asset(
                  icon,
                  width: 28,
                  height: 28,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, __, ___) => const Text('🧙', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: GoogleFonts.cinzel(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2D1B10),
                        fontSize: 13,
                      )),
                      Text(subtitle, style: GoogleFonts.almendra(
                        color: const Color(0xFF5D4037),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      )),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF5D4037), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, GameState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.red, width: 4)),
        title: Text('⚠ SERIOUS WARNING', style: GoogleFonts.cinzel(color: Colors.red.shade900, fontWeight: FontWeight.w900)),
        content: Text(
          'This will permanently WIPE your day progress, cash, bank balance, BNPL debts, and inventory. This action CANNOT be undone.',
          style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10), fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ABORT', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              state.devResetGame();
              Navigator.pop(ctx); // Close warning
              Navigator.pop(context); // Close Dev Tools
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: const Color(0xFFF4E4BC)),
            child: Text('YES, WIPE EVERYTHING', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _disasterButton(String label, Color color, VoidCallback onTrigger) {
    return TextButton(
      onPressed: () { onTrigger(); Navigator.pop(context); },
      child: Text(label, style: GoogleFonts.cinzel(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
    );
  }

  double _convertCurrency(double amount, {required String fromCountry, required String toCountry}) {
    final fromRate = _currencyToUsdRate[fromCountry];
    final toRate = _currencyToUsdRate[toCountry];
    if (fromRate == null || toRate == null || fromRate == 0) return amount;
    return (amount * fromRate) / toRate;
  }

  String _formatCountdown(int seconds) {
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  IconData _weatherIcon(dynamic disaster) {
    switch (disaster.toString()) {
      case 'DisasterType.flood': return Icons.water;
      case 'DisasterType.storm': return Icons.flash_on;
      case 'DisasterType.drought': return Icons.local_fire_department;
      default: return Icons.cloud;
    }
  }

  String _weatherLabel(dynamic disaster) {
    switch (disaster.toString()) {
      case 'DisasterType.flood': return 'Flood!';
      case 'DisasterType.storm': return 'Storm!';
      case 'DisasterType.drought': return 'Drought!';
      default: return 'Clear';
    }
  }

  Color _weatherColor(dynamic disaster) {
    switch (disaster.toString()) {
      case 'DisasterType.flood': return Colors.blue.shade900;
      case 'DisasterType.storm': return Colors.red.shade900;
      case 'DisasterType.drought': return Colors.orange.shade900;
      default: return const Color(0xFF2D1B10).withOpacity(0.6);
    }
  }
}

class _TopRightNotification extends StatefulWidget {
  final String message;
  final VoidCallback onFinished;
  const _TopRightNotification({required this.message, required this.onFinished});

  @override
  State<_TopRightNotification> createState() => _TopRightNotificationState();
}

class _TopRightNotificationState extends State<_TopRightNotification> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _offsetAnimation = Tween<Offset>(begin: const Offset(1.5, 0), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 20,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4E4BC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF5D4037), width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(4, 4))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wb_sunny, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(widget.message, style: GoogleFonts.cinzel(color: const Color(0xFF2D1B10), fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final List<Widget> children;
  const _HudChip({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _HudBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HudBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.cinzel(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }
}

  void _showAiTestDialog(BuildContext context, GameState state) {
    final player = state.player;
    if (player == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC), // Parchment
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF5D4037), width: 3),
        ),
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Color(0xFF5D4037), size: 28),
            const SizedBox(width: 8),
            Text(
              'AI TESTING',
              style: GoogleFonts.cinzel(
                color: const Color(0xFF5D4037),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trigger AI interactions manually:',
              style: GoogleFonts.almendra(
                color: const Color(0xFF5D4037),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAiTestButton(
              context,
              icon: Icons.money_off,
              label: 'Warn: Bad Loan',
              onTap: () {
                Navigator.pop(ctx);
                FinancialAdvisor.forceWarnLoan(context, player);
              },
            ),
            _buildAiTestButton(
              context,
              icon: Icons.shopping_cart_checkout,
              label: 'Warn: BNPL Overload',
              onTap: () {
                Navigator.pop(ctx);
                FinancialAdvisor.forceWarnBnpl(context, player);
              },
            ),
            _buildAiTestButton(
              context,
              icon: Icons.shield,
              label: 'Suggest: Insurance',
              onTap: () {
                Navigator.pop(ctx);
                FinancialAdvisor.forceSuggestInsurance(context, player);
              },
            ),
            _buildAiTestButton(
              context,
              icon: Icons.warning,
              label: 'Force Danger Analysis',
              onTap: () {
                Navigator.pop(ctx);
                FinancialAdvisor.forceDangerAnalysis(
                  context,
                  player,
                  bnplCount: 5,
                  loanCount: 2,
                  currentDay: state.currentDay,
                  activeDisaster: state.activeDisaster.toString(),
                );
              },
            ),
            _buildAiTestButton(
              context,
              icon: Icons.chat,
              label: 'Open Oracle Chat',
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  barrierColor: Colors.black.withValues(alpha: 0.5),
                  builder: (_) => OracleChatDialog(
                    initialTrustScore: 75,
                    initialWarning: '',
                    isDangerous: false,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CLOSE',
              style: GoogleFonts.cinzel(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTestButton(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5D4037),
          foregroundColor: const Color(0xFFF4E4BC),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 14)),
        onPressed: onTap,
      ),
    );
  }

class _CreditScoreBadge extends StatelessWidget {
  final int score;
  const _CreditScoreBadge({required this.score});

  Color get _color {
    if (score >= 700) return Colors.green.shade900;
    if (score >= 550) return Colors.orange.shade900;
    return Colors.red.shade900;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = ((score - 300) / 550).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 30, height: 18, child: CustomPaint(painter: _SemiGaugePainter(progress: normalized, color: _color))),
          const SizedBox(width: 8),
          Text('$score', style: GoogleFonts.cinzel(color: _color, fontWeight: FontWeight.w900, fontSize: 12)),
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
    final basePaint = Paint()..color = color.withOpacity(0.2)..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    final progressPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi, false, basePaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _SemiGaugePainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

class _ToolIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final String? sublabel2;
  final String? sublabelValue;
  final Color? sublabelColor;
  final Color color;
  final VoidCallback onTap;

  const _ToolIcon({
    required this.icon, 
    required this.label, 
    this.sublabel, 
    this.sublabel2, 
    this.sublabelValue, 
    this.sublabelColor, 
    required this.color, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.cinzel(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          if (sublabel != null)
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.almendra(color: color.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: sublabel!),
                  if (sublabel2 != null) TextSpan(text: '\n${sublabel2!}'),
                  if (sublabelValue != null) 
                    TextSpan(
                      text: sublabelValue!,
                      style: TextStyle(color: sublabelColor ?? color, fontWeight: FontWeight.w900),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
