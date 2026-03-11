import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/utils/currency_util.dart';

class LeaderboardScreen extends StatelessWidget {
  final Player player;

  const LeaderboardScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      appBar: AppBar(
        title: Text('${player.country} Regional Leaderboard 🏆'),
        backgroundColor: GameColors.uiPanel,
        foregroundColor: GameColors.uiGold,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leaderboards')
            .doc(player.country)
            .collection('rankings')
            .orderBy('netWorth', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: GameColors.uiAccent));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: GameColors.uiRed)));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("No players in this region yet. Be the first to get rich!", style: TextStyle(color: GameColors.uiTextDim)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final isMe = docs[index].id == player.uid;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isMe ? GameColors.uiHighlight.withValues(alpha: 0.2) : GameColors.uiPanel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMe ? GameColors.uiHighlight : GameColors.uiAccent.withValues(alpha: 0.3),
                    width: isMe ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getMedalColor(index),
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(data['displayName'] ?? 'Unknown Farmer', 
                      style: TextStyle(color: GameColors.uiText, fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                  subtitle: isMe ? const Text('You', style: TextStyle(color: GameColors.uiHighlight, fontSize: 12)) : null,
                  trailing: Text(CurrencyUtil.format((data["netWorth"] as num?)?.toDouble() ?? 0.0, player.country), 
                      style: const TextStyle(color: GameColors.uiGold, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getMedalColor(int index) {
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.grey.shade400; // Silver
    if (index == 2) return Colors.brown.shade400; // Bronze
    return GameColors.uiTextDim.withValues(alpha: 0.5);
  }
}
