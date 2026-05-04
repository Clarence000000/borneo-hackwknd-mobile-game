# Tiled 运行时 GID 切换实装指南

本指南说明如何在运行时使用 `RichiFarmGame.setTileGidAt()` 方法来切换作物的生长阶段（通过更改 tile 的 GID）。

## 前置条件

1. 你已在 Tiled 中创建了 `crops` 图层并放置了作物 tiles。
2. 你已记下 tileset 中代表各生长阶段的 localId 和对应的 gid（使用脚本 `tools/get_tiled_gid_map.py`）。
3. `lib/engine/richi_farm_game.dart` 已包含 `setTileGidAt()` 和 `getTileGidAt()` 方法。

## 第一步：记录 GID 映射

使用脚本查找你的作物 tileset 的 GID：

```bash
python tools/get_tiled_gid_map.py assets/tiles/level1.tmx
```

假设输出为：

```
Tileset: crops
  firstGid: 258  tile: 16x16
    localId=0 -> gid=258  image=wheat_stage0.png
    localId=1 -> gid=259  image=wheat_stage1.png
    localId=2 -> gid=260  image=wheat_stage2.png
    localId=3 -> gid=261  image=wheat_stage3.png
```

记录：
- 小麦 stage 0: gid=258
- 小麦 stage 1: gid=259
- 小麦 stage 2: gid=260
- 小麦 stage 3: gid=261

## 第二步：在 GameState 中添加生长逻辑

在 `lib/providers/game_state.dart` 中添加方法，用于在生长时切换 tile GID。

示例代码：

```dart
// 在 GameState 类中

/// 定义作物 GID 映射（填入你从脚本获取的 GID）
static const Map<CropType, List<int>> cropGidsByStage = {
  CropType.wheat: [258, 259, 260, 261],  // stage 0, 1, 2, 3
  CropType.rice: [262, 263, 264, 265],
  CropType.corn: [266, 267, 268, 269],
};

/// 在服务器计时器或每日更新时调用此方法
void advanceCropGrowth() {
  for (int row = 0; row < kGridRows; row++) {
    for (int col = 0; col < kGridCols; col++) {
      final tile = grid[row][col];
      if (tile.crop != null && tile.crop != CropType.empty) {
        // 增加生长阶段
        if (tile.growthStage < 3) {
          tile.growthStage++;
          
          // 获取新的 GID 并在 Tiled map 上更新
          final gids = cropGidsByStage[tile.crop];
          if (gids != null && gids.isNotEmpty) {
            final newGid = gids[tile.growthStage];
            // 调用 FlameGame 的方法来更新 tile GID
            // (需要从 UI 传入 RichiFarmGame 引用，见下文)
            updateTileInMap('crops', col, row, newGid);
          }
        }
      }
    }
  }
  notifyListeners();
}

// 帮助方法：更新地图 tile GID（需要 RichiFarmGame 引用）
void updateTileInMap(String layerName, int col, int row, int gid) {
  // 这个方法需要访问 RichiFarmGame 实例
  // 可以通过将 game 作为参数传入，或通过服务定位器
  // 见下文的集成方式
}
```

## 第三步：连接 GameState 与 RichiFarmGame

方式 A：通过构造函数传递 RichiFarmGame 实例

```dart
// lib/providers/game_state.dart

class GameState extends ChangeNotifier {
  final RichiFarmGame? game; // 可选，用于 Tiled GID 更新
  
  GameState({this.game});
  
  void updateTileInMap(String layerName, int col, int row, int gid) {
    game?.setTileGidAt(layerName, col, row, gid);
  }
}
```

在初始化 GameState 时传入 game 实例：

```dart
// lib/screens/game_screen.dart

final gameState = GameState(game: game);
```

方式 B：使用服务定位器（GetIt 或类似）

```dart
// 在 main.dart 或初始化时
GetIt.I.registerSingleton<RichiFarmGame>(game);

// 在 GameState 中
void updateTileInMap(String layerName, int col, int row, int gid) {
  final game = GetIt.I<RichiFarmGame>();
  game.setTileGidAt(layerName, col, row, gid);
}
```

## 第四步：触发生长逻辑

在你的计时器或日期推进逻辑中调用 `advanceCropGrowth()`：

```dart
// 例如，在某个按钮或计时器中
void advanceDay() {
  gameState.advanceCropGrowth(); // 推进所有作物生长
  gameState.incrementDayCounter();
  // ... 其他逻辑
}
```

或使用 Flame 的 `update()` 方法（如果你想基于游戏时间）：

```dart
// lib/engine/richi_farm_game.dart

double growthTimer = 0;
const double growthInterval = 30; // 每 30 秒增长一个阶段

@override
void update(double dt) {
  super.update(dt);
  
  growthTimer += dt;
  if (growthTimer >= growthInterval) {
    growthTimer = 0;
    gameState.advanceCropGrowth();
  }
}
```

## 第五步：验证

1. 在 Tiled 中放置几个作物 tiles。
2. 保存 TMX，运行应用。
3. 触发生长逻辑（按按钮或等待计时器）。
4. 观察地图上的作物 tiles 是否切换显示（应该从 stage 0 逐步变到 stage 3）。

## 常见问题

**Q: 我的作物没有切换显示？**
- 确保你的 GID 映射正确（使用脚本查证）。
- 确保 GameState 正确传入了 RichiFarmGame 引用。
- 检查日志输出（`print` 语句）是否有错误信息。

**Q: 如何在不同的 tileset 中区分不同作物？**
- 在 Tiled 中为每种作物创建单独的 tileset（例如 `wheat_tileset`、`rice_tileset`）。
- 在代码中为每个 tileset 维护对应的 GID 映射。
- 在放置时选择正确的 tileset。

**Q: 我想保存/加载玩家进度，如何处理 tile GID？**
- 不要直接保存 GID；保存 Tile 模型中的 `crop` 和 `growthStage`。
- 加载时根据 `growthStage` 计算并设置对应的 GID。
- 这样即使后期更新了 GID 映射，旧存档也能兼容。

## 相关文件

- [RichiFarmGame](../lib/engine/richi_farm_game.dart): `setTileGidAt()` 和 `getTileGidAt()` 方法
- [TILED_CROPS_GUIDE.md](./TILED_CROPS_GUIDE.md): Tiled 编辑器操作指南
- [tools/get_tiled_gid_map.py](../tools/get_tiled_gid_map.py): GID 查询脚本
