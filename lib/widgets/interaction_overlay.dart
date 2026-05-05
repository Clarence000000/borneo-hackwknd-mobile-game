import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/engine/components/building_component.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';

class InteractionOverlay extends StatelessWidget {
  final RichiFarmGame game;
  const InteractionOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameState>(
      builder: (context, state, child) {
        if (state.interactableBuilding == null && state.interactableTile == null) {
          return const SizedBox.shrink();
        }

        List<Widget> options = [];
        Vector2 worldPos;

        if (state.interactableBuilding != null) {
          final building = state.interactableBuilding!;
          if (building.buildingType == BuildingType.bank) {
            options.add(_buildOption('F', 'Bank', () => game.onBuildingTapped?.call(building.buildingType)));
          } else if (building.buildingType == BuildingType.merchant) {
            options.add(_buildOption('F', 'Merchant', () => game.onBuildingTapped?.call(building.buildingType)));
          }
          worldPos = Vector2(building.position.x + building.size.x, building.position.y + building.size.y / 2);
        } else {
          final (col, row) = state.interactableTile!;
          final tile = state.grid[row][col];
          worldPos = Vector2(col * 16.0 + 16.0, row * 16.0 + 8.0);

          if (state.interactionMenuState == InteractionMenuState.main) {
            if (!tile.hasCrop) {
              options.add(_buildOption('F', 'Plant Crop', () => state.setInteractionMenuState(InteractionMenuState.plant)));
            } else if (tile.isHarvestable) {
              options.add(_buildOption('1', 'Harvest', () => state.setInteractionMenuState(InteractionMenuState.harvest)));
              options.add(_buildOption('2', 'Remove Plant', () => state.setInteractionMenuState(InteractionMenuState.confirmRemove)));
            } else {
              options.add(_buildOption('F', 'Remove Plant', () => state.setInteractionMenuState(InteractionMenuState.confirmRemove)));
            }
          } else if (state.interactionMenuState == InteractionMenuState.plant) {
            options.add(_buildOption('1', 'Wheat', () => state.plantCropInteraction(CropType.wheat)));
            options.add(_buildOption('2', 'Paddy', () => state.plantCropInteraction(CropType.rice)));
            options.add(_buildOption('3', 'Corn', () => state.plantCropInteraction(CropType.corn)));
          } else if (state.interactionMenuState == InteractionMenuState.harvest) {
            options.add(_buildOption('1', 'Store in Inventory', () => state.harvestCropInteraction(sell: false)));
            options.add(_buildOption('2', 'Sell Now', () => state.harvestCropInteraction(sell: true)));
          } else if (state.interactionMenuState == InteractionMenuState.confirmRemove) {
            options.add(const Padding(
              padding: EdgeInsets.only(bottom: 4.0),
              child: Text('Warning: No refund.', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ));
            options.add(_buildOption('1', 'Yes, Remove', () => state.removeCrop()));
            options.add(_buildOption('2', 'No, Cancel', () => state.setInteractionMenuState(InteractionMenuState.main)));
          }
        }

        // Calculate screen position from world coordinates
        final screenPos = game.camera.viewfinder.localToGlobal(worldPos);



        return Positioned(
          left: screenPos.x + 8, // Just to the right of the tile
          top: screenPos.y - (options.length * 14), // Centered vertically relative to the tile
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.brown.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.brown.shade300.withValues(alpha: 0.5), width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: options,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOption(String keyLabel, String label, VoidCallback onTap) {
    final displayKey = keyLabel == 'F' ? keyLabel : '$keyLabel.';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayKey,
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
