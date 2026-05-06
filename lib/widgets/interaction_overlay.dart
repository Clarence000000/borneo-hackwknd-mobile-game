import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/engine/components/building_component.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';

class InteractionOverlay extends StatelessWidget {
  final RichiFarmGame game;
  const InteractionOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2D1B10);
    const parchmentColor = Color(0xFFF4E4BC);
    const leatherBorder = Color(0xFF5D4037);

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
            options.add(_buildOption('1', 'Store', () => state.harvestCropInteraction(sell: false)));
            options.add(_buildOption('2', 'Sell', () => state.harvestCropInteraction(sell: true)));
          } else if (state.interactionMenuState == InteractionMenuState.confirmRemove) {
            options.add(Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text('Warning: No refund.', style: GoogleFonts.almendra(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.bold)),
            ));
            options.add(_buildOption('1', 'Yes, Remove', () => state.removeCrop()));
            options.add(_buildOption('2', 'No, Cancel', () => state.setInteractionMenuState(InteractionMenuState.main)));
          }
        }

        final screenPos = game.camera.viewfinder.localToGlobal(worldPos);
        final playerComp = game.playerComponent;
        if (playerComp == null) return const SizedBox.shrink();
        final playerScreenPos = game.camera.viewfinder.localToGlobal(playerComp.position);
        
        // Decide whether to show box on the left or right of the tile
        // to avoid the player character.
        bool showOnRight = screenPos.x > playerScreenPos.x;
        // If tile is to the right of player, show box to the right.
        // If tile is to the left of player, show box to the left.
        // If they are on same tile, default to right but offset more.
        
        final size = MediaQuery.of(context).size;
        double leftPos;
        if (showOnRight) {
          leftPos = (screenPos.x + 20).clamp(0.0, size.width - 150);
        } else {
          leftPos = (screenPos.x - 160).clamp(10.0, size.width);
        }
        
        final topPos = (screenPos.y - (options.length * 20)).clamp(80.0, size.height - 200);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          left: leftPos,
          top: topPos,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: parchmentColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: leatherBorder, width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(4, 4)),
                ],
              ),
              child: Stack(
                children: [
                  const Positioned(top: 0, left: 0, child: Icon(Icons.auto_awesome, size: 8, color: leatherBorder)),
                  const Positioned(bottom: 0, right: 0, child: Icon(Icons.auto_awesome, size: 8, color: leatherBorder)),
                  
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: options,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOption(String keyLabel, String label, VoidCallback onTap) {
    final displayKey = keyLabel == 'F' ? keyLabel : '$keyLabel.';
    const highlightColor = Color(0xFFC5A021); // The new darker gold
    const textColor = Color(0xFF2D1B10);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF5D4037).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                displayKey,
                style: GoogleFonts.cinzel(
                  color: highlightColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.almendra(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
