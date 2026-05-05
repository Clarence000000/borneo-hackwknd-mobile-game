import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/financial/bnpl_plan.dart';
import 'package:farm_fintech/models/financial/transaction.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/widgets/book_ui.dart';

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
    const textColor = Color(0xFF2D1B10);

    return Consumer<GameState>(
      builder: (context, state, _) {
        final player = state.player;
        if (player == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_transactionsUid != player.uid || _transactionsFuture == null) {
          _transactionsUid = player.uid;
          _transactionsFuture = _fetchTransactions(player.uid);
        }

        final pages = [
          // ── Page 1: Farmer Identity & Cash ────────────────
          Column(
            children: [
              const CircleAvatar(
                radius: 45,
                backgroundColor: Color(0xFF5D4037),
                child: Icon(Icons.person, size: 55, color: Color(0xFFF4E4BC)),
              ),
              const SizedBox(height: 16),
              Text(
                player.displayName,
                style: GoogleFonts.cinzel(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${player.country} Citizen',
                style: GoogleFonts.almendra(
                  color: textColor.withOpacity(0.7),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Registry Date: ${player.createdAt.toLocal().toString().split(' ')[0]}',
                style: GoogleFonts.almendra(
                  color: textColor.withOpacity(0.5),
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),
              _StatRow(
                label: 'Cash in Hand',
                value: CurrencyUtil.format(player.cashBalance, player.country),
                icon: Icons.wallet,
                color: Colors.orange.shade900,
              ),
              const SizedBox(height: 16),
              _StatRow(
                label: 'Vault Balance',
                value: player.bankRegistered
                    ? CurrencyUtil.format(player.bankBalance, player.country)
                    : 'Unregistered',
                icon: Icons.account_balance,
                color: Colors.green.shade900,
              ),
            ],
          ),

          // ── Page 2: Worth & Standing ─────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Standing',
                style: GoogleFonts.cinzel(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 24),
              _StatCard(
                title: 'Total Net Worth',
                value: CurrencyUtil.format(player.totalNetWorth, player.country),
                icon: Icons.stars,
                color: const Color(0xFF5D4037),
              ),
              const SizedBox(height: 20),
              _StatCard(
                title: 'Royal Credit Score',
                value: player.creditScore.toString(),
                icon: Icons.verified_user,
                color: player.creditScore >= 700
                    ? Colors.green.shade900
                    : (player.creditScore >= 550 ? Colors.orange.shade900 : Colors.red.shade900),
              ),
              const SizedBox(height: 32),
              Text(
                'Active BNPL Obligations',
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              if (state.bnplPlans.isEmpty)
                Text(
                  'No active obligations.',
                  style: GoogleFonts.almendra(
                    color: textColor.withOpacity(0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: state.bnplPlans.length,
                    itemBuilder: (context, index) => _BnplTile(
                      plan: state.bnplPlans[index],
                      playerCountry: player.country,
                      currentDay: state.currentDay,
                    ),
                  ),
                ),
            ],
          ),

          // ── Page 3: Transaction Ledger ──────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction Ledger',
                style: GoogleFonts.cinzel(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Transaction>>(
                  future: _transactionsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final transactions = snapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return Center(
                        child: Text(
                          'Ledger is empty.',
                          style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.5)),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) => _TransactionTile(
                        tx: transactions[index],
                        playerCountry: player.country,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ── Page 4: Actions & Settings ──────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Registry Actions',
                style: GoogleFonts.cinzel(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: const Color(0xFFF4E4BC),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFFF4E4BC),
                        title: Text('Sever Ties?', style: GoogleFonts.cinzel(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                        content: Text('Are you sure you wish to leave the realm?', style: GoogleFonts.almendra(fontWeight: FontWeight.bold)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: Text('LOGOUT', style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ];

        return BookUI(
          title: '📜 Farmer Profile',
          pages: pages,
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.almendra(fontSize: 14, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.6))),
            Text(value, style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ],
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
    const textColor = Color(0xFF2D1B10);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
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
                style: GoogleFonts.almendra(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cinzel(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 22,
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
    const textColor = Color(0xFF2D1B10);
    final isOverdue = plan.isOverdueAtGameDay(currentDay);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isOverdue ? Colors.red.shade900 : textColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.itemName, style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 14, color: textColor)),
              Text('${plan.paidInstallments}/${plan.installments} paid', style: GoogleFonts.almendra(fontSize: 12, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7))),
            ],
          ),
          Text(
            CurrencyUtil.format(plan.monthlyAmount, playerCountry),
            style: GoogleFonts.cinzel(color: Colors.orange.shade900, fontWeight: FontWeight.w900),
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
    const textColor = Color(0xFF2D1B10);
    final isDeposit = tx.category == TransactionCategory.bankDeposit || tx.category == TransactionCategory.cropSale;
    final color = isDeposit ? Colors.green.shade900 : textColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: textColor.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(isDeposit ? Icons.add : Icons.remove, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.category.name, style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 13, color: textColor)),
                Text(tx.timestamp.toString().split(' ')[0], style: GoogleFonts.almendra(fontSize: 11, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.6))),
              ],
            ),
          ),
          Text(
            '${isDeposit ? '+' : '-'}${CurrencyUtil.format(tx.amount, playerCountry)}',
            style: GoogleFonts.cinzel(color: color, fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
