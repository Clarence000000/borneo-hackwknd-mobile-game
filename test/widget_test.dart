import 'package:flutter_test/flutter_test.dart';

import 'package:farm_fintech/engine/isometric_engine.dart';

void main() {
  group('IsometricEngine', () {
    const engine = IsometricEngine();

    test('gridToScreen returns correct position for origin', () {
      final pos = engine.gridToScreen(0, 0);
      expect(pos.dx, 0);
      expect(pos.dy, 0);
    });

    test('gridToScreen produces expected isometric layout', () {
      // (1, 0) should be to the right and down
      final pos10 = engine.gridToScreen(1, 0);
      expect(pos10.dx, 32); // tileWidth / 2
      expect(pos10.dy, 16); // tileHeight / 2

      // (0, 1) should be to the left and down
      final pos01 = engine.gridToScreen(0, 1);
      expect(pos01.dx, -32);
      expect(pos01.dy, 16);
    });

    test('screenToGrid roundtrips correctly', () {
      for (var col = 0; col < 8; col++) {
        for (var row = 0; row < 8; row++) {
          final screen = engine.gridToScreen(col, row);
          final (rCol, rRow) = engine.screenToGrid(screen.dx, screen.dy);
          expect(rCol, col, reason: 'col mismatch for ($col, $row)');
          expect(rRow, row, reason: 'row mismatch for ($col, $row)');
        }
      }
    });

    test('isValidTile checks bounds correctly', () {
      expect(engine.isValidTile(0, 0), true);
      expect(engine.isValidTile(7, 7), true);
      expect(engine.isValidTile(-1, 0), false);
      expect(engine.isValidTile(0, -1), false);
      expect(engine.isValidTile(8, 0), false);
      expect(engine.isValidTile(0, 8), false);
    });

    test('getTileDiamondPoints returns 4 points', () {
      final points = engine.getTileDiamondPoints(3, 3);
      expect(points.length, 4);
    });

    test('getGridBounds returns valid rect', () {
      final bounds = engine.getGridBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });
  });
}
