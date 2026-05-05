import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/widgets/book_ui.dart';

class LeaderboardScreen extends StatelessWidget {
  final Player player;

  const LeaderboardScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);

    return BookUI(
      title: '${player.country} Regional Rankings',
      pages: [
        // Page 1: Top Rankings
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('leaderboards')
              .doc(player.country)
              .collection('rankings')
              .orderBy('netWorth', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF5D4037)));
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}", style: GoogleFonts.almendra(color: Colors.red.shade900)));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Text(
                  "No players in this region yet.\nBe the first to get rich!",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.almendra(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final isMe = docs[index].id == player.uid;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF5D4037).withOpacity(0.1) : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMe ? const Color(0xFF5D4037) : const Color(0xFF5D4037).withOpacity(0.3),
                      width: isMe ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _RankBadge(index: index),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['displayName'] ?? 'Unknown Farmer',
                              style: GoogleFonts.cinzel(
                                color: textColor,
                                fontWeight: isMe ? FontWeight.w900 : FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (isMe)
                              Text(
                                'You',
                                style: GoogleFonts.almendra(
                                  color: const Color(0xFF5D4037),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyUtil.format((data["netWorth"] as num?)?.toDouble() ?? 0.0, player.country),
                        style: GoogleFonts.cinzel(
                          color: const Color(0xFF5D4037),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        
        // Page 2: Region Stats / Achievements
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regional Ledger',
              style: GoogleFonts.cinzel(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
            ),
            const Divider(color: Color(0xFF5D4037), thickness: 2),
            const SizedBox(height: 16),
            _StatsRow(label: 'Total Economy', value: 'Billionaire Tier'),
            _StatsRow(label: 'Active Farmers', value: 'Growing'),
            _StatsRow(label: 'Top Export', value: 'Golden Wheat'),
            const Spacer(),
            Center(
              child: Icon(Icons.workspace_premium, size: 80, color: const Color(0xFF5D4037).withOpacity(0.2)),
            ),
            const Spacer(),
            Text(
              'A truly prosperous region, where the soil is rich and the farmers are resilient.',
              textAlign: TextAlign.center,
              style: GoogleFonts.almendra(fontSize: 16, fontStyle: FontStyle.italic, color: textColor),
            ),
          ],
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int index;
  const _RankBadge({required this.index});

  @override
  Widget build(BuildContext context) {
    Color medalColor;
    String label = '${index + 1}';
    
    if (index == 0) {
      medalColor = Colors.amber.shade700;
      label = '👑';
    } else if (index == 1) {
      medalColor = Colors.blueGrey.shade400;
    } else if (index == 2) {
      medalColor = Colors.brown.shade600;
    } else {
      medalColor = const Color(0xFF5D4037).withOpacity(0.5);
    }

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: medalColor,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF4E4BC), width: 2),
      ),
      child: Text(
        label,
        style: GoogleFonts.cinzel(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: index == 0 ? 18 : 14,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatsRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF5D4037))),
          Text(value, style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF2D1B10))),
        ],
      ),
    );
  }
}
