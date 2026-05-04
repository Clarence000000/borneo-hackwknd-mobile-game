# Tiled 作物 GID 配置快速指南

## 概述

现在 GameState 已集成了 Tiled 地图支持，当作物生长时会自动更新地图上的 tile GID。你需要：

1. 在 Tiled 中配置作物 tileset 和 PNG
2. 运行 GID 查询脚本找到每个作物各阶段的 GID
3. 将 GID 填入 `lib/providers/game_state.dart` 的 `cropGidsByStage` 常量

## 第一步：在 Tiled 中配置（参考 TILED_CROPS_GUIDE.md）

已完成的步骤：
- ✅ 创建 `crops` 图层
- ✅ 添加 `crops` tileset（包含作物 PNG）
- ✅ 在地图上放置作物 tiles

## 第二步：查找 GID 值

在项目根目录运行：

```bash
python tools/get_tiled_gid_map.py assets/tiles/level1.tmx
```

找到 `crops` tileset 的输出，例如：

```
Tileset: crops
  firstGid: 258  tile: 16x16
    localId=0 -> gid=258  image=wheat_stage0.png
    localId=1 -> gid=259  image=wheat_stage1.png
    localId=2 -> gid=260  image=wheat_stage2.png
    localId=3 -> gid=261  image=wheat_stage3.png
```

记录每个作物的 4 个 GID（stage 0..3）。

## 第三步：填充 cropGidsByStage

编辑 `lib/providers/game_state.dart`，在 `GameState` 类中找到：

```dart
static const Map<CropType, List<int>> cropGidsByStage = {
  // TODO: Replace with actual GID values from your tileset
  CropType.wheat: [0, 0, 0, 0], // stage 0..3 GIDs for wheat
  CropType.rice: [0, 0, 0, 0],  // stage 0..3 GIDs for rice
  CropType.corn: [0, 0, 0, 0],  // stage 0..3 GIDs for corn
};
```

替换为你从脚本获取的实际 GID，例如：

```dart
static const Map<CropType, List<int>> cropGidsByStage = {
  CropType.wheat: [258, 259, 260, 261],  // stage 0..3 GIDs for wheat
  CropType.rice: [262, 263, 264, 265],   // stage 0..3 GIDs for rice
  CropType.corn: [266, 267, 268, 269],   // stage 0..3 GIDs for corn
};
```

## 第四步：在 GameScreen 中传入 RichiFarmGame 引用

确保 GameState 被传入了 RichiFarmGame 实例。在 `lib/screens/game_screen.dart` 中：

```dart
// 假设你已有 GameWidget 实例
final gameWidget = GameWidget(
  game: RichiFarmGame(gameState: gameState),
);

// 当 RichiFarmGame 加载后，设置引用
// 方案 1：在 RichiFarmGame.onLoad() 中
gameState.game = this;

// 方案 2：直接在构造时传入（需要修改 GameState 构造）
// final gameState = GameState(game: game);
```

推荐方案 1（更灵活）：在 `lib/engine/richi_farm_game.dart` 的 `onLoad()` 中添加：

```dart
@override
Future<void> onLoad() async {
  await super.onLoad();
  
  gameState.game = this; // 设置回引用
  
  // ... 其他加载逻辑
}
```

## 第五步：测试

1. 保存所有文件。
2. 运行应用：`flutter run`
3. 进入游戏。
4. 推进一个游戏日期（通过"Next Day"按钮或计时器）。
5. 观察地图上已种植的作物是否切换显示（stage 0 → 1 → 2 → 3）。

## 故障排查

**Q: 地图上的作物没有切换显示**
- 检查 `cropGidsByStage` 中的 GID 是否正确（与脚本输出匹配）。
- 确认 `gameState.game` 被正确设置（查看日志输出）。
- 确认 `crops` 图层在地面图层的**上方**（见 TILED_CROPS_GUIDE.md）。

**Q: 脚本没有输出我的作物 tileset**
- 检查 `crops` tileset 是否已添加到 TMX 文件中。
- 确保 tileset 名称正确（在 Tiled 中匹配）。

**Q: 日志显示"RichiFarmGame reference not set"**
- 在 `RichiFarmGame.onLoad()` 中添加 `gameState.game = this;`。

## 相关文件

- [lib/providers/game_state.dart](../lib/providers/game_state.dart): GameState 和 cropGidsByStage
- [lib/engine/richi_farm_game.dart](../lib/engine/richi_farm_game.dart): setTileGidAt() 实现
- [docs/TILED_CROPS_GUIDE.md](./TILED_CROPS_GUIDE.md): Tiled 编辑器操作步骤
- [docs/TILED_RUNTIME_GID_SWITCHING.md](./TILED_RUNTIME_GID_SWITCHING.md): 详细的 GID 切换说明
- [tools/get_tiled_gid_map.py](../tools/get_tiled_gid_map.py): GID 查询脚本
