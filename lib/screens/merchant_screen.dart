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
                child: ListView.builder(
                  itemCount: _equipmentCatalog.length,
                  itemBuilder: (context, index) {
                    return _EquipmentCard(
                      equipment: _equipmentCatalog[index],
                      player: player,
                      state: state,
                    );
                  },
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
              _InventorySection(player: player),
            ],
          ),

          // ── Page 4: Market Sell Actions ────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOverdue ? Colors.red.shade900 : const Color(0xFF5D4037).withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(plan.itemName, 
                   style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
              Text('${CurrencyUtil.format(plan.monthlyAmount, player.country)}/mo', 
                   style: GoogleFonts.almendra(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.orange.shade900)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${plan.paidInstallments}/${plan.installments} installments paid', 
                   style: GoogleFonts.almendra(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              ElevatedButton(
                onPressed: () => state.repayBnplPlan(plan.id, PaymentMethod.cash),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: const Color(0xFFF4E4BC),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: Text('Repay Cash', style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
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
    final canBuyWithCash = player.cashBalance >= equipment.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
                  onPressed: canBuyWithCash
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
                  onPressed: () => state.unlockEquipment(equipment.name), // Simplified for brevity
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5D4037), width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('BNPL 3X', style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF5D4037))),
                ),
              ),
            ],
          ),
        ],
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
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            'Inventory is empty.',
            style: GoogleFonts.almendra(fontSize: 20, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.6)),
          ),
        ),
      );
    }
    
    return Column(
      children: items.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(e.key.toUpperCase(), style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
            Text('x${e.value}', style: GoogleFonts.almendra(fontSize: 22, fontWeight: FontWeight.w900, color: textColor)),
          ],
        ),
      )).toList(),
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
    final items = player.inventory.entries.where((e) => e.value > 0).toList();
    if (items.isEmpty) return const SizedBox();

    return Column(
      children: items.map((entry) {
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
              Text(entry.key.toUpperCase(), 
                   style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
              ElevatedButton(
                onPressed: () => state.sellInventoryCrop(entry.key),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade900,
                  foregroundColor: const Color(0xFFF4E4BC),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text('SELL ALL', style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w900)),
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
