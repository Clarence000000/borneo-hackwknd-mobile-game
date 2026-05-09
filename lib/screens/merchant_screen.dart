import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/financial/bnpl_plan.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';
import 'package:farm_fintech/widgets/financial_advisor.dart';
import 'package:farm_fintech/utils/currency_util.dart';
import 'package:farm_fintech/widgets/book_ui.dart';

/// Equipment data for the merchant shop.
class _Equipment {
  final String name;
  final String description;
  final double price;
  final IconData icon;

  const _Equipment({
    required this.name,
    required this.description,
    required this.price,
    required this.icon,
  });
}

const _equipmentCatalog = [
  _Equipment(
    name: 'Tractor',
    description: 'Auto-harvest mature crops. Saves time and effort.',
    price: 500,
    icon: Icons.agriculture,
  ),
  _Equipment(
    name: 'Irrigation System',
    description: 'Crops grow 1 stage faster per day. Essential for efficiency.',
    price: 350,
    icon: Icons.water_drop,
  ),
  _Equipment(
    name: 'Greenhouse',
    description: 'Protects 1 plot from mild weather. Reduces disaster damage.',
    price: 800,
    icon: Icons.house,
  ),
  _Equipment(
    name: 'Fertilizer Pack',
    description: 'Instantly advance all crops by 1 growth stage.',
    price: 120,
    icon: Icons.science,
  ),
];

/// In-game Merchant screen — buy equipment and sell crops.
class MerchantScreen extends StatelessWidget {
  const MerchantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, _) {
        final player = state.player;
        if (player == null) return const SizedBox();

        final pages = [
          // ── Page 1: Balances & BNPL ────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.5), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BalanceBadge(
                      label: 'CASH',
                      value: player.cashBalance,
                      color: Colors.orange.shade900,
                      countryCode: player.country,
                    ),
                    if (player.bankRegistered)
                      _BalanceBadge(
                        label: 'BANK',
                        value: player.bankBalance,
                        color: Colors.green.shade900,
                        countryCode: player.country,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (state.bnplPlans.isNotEmpty) ...[
                Text(
                  'Active BNPL Plans',
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFF2D1B10),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: state.bnplPlans.length,
                    itemBuilder: (context, index) {
                      final plan = state.bnplPlans[index];
                      return _BnplPlanCard(plan: plan, player: player, state: state);
                    },
                  ),
                ),
              ] else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text(
                      'No active BNPL plans.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.almendra(
                        color: const Color(0xFF2D1B10).withOpacity(0.6),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Page 2: Equipment Catalog ──────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Equipment Catalog',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFF2D1B10),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _SeedShopSection(player: player, state: state),
                    const SizedBox(height: 24),
                    Text(
                      'Royal Equipment',
                      style: GoogleFonts.cinzel(color: const Color(0xFF2D1B10), fontWeight: FontWeight.w900, fontSize: 24),
                    ),
                    const SizedBox(height: 12),
                    ..._equipmentCatalog.map((eq) => _EquipmentCard(
                      equipment: eq,
                      player: player,
                      state: state,
                    )),
                  ],
                ),
              ),
            ],
          ),

          // ── Page 3: Market Inventory ───────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Royal Inventory',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFF2D1B10),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _InventorySection(player: player)),
            ],
          ),

          // ── Page 4: Market Sell Actions ────────────────
          ListView(
            padding: EdgeInsets.zero,
            children: [
              Text(
                'Trading Floor',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFF2D1B10),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 16),
              _MarketSellSection(player: player, state: state),
            ],
          ),
        ];

        return BookUI(
          title: '🛒 Merchant Shop',
          pages: pages,
        );
      },
    );
  }
}

class _BnplPlanCard extends StatelessWidget {
  final BnplPlan plan;
  final Player player;
  final GameState state;

  const _BnplPlanCard({required this.plan, required this.player, required this.state});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    final isOverdue = plan.isOverdueAtGameDay(state.currentDay);
    final amountDue = plan.monthlyAmount + plan.lateFees;

    String statusStr = 'UNKNOWN';
    Color statusColor = textColor;
    
