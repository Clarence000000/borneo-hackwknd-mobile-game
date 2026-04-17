import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/financial/bnpl_plan.dart';
import 'package:farm_fintech/models/financial/transaction.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/utils/currency_util.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<List<Transaction>>? _transactionsFuture;
  String? _transactionsUid;

  Future<List<Transaction>> _fetchTransactions(String uid) async {
    final docs = await FirestoreService()
        .getDb()
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return docs.docs
        .map((doc) => Transaction.fromMap(doc.id, doc.data()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      appBar: AppBar(
        title: const Text('📝 Player Profile'),
        backgroundColor: GameColors.merchantRoof,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<GameState>(
        builder: (context, state, _) {
          final player = state.player;
          if (player == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_transactionsUid != player.uid || _transactionsFuture == null) {
            _transactionsUid = player.uid;
            _transactionsFuture = _fetchTransactions(player.uid);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Profile Info ─────────────────────
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: GameColors.uiAccent,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: GameColors.uiBackground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            player.country,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            player.displayName,
                            style: const TextStyle(
                              color: GameColors.uiText,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Member since: ${player.createdAt.toString().split(' ')[0]}',
                        style: const TextStyle(
                          color: GameColors.uiTextDim,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Financial Overview ────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Cash',
                        value: CurrencyUtil.format(
                          player.cashBalance,
                          player.country,
                        ),
                        icon: Icons.money,
                        color: GameColors.uiGold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Bank',
                        value: player.bankRegistered
                            ? CurrencyUtil.format(
                                player.bankBalance,
                                player.country,
                              )
                            : 'Unregistered',
                        icon: Icons.account_balance,
                        color: GameColors.uiGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Net Worth',
                        value: CurrencyUtil.format(
                          player.totalNetWorth,
                          player.country,
                        ),
                        icon: Icons.pie_chart,
                        color: GameColors.uiHighlight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Credit Score',
                        value: player.creditScore.toString(),
                        icon: Icons.speed,
                        color: player.creditScore >= 700
                            ? GameColors.uiGreen
                            : (player.creditScore >= 550
                                  ? GameColors.uiGold
                                  : GameColors.uiRed),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Active BNPL Plans ────────────────────
                const Text(
                  'Active BNPL Plans',
                  style: TextStyle(
                    color: GameColors.uiText,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                if (state.bnplPlans.isEmpty)
                  const Text(
                    'No active BNPL plans.',
                    style: TextStyle(color: GameColors.uiTextDim),
                  ),
                if (state.bnplPlans.isNotEmpty)
                  ...state.bnplPlans.map(
                    (plan) => _BnplTile(
                      plan: plan,
                      playerCountry: player.country,
                      currentDay: state.currentDay,
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Recent Transactions ──────────────────
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    color: GameColors.uiText,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Transaction>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text(
                        'Error loading transactions.',
                        style: TextStyle(color: GameColors.uiRed),
                      );
                    }
                    final transactions = snapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return const Text(
                        'No recent transactions.',
                        style: TextStyle(color: GameColors.uiTextDim),
                      );
                    }
                    return Column(
                      children: transactions
                          .take(5)
                          .map(
                            (tx) => _TransactionTile(
                              tx: tx,
                              playerCountry: player.country,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.uiPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: GameColors.uiTextDim,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _BnplTile extends StatelessWidget {
  final BnplPlan plan;
  final String playerCountry;
  final int currentDay;

  const _BnplTile({
    required this.plan,
    required this.playerCountry,
    required this.currentDay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: plan.isOverdueAtGameDay(currentDay)
            ? GameColors.uiRed.withValues(alpha: 0.15)
            : GameColors.uiPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: plan.isOverdueAtGameDay(currentDay)
              ? GameColors.uiRed.withValues(alpha: 0.5)
              : GameColors.uiAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.itemName,
                style: const TextStyle(
                  color: GameColors.uiText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${plan.paidInstallments}/${plan.installments} paid',
                style: const TextStyle(
                  color: GameColors.uiTextDim,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${CurrencyUtil.format(plan.monthlyAmount, playerCountry)}/mo',
                style: const TextStyle(
                  color: GameColors.uiGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (plan.lateFees > 0)
                Text(
                  'Late fees: ${CurrencyUtil.format(plan.lateFees, playerCountry)}',
                  style: const TextStyle(color: GameColors.uiRed, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  final String playerCountry;

  const _TransactionTile({required this.tx, required this.playerCountry});

  @override
  Widget build(BuildContext context) {
    final isDeposit =
        tx.category == TransactionCategory.bankDeposit ||
        tx.category == TransactionCategory.cropSale;
    final color = isDeposit ? GameColors.uiGreen : GameColors.uiText;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(
          isDeposit ? Icons.add : Icons.remove,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        tx.category.name,
        style: const TextStyle(color: GameColors.uiText),
      ),
      subtitle: Text(
        tx.timestamp.toString().split('.')[0],
        style: const TextStyle(color: GameColors.uiTextDim, fontSize: 11),
      ),
      trailing: Text(
        '${isDeposit ? '+' : '-'}${CurrencyUtil.format(tx.amount, playerCountry)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
