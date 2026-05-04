import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/models/tile.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wheat stage images 0..3 all load and decode', () async {
    for (var stage = 0; stage <= 3; stage++) {
      final path = 'assets/images/crops/wheat_$stage.png';
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0));

      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
    }
  });

  test('wheat lifecycle grows through stage 0/1/2/3', () {
    final tile = Tile(col: 10, row: 10, type: TileType.farmland);

    final planted = tile.plant(CropType.wheat, currentDay: 1);
    expect(planted, isTrue);
    expect(tile.growthStage, 0);
    expect(tile.farmState, FarmPlotState.planted);

    tile.advanceLifecycle(currentDay: 2, growthDays: 3);
    expect(tile.growthStage, 1);
    expect(tile.farmState, FarmPlotState.growing);

    tile.advanceLifecycle(currentDay: 3, growthDays: 3);
    expect(tile.growthStage, 2);
    expect(tile.farmState, FarmPlotState.growing);

    tile.advanceLifecycle(currentDay: 4, growthDays: 3);
    expect(tile.growthStage, 3);
    expect(tile.farmState, FarmPlotState.ready);
    expect(tile.isHarvestable, isTrue);

    // Verify it stays ready after additional day advances.
    tile.advanceLifecycle(currentDay: 8, growthDays: 3);
    expect(tile.growthStage, 3);
    expect(tile.farmState, FarmPlotState.ready);
    expect(tile.isHarvestable, isTrue);
  });
}
