import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/financial/bnpl_plan.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/widgets/dialog_popup.dart';
import 'package:farm_fintech/widgets/financial_advisor.dart';
import 'package:farm_fintech/utils/currency_util.dart';

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
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      appBar: AppBar(
        title: const Text('🛒 Merchant Shop'),
        backgroundColor: GameColors.merchantRoof,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<GameState>(
        builder: (context, state, _) {
          final player = state.player;
          if (player == null) return const SizedBox();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GameColors.uiPanel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: GameColors.merchantRoof.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _BalanceBadge(
                          label: 'Cash',
                          value: player.cashBalance,
                          color: GameColors.uiGold,
                          countryCode: player.country,
                        ),
                        if (player.bankRegistered)
                          _BalanceBadge(
                            label: 'Bank',
                            value: player.bankBalance,
                            color: GameColors.uiGreen,
                            countryCode: player.country,
                          ),
                      ],
                    ),
                  ),
                ),
                const TabBar(
                  labelColor: GameColors.uiHighlight,
                  unselectedLabelColor: GameColors.uiTextDim,
                  indicatorColor: GameColors.uiHighlight,
                  tabs: [
                    Tab(text: 'Equipment'),
                    Tab(text: 'Market'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (state.bnplPlans.isNotEmpty) ...[
                              const Text(
                                'Active BNPL Plans',
                                style: TextStyle(
                                  color: GameColors.uiText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...state.bnplPlans.map(
                                (plan) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: plan.isOverdue
                                        ? GameColors.uiRed.withValues(
                                            alpha: 0.15,
                                          )
                                        : GameColors.uiPanel,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: plan.isOverdue
                                          ? GameColors.uiRed.withValues(
                                              alpha: 0.5,
                                            )
                                          : GameColors.uiAccent.withValues(
                                              alpha: 0.3,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${CurrencyUtil.format(plan.monthlyAmount, player.country)}/mo',
                                            style: const TextStyle(
                                              color: GameColors.uiGold,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (plan.lateFees > 0)
                                            Text(
                                              'Late fees: ${CurrencyUtil.format(plan.lateFees, player.country)}',
                                              style: const TextStyle(
                                                color: GameColors.uiRed,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            const Text(
                              'Equipment',
                              style: TextStyle(
                                color: GameColors.uiText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._equipmentCatalog.map(
                              (eq) => _EquipmentCard(
                                equipment: eq,
                                player: player,
                                state: state,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _MarketSection(player: player, state: state),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: GameColors.uiTextDim, fontSize: 12),
        ),
        Text(
          CurrencyUtil.format(value, countryCode),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
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
    final canBuyWithCash = player.cashBalance >= equipment.price;
    final canBuyWithBank =
        player.bankRegistered && player.bankBalance >= equipment.price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GameColors.uiPanel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameColors.uiAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: GameColors.merchantRoof.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(equipment.icon, color: GameColors.uiGold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipment.name,
                      style: const TextStyle(
                        color: GameColors.uiText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      equipment.description,
                      style: const TextStyle(
                        color: GameColors.uiTextDim,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyUtil.format(equipment.price, player.country),
                style: const TextStyle(
                  color: GameColors.uiGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canBuyWithCash
                        ? GameColors.uiGold
                        : GameColors.uiTextDim.withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: canBuyWithCash
                      ? () async {
                          final success = await state.buyEquipment(
                            equipment.price,
                            PaymentMethod.cash,
                          );
                          if (!context.mounted || !success) return;
                          DialogPopup.show(
                            context,
                            title: '✅ Purchased!',
                            message:
                                '${equipment.name} bought with CASH for ${CurrencyUtil.format(equipment.price, player.country)}.',
                            icon: Icons.check_circle,
                            iconColor: GameColors.uiGreen,
                          );
                        }
                      : null,
                  child: const Text(
                    'Buy with Cash',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canBuyWithBank
                        ? GameColors.uiGreen
                        : GameColors.uiTextDim.withValues(alpha: 0.3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: canBuyWithBank
                      ? () async {
                          final success = await state.buyEquipment(
                            equipment.price,
                            PaymentMethod.bank,
                          );
                          if (!context.mounted || !success) return;
                          DialogPopup.show(
                            context,
                            title: '✅ Purchased!',
                            message:
                                '${equipment.name} bought with BANK for ${CurrencyUtil.format(equipment.price, player.country)}.',
                            icon: Icons.check_circle,
                            iconColor: GameColors.uiGreen,
                          );
                        }
                      : null,
                  child: const Text(
                    'Buy with Bank',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: kBnplInstallmentOptions.map((months) {
              final monthly = equipment.price / months;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GameColors.uiHighlight,
                      side: const BorderSide(color: GameColors.uiHighlight),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await FinancialAdvisor.warnBnpl(
                        context,
                        player,
                        state.bnplPlans.length,
                      );
                      if (!context.mounted) return;

                      final plan = __createBnplPlan(
                        equipment.name,
                        equipment.price,
                        months,
                      );
                      await FirestoreService().createBnplPlan(player.uid, plan);
                      state.bnplPlans.add(plan);
                      state.refresh();

                      if (!context.mounted) return;
                      DialogPopup.show(
                        context,
                        title: '📦 BNPL Activated!',
                        message:
                            '${equipment.name} acquired on ${months}x installments.\n\n'
                            'Monthly payment: ${CurrencyUtil.format(monthly, player.country, decimals: 2)}\n\n'
                            '⚠️ Late payments will incur:\n'
                            '• ${CurrencyUtil.format(kBnplAdminFee, player.country)} admin fee\n'
                            '• ${CurrencyUtil.format(kBnplLateFee, player.country)} late fee',
                        icon: Icons.credit_card,
                        iconColor: GameColors.uiHighlight,
                      );
                    },
                    child: Text(
                      '${months}x\n${CurrencyUtil.format(monthly, player.country)}/mo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MarketSection extends StatelessWidget {
  final Player player;
  final GameState state;

  const _MarketSection({required this.player, required this.state});

  CropType? _findCropTypeByKey(String key) {
    for (final cropType in CropType.values) {
      if (cropType.name == key) {
        return cropType;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = player.inventory.entries
        .where((entry) => entry.value > 0)
        .toList();
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No crops in inventory yet.\nHarvest crops to stock your market.',
          textAlign: TextAlign.center,
          style: TextStyle(color: GameColors.uiTextDim),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Market',
          style: TextStyle(
            color: GameColors.uiText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((entry) {
          final cropKey = entry.key;
          final quantity = entry.value;
          final cropType = _findCropTypeByKey(cropKey);
          if (cropType == null) return const SizedBox.shrink();

          final config = kCropConfig[cropType]!;
          final cropName = config['name'] as String;
          final sellPrice = config['sellPrice'] as double;
          final totalValue = sellPrice * quantity;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GameColors.uiPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: GameColors.uiAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cropName,
                        style: const TextStyle(
                          color: GameColors.uiText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: $quantity • ${CurrencyUtil.format(sellPrice, player.country)} each',
                        style: const TextStyle(
                          color: GameColors.uiTextDim,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Total: ${CurrencyUtil.format(totalValue, player.country)}',
                        style: const TextStyle(
                          color: GameColors.uiGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameColors.uiGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final revenue = await state.sellInventoryCrop(cropKey);
                    if (!context.mounted || revenue == null) return;

                    DialogPopup.show(
                      context,
                      title: '💰 Sold!',
                      message:
                          'Sold all $cropName for ${CurrencyUtil.format(revenue, player.country)}.',
                      icon: Icons.sell,
                      iconColor: GameColors.uiGreen,
                    );
                  },
                  child: const Text('Sell All'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

BnplPlan __createBnplPlan(String itemName, double totalAmount, int months) {
  return BnplPlan(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    itemName: itemName,
    totalAmount: totalAmount,
    installments: months,
    monthlyAmount: totalAmount / months,
    nextDueDate: DateTime.now().add(const Duration(days: 30)),
  );
}
