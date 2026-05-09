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
    final label = plan.statusLabelAtDay(state.currentDay);
    final isOverdue = label.startsWith('Overdue');
    final isDue = label == 'Due by this month';
    final fineForNext = plan.fineFor(plan.nextUnpaidIndex);
    final dueAmount = plan.oldestUnpaidAmount();

    final IconData statusIcon;
    final Color statusColor;
    if (isOverdue) {
      statusIcon = Icons.error_outline;
      statusColor = Colors.red.shade900;
    } else if (isDue) {
      statusIcon = Icons.schedule;
      statusColor = const Color(0xFFBF360C);
    } else {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green.shade900;
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(plan.itemName,
                     style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
              ),
              Text('${CurrencyUtil.format(plan.monthlyAmount, player.country)}/mo',
                   style: GoogleFonts.almendra(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFFBF360C))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Monthly Progress: $label',
                  style: GoogleFonts.almendra(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (fineForNext > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 18),
              child: Text(
                '+ ${CurrencyUtil.format(fineForNext, player.country)} late fee',
                style: GoogleFonts.almendra(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${plan.paidInstallments}/${plan.installments} installments paid',
                   style: GoogleFonts.almendra(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
              ElevatedButton(
                onPressed: () => _confirmRepayment(context, textColor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D4037),
                  foregroundColor: const Color(0xFFF4E4BC),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Repay ${CurrencyUtil.format(dueAmount, player.country)}',
                  style: GoogleFonts.cinzel(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmRepayment(BuildContext context, Color textColor) {
    final dueAmount = plan.oldestUnpaidAmount();
    if (player.cashBalance < dueAmount) {
      _showParchmentSnackBar(context, 'Insufficient cash for installment.');
      return;
    }
    final fine = plan.fineFor(plan.nextUnpaidIndex);
    final monthIdx = plan.nextUnpaidIndex;
    final body = fine > 0
        ? 'Pay ${CurrencyUtil.format(dueAmount, player.country)} '
          '(${CurrencyUtil.format(plan.monthlyAmount, player.country)} '
          '+ ${CurrencyUtil.format(fine, player.country)} late fee) '
          'for ${plan.itemName} month $monthIdx of ${plan.installments}?'
        : 'Pay ${CurrencyUtil.format(dueAmount, player.country)} for ${plan.itemName} '
          'month $monthIdx of ${plan.installments}?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF5D4037), width: 3),
        ),
        title: Text('Confirm Repayment', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, color: textColor)),
        content: Text(
          body,
          style: GoogleFonts.almendra(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.cinzel(color: const Color(0xFF5D4037), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.repayBnplPlan(plan.id, PaymentMethod.cash);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade900,
              foregroundColor: const Color(0xFFF4E4BC),
            ),
            child: Text('Confirm', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
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
                  onPressed: () => _showEquipmentBnplDialog(context, equipment, state, player),
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
    // Filter inventory to only show harvested crops (keys without '_seed')
    final items = player.inventory.entries
        .where((e) => e.value > 0 && !e.key.endsWith('_seed'))
        .toList();
        
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text('No harvested crops to sell.', 
              style: GoogleFonts.almendra(fontSize: 18, color: textColor.withOpacity(0.5))),
        ),
      );
    }

    return Column(
      children: items.map((entry) {
        // Find config to get sell price
        final cropType = CropType.values.firstWhere((t) => t.name == entry.key);
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key.toUpperCase(), 
                           style: GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
                      Text('Quantity: ${entry.value}', style: GoogleFonts.almendra(fontSize: 14, color: textColor)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(CurrencyUtil.format(totalValue, player.country), 
                           style: GoogleFonts.cinzel(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green.shade900)),
                      Text('${CurrencyUtil.format(sellPrice, player.country)} per unit', style: GoogleFonts.almendra(fontSize: 12, color: textColor.withOpacity(0.7))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => state.sellInventoryCrop(entry.key),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade900,
                    foregroundColor: const Color(0xFFF4E4BC),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('SELL ALL FOR ${CurrencyUtil.format(totalValue, player.country)}', 
                             style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Helper to show equipment BNPL dialog
void _showEquipmentBnplDialog(BuildContext context, _Equipment equipment, GameState state, Player player) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFF4E4BC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF5D4037), width: 2)),
      title: Text('BNPL: ${equipment.name}', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, color: const Color(0xFF2D1B10))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BnplOptionTile(
            months: 3,
            amount: equipment.price,
            feePercent: 0,
            onSelect: () async {
              final ok = await state.purchaseWithBnpl(equipment.name, equipment.price, 3);
              if (context.mounted) {
                Navigator.pop(ctx);
                if (!ok) {
                  _showParchmentSnackBar(context, 'Insufficient funds for the first installment.');
                }
              }
            },
            country: player.country,
          ),
          const SizedBox(height: 12),
          _BnplOptionTile(
            months: 6,
            amount: equipment.price,
            feePercent: 0.05,
            onSelect: () async {
              final ok = await state.purchaseWithBnpl(equipment.name, equipment.price, 6);
              if (context.mounted) {
                Navigator.pop(ctx);
                if (!ok) {
                  _showParchmentSnackBar(context, 'Insufficient funds for the first installment.');
                }
              }
            },
            country: player.country,
          ),
        ],
      ),
    ),
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
    
    String assetName;
    switch(widget.type) {
      case CropType.wheat: assetName = 'wheat'; break;
      case CropType.rice: assetName = 'rice'; break;
      case CropType.corn: assetName = 'corn'; break;
    }

    final totalCost = price * _quantity;

    return Container(
      width: 200, // Wider to accommodate slider
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF5E6).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5D4037).withOpacity(0.4), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset('assets/images/crops/${assetName}_3.png', width: 32, height: 32, filterQuality: FilterQuality.none),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.cinzel(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF2D1B10))),
                    Text('Own: $owned', style: GoogleFonts.almendra(fontSize: 12, color: const Color(0xFF2D1B10))),
                  ],
                ),
              ),
              Text(CurrencyUtil.format(price, widget.player.country), style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Text('Qty: ', style: GoogleFonts.almendra(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
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
              Text('$_quantity', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
            ],
          ),
          Text('Total: ${CurrencyUtil.format(totalCost, widget.player.country)}', 
               style: GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF2D1B10))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (widget.player.cashBalance + widget.player.bankBalance >= totalCost)
                      ? () => widget.state.buySeeds(widget.type, _quantity)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D4037),
                    foregroundColor: const Color(0xFFF4E4BC),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text('CASH', style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showSeedBnplDialog(context, name, totalCost),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5D4037), width: 1.5),
                    foregroundColor: const Color(0xFF2D1B10),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text('BNPL', style: GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSeedBnplDialog(BuildContext context, String name, double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF4E4BC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF5D4037), width: 2)),
        title: Text('BNPL: $name', style: GoogleFonts.cinzel(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BnplOptionTile(
              months: 3,
              amount: amount,
              feePercent: 0,
              onSelect: () async {
                final ok = await widget.state.buySeeds(widget.type, _quantity, useBnpl: true, installments: 3);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  if (!ok) {
                    _showParchmentSnackBar(context, 'Insufficient funds for the first installment.');
                  }
                }
              },
              country: widget.player.country,
            ),
            const SizedBox(height: 12),
            _BnplOptionTile(
              months: 6,
              amount: amount,
              feePercent: 0.05,
              onSelect: () async {
                final ok = await widget.state.buySeeds(widget.type, _quantity, useBnpl: true, installments: 6);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  if (!ok) {
                    _showParchmentSnackBar(context, 'Insufficient funds for the first installment.');
                  }
                }
              },
              country: widget.player.country,
            ),
          ],
        ),
      ),
    );
  }
}

void _showParchmentSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFFF4E4BC),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF5D4037), width: 2),
      ),
      content: Text(
        message,
        style: GoogleFonts.almendra(
          color: const Color(0xFF2D1B10),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

class _BnplOptionTile extends StatelessWidget {
  final int months;
  final double amount;
  final double feePercent;
  final VoidCallback onSelect;
  final String country;

  const _BnplOptionTile({
    required this.months,
    required this.amount,
    required this.feePercent,
    required this.onSelect,
    required this.country,
  });

  @override
  Widget build(BuildContext context) {
    final total = amount * (1 + feePercent);
    final monthly = total / months;
    return InkWell(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF5D4037)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$months Months Plan', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
            Text('${CurrencyUtil.format(monthly, country)} / month', style: GoogleFonts.almendra(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF2D1B10))),
            if (feePercent > 0)
              Text('+${(feePercent * 100).toInt()}% Processing Fee', style: GoogleFonts.almendra(fontSize: 12, color: Colors.red.shade900)),
            Text('Total: ${CurrencyUtil.format(total, country)}', style: GoogleFonts.almendra(fontSize: 12, color: const Color(0xFF2D1B10))),
          ],
        ),
      ),
    );
  }
}
