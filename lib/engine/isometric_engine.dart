import 'dart:ui';

import 'package:farm_fintech/config/constants.dart';

/// Core 2.5D isometric projection math.
///
/// Uses a standard 2:1 isometric diamond layout where:
/// - X-axis goes down-right
/// - Y-axis goes down-left
/// - Origin is top-center of the grid
class IsometricEngine {
  final double tileWidth;
  final double tileHeight;

  const IsometricEngine({
    this.tileWidth = kTileWidth,
    this.tileHeight = kTileHeight,
  });

  /// Convert grid coordinates (col, row) → screen pixel position (x, y).
  ///
  /// Returns the CENTER-TOP of the isometric diamond tile.
  Offset gridToScreen(int col, int row) {
    final x = (col - row) * (tileWidth / 2);
    final y = (col + row) * (tileHeight / 2);
    return Offset(x, y);
  }

  /// Convert screen pixel position (x, y) → grid coordinates (col, row).
  ///
  /// This is the inverse of [gridToScreen], used for hit-testing taps.
  /// The [screenOffset] should already have camera transform applied.
  (int col, int row) screenToGrid(double sx, double sy) {
    final col = (sx / (tileWidth / 2) + sy / (tileHeight / 2)) / 2;
    final row = (sy / (tileHeight / 2) - sx / (tileWidth / 2)) / 2;
    return (col.floor(), row.floor());
  }

  /// Check if grid coordinates are within valid bounds.
  bool isValidTile(int col, int row, {int cols = kGridCols, int rows = kGridRows}) {
    return col >= 0 && col < cols && row >= 0 && row < rows;
  }

  /// Get the 4 corner points of an isometric diamond tile at (col, row).
  ///
  /// Returns [top, right, bottom, left] offsets — useful for drawing
  /// the tile shape with [Canvas.drawPath].
  List<Offset> getTileDiamondPoints(int col, int row) {
    final center = gridToScreen(col, row);
    final halfW = tileWidth / 2;
    final halfH = tileHeight / 2;

    return [
      Offset(center.dx, center.dy),               // top
      Offset(center.dx + halfW, center.dy + halfH), // right
      Offset(center.dx, center.dy + tileHeight),     // bottom
      Offset(center.dx - halfW, center.dy + halfH), // left
    ];
  }

  /// Calculate the screen-space bounding box of the entire grid.
  /// Useful for centering the camera.
  Rect getGridBounds({int cols = kGridCols, int rows = kGridRows}) {
    // The four extreme tiles
    final topPoint = gridToScreen(0, 0);
    final rightPoint = gridToScreen(cols - 1, 0);
    final bottomPoint = gridToScreen(cols - 1, rows - 1);
    final leftPoint = gridToScreen(0, rows - 1);

    final minX = leftPoint.dx - tileWidth / 2;
    final maxX = rightPoint.dx + tileWidth / 2;
    final minY = topPoint.dy;
    final maxY = bottomPoint.dy + tileHeight;

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