    if (plan.nextDueDay != null && state.currentDay > plan.nextDueDay!) {
      final monthsLate = ((state.currentDay - plan.nextDueDay!) / kGameDaysPerMonth).ceil();
      statusStr = 'OVERDUE by $monthsLate month(s) (Fined)';
      statusColor = const Color(0xFFB71C1C);
    } else if (plan.nextDueDay != null) {
      final currentGameMonth = ((state.currentDay - 1) ~/ kGameDaysPerMonth) + 1;
      final dueMonth = ((plan.nextDueDay! - 1) ~/ kGameDaysPerMonth) + 1;
      final dueDay = ((plan.nextDueDay! - 1) % kGameDaysPerMonth) + 1;
      final monthsAhead = dueMonth - currentGameMonth;

      if (state.currentDay == plan.nextDueDay!) {
        statusStr = 'DUE TODAY';
        statusColor = Colors.orange.shade900;
      } else if (monthsAhead >= 3) {
        // Paid while already PAID — truly ahead of schedule
        statusStr = 'OVERPAID — Due on Month $dueMonth Day $dueDay';
        statusColor = Colors.green.shade800;
      } else if (monthsAhead >= 2) {
        // On track — just purchased or paid from DUE
        statusStr = 'PAID — Due on Month $dueMonth Day $dueDay';
        statusColor = Colors.blue.shade900;
      } else if (monthsAhead >= 1) {
        // Due next month — time to pay
        statusStr = 'DUE — Due on Month $dueMonth Day $dueDay';
        statusColor = Colors.orange.shade900;
      } else {
        // Due this month
        statusStr = 'DUE — Due on Month $dueMonth Day $dueDay';
        statusColor = Colors.orange.shade900;
      }
    } else {
      statusStr = 'DUE';
      statusColor = Colors.orange.shade900;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFFEBEE) : const Color(0xFFFDF5E6).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? const Color(0xFFB71C1C) : const Color(0xFF8D6E63),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(plan.itemName, style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
              Text('${CurrencyUtil.format(plan.monthlyAmount, player.country)}/mo', 
                   style: GoogleFonts.almendra(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFFBF360C))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Status: $statusStr', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: statusColor, fontSize: 14)),
              Text('Fines: ${CurrencyUtil.format(plan.lateFees, player.country)}', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFFB71C1C), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${plan.paidInstallments}/${plan.installments} installments paid', 
                   style: GoogleFonts.almendra(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              ElevatedButton(
                onPressed: () => _confirmRepayment(context, amountDue),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: const Color(0xFFF4E4BC),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Repay Cash', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmRepayment(BuildContext context, double amountDue) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF5D4037), width: 3)),
        title: Text('Confirm Repayment', style: GoogleFonts.cinzel(color: const Color(0xFF2D1B10), fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to pay the next installment.', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10), fontSize: 16)),
            const SizedBox(height: 8),
            Text('Installment: ${CurrencyUtil.format(plan.monthlyAmount, player.country)}', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
            if (plan.lateFees > 0)
              Text('Late Fees: ${CurrencyUtil.format(plan.lateFees, player.country)}', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFFB71C1C))),
            const Divider(color: Color(0xFF5D4037)),
            Text('Total Due: ${CurrencyUtil.format(amountDue, player.country)}', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, color: const Color(0xFF2D1B10), fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (player.cashBalance >= amountDue) {
                state.repayBnplPlan(plan.id, PaymentMethod.cash);
              } else {
                DialogPopup.show(
                  context,
                  title: 'Insufficient Funds',
                  message: 'You need ${CurrencyUtil.format(amountDue, player.country)} in cash to make this payment.',
                  icon: Icons.error,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: const Color(0xFFF4E4BC)),
            child: Text('PAY', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String countryCode;

  const _BalanceBadge({
    required this.label,
    required this.value,
    required this.color,
    required this.countryCode,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.almendra(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          CurrencyUtil.format(value, countryCode),
          style: GoogleFonts.cinzel(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final _Equipment equipment;
  final Player player;
  final GameState state;

  const _EquipmentCard({
    required this.equipment,
    required this.player,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    final totalBalance = player.cashBalance + player.bankBalance;
    final canAfford = totalBalance >= equipment.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6).withOpacity(0.4), // Creamy parchment
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5D4037), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(equipment.icon, color: const Color(0xFF2D1B10), size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  equipment.name,
                  style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 18, color: textColor),
                ),
              ),
              Text(
                CurrencyUtil.format(equipment.price, player.country),
                style: GoogleFonts.cinzel(color: Colors.orange.shade900, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildOwnedCount(textColor),
          const SizedBox(height: 8),
          Text(
            equipment.description,
            style: GoogleFonts.almendra(fontSize: 14, fontWeight: FontWeight.bold, color: textColor, height: 1.2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: canAfford
                      ? () async {
                          final success = await state.buyEquipment(
                            equipment.price,
                            PaymentMethod.cash,
                          );
                          if (success) {
                            await state.unlockEquipment(equipment.name);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: const Color(0xFFF4E4BC), // Parchment instead of white
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: const Color(0xFF5D4037).withOpacity(0.3),
                    disabledForegroundColor: const Color(0xFF2D1B10).withOpacity(0.5),
                  ),
                  child: Text('BUY (CASH)',
                      style: GoogleFonts.cinzel(
                          fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFFF4E4BC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF5D4037), width: 2)),
                        title: Text('BNPL Purchase',
                          style: GoogleFonts.cinzel(color: const Color(0xFF2D1B10), fontWeight: FontWeight.w900, fontSize: 22)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${equipment.name} — ${CurrencyUtil.format(equipment.price, player.country)}',
                              style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10), fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '6 Months (5% Fee): ${CurrencyUtil.format((equipment.price * 1.05) / 6, player.country)}/mo',
                              style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10)),
                            ),
                            Text(
                              '3 Months (0% Fee): ${CurrencyUtil.format(equipment.price / 3, player.country)}/mo',
                              style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10)),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'First installment is deducted immediately.',
                              style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFFBF360C), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final proceed = await FinancialAdvisor.warnBnpl(context, player, state.bnplPlans.length);
                              if (proceed && context.mounted) {
                                await state.purchaseWithBnpl(equipment.name, equipment.price, 6);
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: const Color(0xFFF4E4BC)),
                            child: Text('BNPL 6 MO', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              final proceed = await FinancialAdvisor.warnBnpl(context, player, state.bnplPlans.length);
                              if (proceed && context.mounted) {
                                await state.purchaseWithBnpl(equipment.name, equipment.price, 3);
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800, foregroundColor: const Color(0xFFF4E4BC)),
                            child: Text('BNPL 3 MO', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5D4037), width: 2),
                    foregroundColor: const Color(0xFF2D1B10),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('BUY (BNPL)',
                      style: GoogleFonts.cinzel(
                          fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOwnedCount(Color textColor) {
    String text = 'Owned: 0';
    if (equipment.name == 'Tractor') {
      text = player.tractorOwned ? 'Owned' : 'Not Owned';
    } else if (equipment.name == 'Fertilizer Pack') {
      text = 'Owned: ${player.fertilizerPackCount}';
    }
    
    return Text(
      text,
      style: GoogleFonts.almendra(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: textColor.withOpacity(0.8),
      ),
    );
  }
}

class _InventorySection extends StatelessWidget {
  final Player player;
  const _InventorySection({required this.player});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    final items = player.inventory.entries.where((e) => e.value > 0).toList();
    final hasTractor = player.tractorOwned;
    final fertCount = player.fertilizerPackCount;
    
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (items.isNotEmpty) ...[
          Text('Crop Harvest', style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
          const SizedBox(height: 8),
          ...items.map((e) => _buildInventoryItem(e.key.toUpperCase(), 'x${e.value}', textColor)),
          const SizedBox(height: 24),
        ],
        
        Text('Royal Assets', style: GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 8),
        if (hasTractor) _buildInventoryItem('TRACTOR', 'OWNED', textColor),
        if (fertCount > 0) _buildInventoryItem('FERTILIZER', 'x$fertCount', textColor),
        if (!hasTractor && fertCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No royal equipment owned.', style: GoogleFonts.almendra(fontSize: 16, color: textColor.withOpacity(0.6))),
          ),
      ],
    );
  }

  Widget _buildInventoryItem(String title, String trailing, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6).withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
          Text(trailing, style: GoogleFonts.almendra(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }
}

class _MarketSellSection extends StatelessWidget {
  final Player player;
  final GameState state;

  const _MarketSellSection({required this.player, required this.state});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    // Filter out seeds
    final items = player.inventory.entries.where((e) => e.value > 0 && !e.key.endsWith('_seed')).toList();
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('No harvested crops to sell. Get farming!', style: GoogleFonts.almendra(fontSize: 16, color: textColor.withOpacity(0.6))),
      );
    }

    return Column(
      children: items.map((entry) {
        final cropNameStr = entry.key; // e.g. "wheat", "corn"
        final cropType = CropType.values.firstWhere((c) => c.name.toLowerCase() == cropNameStr.toLowerCase(), orElse: () => CropType.wheat);
        final config = kCropConfig[cropType]!;
        final sellPrice = config['sellPrice'] as double;
        final totalValue = sellPrice * entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.3), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${config['name']} (x${entry.value})', 
                         style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
                    Text('Unit: ${CurrencyUtil.format(sellPrice, player.country)}  |  Total: ${CurrencyUtil.format(totalValue, player.country)}', 
                         style: GoogleFonts.almendra(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await state.sellInventoryCrop(entry.key);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade900,
                  foregroundColor: const Color(0xFFF4E4BC),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Text('SELL ALL', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}


BnplPlan __createBnplPlan(
  String itemName,
  double totalAmount,
  int months,
  int currentDay,
) {
  return BnplPlan(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    itemName: itemName,
    totalAmount: totalAmount,
    installments: months,
    monthlyAmount: totalAmount / months,
    nextDueDate: DateTime.now().add(const Duration(days: kGameDaysPerMonth)),
    nextDueDay: currentDay + kGameDaysPerMonth,
  );
}

class _SeedShopSection extends StatelessWidget {
  final Player player;
  final GameState state;
  const _SeedShopSection({required this.player, required this.state});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seed Market',
          style: GoogleFonts.cinzel(
            color: textColor,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            _SeedCard(type: CropType.wheat, player: player, state: state),
            _SeedCard(type: CropType.rice, player: player, state: state),
            _SeedCard(type: CropType.corn, player: player, state: state),
          ],
        ),
      ],
    );
  }
}

class _SeedCard extends StatefulWidget {
  final CropType type;
  final Player player;
  final GameState state;
  const _SeedCard({required this.type, required this.player, required this.state});

  @override
  State<_SeedCard> createState() => _SeedCardState();
}

class _SeedCardState extends State<_SeedCard> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final config = kCropConfig[widget.type]!;
    final price = config['seedCost'] as double;
    final name = config['name'] as String;
    final seedKey = '${widget.type.name}_seed';
    final owned = widget.player.inventory[seedKey] ?? 0;
    
    // Map CropType to asset name
    String assetName;
    switch(widget.type) {
      case CropType.wheat: assetName = 'wheat'; break;
      case CropType.rice: assetName = 'rice'; break;
      case CropType.corn: assetName = 'corn'; break;
    }

    final totalPrice = price * _quantity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/crops/${assetName}_3.png', width: 40, height: 40, filterQuality: FilterQuality.none),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$name Seeds', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF2D1B10))),
                    Text('Unit: ${CurrencyUtil.format(price, widget.player.country)}', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                    Text('Owned: $owned', style: GoogleFonts.almendra(fontSize: 14, color: const Color(0xFF2D1B10))),
                  ],
                ),
              ),
              Text(
                'Total: ${CurrencyUtil.format(totalPrice, widget.player.country)}',
                style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.green.shade900),
              )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Qty: $_quantity', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
              Expanded(
                child: Slider(
                  value: _quantity.toDouble(),
                  min: 1,
                  max: 99,
                  divisions: 98,
                  activeColor: const Color(0xFF5D4037),
                  inactiveColor: const Color(0xFF5D4037).withOpacity(0.2),
                  onChanged: (val) => setState(() => _quantity = val.toInt()),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFFF4E4BC),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF5D4037), width: 2)),
                      title: Text('BNPL Purchase', style: GoogleFonts.cinzel(color: const Color(0xFF2D1B10), fontWeight: FontWeight.w900, fontSize: 22)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Buy ${_quantity}x $name Seeds via BNPL?', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10), fontSize: 16)),
                          const SizedBox(height: 12),
                          Text('6 Months (5% Fee): ${CurrencyUtil.format((totalPrice * 1.05) / 6, widget.player.country)}/mo', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
                          Text('3 Months (0% Fee): ${CurrencyUtil.format(totalPrice / 3, widget.player.country)}/mo', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
                          const SizedBox(height: 12),
                          Text('First installment is deducted immediately.', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFFBF360C), fontStyle: FontStyle.italic)),
                        ],
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold))),
                        ElevatedButton(
                          onPressed: () async {
                            final proceed = await FinancialAdvisor.warnBnpl(context, widget.player, widget.state.bnplPlans.length);
                            if (proceed && context.mounted) {
                              final success = await widget.state.purchaseWithBnpl('$name Seeds (x$_quantity)', totalPrice, 6); // Defaulting to 6 for now, or could show options
                              if (success && context.mounted) {
                                widget.state.buySeeds(widget.type, _quantity, free: true); // Add seeds to inventory without deducting cash again
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: const Color(0xFFF4E4BC)),
                          child: Text('BNPL 6 MO', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final proceed = await FinancialAdvisor.warnBnpl(context, widget.player, widget.state.bnplPlans.length);
                            if (proceed && context.mounted) {
                              final success = await widget.state.purchaseWithBnpl('$name Seeds (x$_quantity)', totalPrice, 3);
                              if (success && context.mounted) {
                                widget.state.buySeeds(widget.type, _quantity, free: true); // Add seeds
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown.shade800, foregroundColor: const Color(0xFFF4E4BC)),
                          child: Text('BNPL 3 MO', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF5D4037), width: 2), foregroundColor: const Color(0xFF2D1B10)),
                child: Text('BUY (BNPL)', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async => await widget.state.buySeeds(widget.type, _quantity),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5D4037), foregroundColor: const Color(0xFFF4E4BC)),
                child: Text('BUY CASH', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
