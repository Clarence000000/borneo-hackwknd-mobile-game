import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/components.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/engine/components/interactive_building_component.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';

class InteractionOverlay extends StatelessWidget {
  final RichiFarmGame game;
  const InteractionOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    
    const parchmentColor = Color(0xFFF4E4BC);
    const leatherBorder = Color(0xFF5D4037);

    return Consumer<GameState>(
      builder: (context, state, child) {
        if (state.interactableBuilding == null &&
            state.interactableTile == null &&
            state.interactableShadyLender == null &&
            state.isNearLyra == false) {
          return const SizedBox.shrink();
        }

        List<Widget> options = [];
        Vector2 worldPos = Vector2.zero();

        if (state.interactableShadyLender != null) {
          final lender = state.interactableShadyLender!;
          options.add(_buildOption('F', 'Shady Lender', () {
            state.showShadyDialogue = true;
            state.refresh();
          }));
          worldPos = Vector2(lender.position.x + lender.size.x, lender.position.y + lender.size.y / 2);
        } else if (state.interactableBuilding != null) {
          final building = state.interactableBuilding!;
          if (building.type == 'bank') {
            options.add(_buildOption('F', 'Bank', () => game.onBuildingTapped?.call(building.type)));
          } else if (building.type == 'merchant') {
            options.add(_buildOption('F', 'Merchant', () => game.onBuildingTapped?.call(building.type)));
          }
          worldPos = Vector2(building.position.x + building.size.x, building.position.y + building.size.y / 2);
        } else if (state.isNearLyra && game.lyraNpc != null) {
          if (state.interactionMenuState == InteractionMenuState.main) {
            options.add(_buildOption('F', 'Speak with Lyra', () {
              state.interactionMenuState = InteractionMenuState.lyra;
              state.refresh();
            }));
          } else if (state.interactionMenuState == InteractionMenuState.lyra) {
            options.add(_buildOption('1', 'Chat with Lyra', () {
              state.interactionMenuState = InteractionMenuState.main;
              game.onLyraTapped?.call();
            }));
            options.add(_buildOption('2', 'Lyra\'s Quest', () {
              state.interactionMenuState = InteractionMenuState.main;
              game.onLyraQuestTapped?.call();
            }));
            options.add(_buildOption('ESC', 'Back', () {
              state.interactionMenuState = InteractionMenuState.main;
              state.refresh();
            }));
          }
          worldPos = Vector2(game.lyraNpc!.position.x + 32, game.lyraNpc!.position.y + 16);
        } else if (state.interactableTile != null) {
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
            final wheatSeeds = state.player?.inventory['wheat_seed'] ?? 0;
            final riceSeeds = state.player?.inventory['rice_seed'] ?? 0;
            final cornSeeds = state.player?.inventory['corn_seed'] ?? 0;

            options.add(Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text('Select crop to plant', 
                style: GoogleFonts.cinzel(color: const Color(0xFFC5A021), fontWeight: FontWeight.w900, fontSize: 16)),
            ));
            
            options.add(const SizedBox(height: 8));

            options.add(_buildOption('1', 'Wheat ($wheatSeeds)', wheatSeeds >= 1 ? () => state.plantCropInteraction(CropType.wheat) : null));
            options.add(_buildOption('2', 'Paddy ($riceSeeds)', riceSeeds >= 1 ? () => state.plantCropInteraction(CropType.rice) : null));
            options.add(_buildOption('3', 'Corn ($cornSeeds)', cornSeeds >= 1 ? () => state.plantCropInteraction(CropType.corn) : null));
            options.add(_buildOption('ESC', 'Back', () => state.setInteractionMenuState(InteractionMenuState.main)));
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
        
        bool showOnRight = screenPos.x > playerScreenPos.x;
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

  Widget _buildOption(String key, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.withOpacity(0.2) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: onTap == null ? Colors.grey : const Color(0xFF5D4037),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                key,
                style: GoogleFonts.cinzel(color: const Color(0xFFF4E4BC), fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.almendra(
                color: onTap == null ? Colors.grey.shade700 : const Color(0xFF2D1B10),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
