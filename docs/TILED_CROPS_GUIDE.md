**Tiled 作物图块（PNG）放置与运行时 GID 切换指南**

本指南演示如何在 Tiled 中将作物 PNG（spritesheet 或单张图片）加入 tileset 并放置在地图上，以及如何在运行时使用 `get_tiled_gid_map.py` 查找 tileset 的 `firstGid` 与 localId→gid 映射，以便在 Flame 中动态切换格子显示（用于作物生长阶段）。

目录
- 准备工作
- 在 Tiled 中添加 tileset（带示意图）
- 在地图上放置 crop tiles（带示意图）
- 在项目中注册资源（`pubspec.yaml`）
- 运行时查找 GID（使用仓库脚本）
- 在 Flame 中切换 tile GID 的示例代码

---

准备工作
- 确认你的 map 使用的 tile 大小（例如 16×16）。本项目使用 16×16。
- 把作物图片放入工程：建议放到 `assets/images/crops/`，例如 `wheat_sheet.png` 或若为单张图片集合可放每帧为单文件。
- 确保 `assets/tiles/level1.tmx` 在 `assets/tiles/` 下。

在 Tiled 中添加 tileset
1. 打开 Tiled，打开或新建地图（确保 Tile Width/Height 与项目一致，例如 16×16）。
2. 菜单 -> Map -> New Tileset...（或在 Tilesets 面板中选择 +）：
   - Name: crops
   - Type: Tileset Image（若你有一张 spritesheet）或 Collection of Images（若你用单张图片集合）
   - Image: 选择 PNG，例如 `../images/crops/wheat_sheet.png`（注意：路径相对 `assets/tiles/level1.tmx`，因此向上一级到 `assets/` 再到 `images/...`）
   - Tile Width / Tile Height: 16 / 16
   - 取消勾选 “Embed in map”（可选：外部 tileset 会在 `.tmx` 中以 `<tileset source="...">` 引用 `.tsx` 文件）。

（示意图）
![Tileset 新建面板示意](assets/docs/tiled_new_tileset.png)

在地图上放置 crop tiles

**步骤 1：创建新图层**
1. 打开 Tiled，打开 `assets/tiles/level1.tmx`（或你的地图）。
2. 右侧找到 Layers（图层）面板。点击底部 + 按钮或菜单 Layer -> New Layer -> Tile Layer。
3. 命名为 `crops`（或你偏好的名称），点 OK。

（示意图：Layers 面板，创建新 Tile Layer）
![创建新图层](assets/docs/tiled_new_layer.png)

**重要：调整图层顺序**

Tiled 中**下面的图层会被上面的图层覆盖**。确保 `crops` 图层在所有地面图层（如 `Tilled_Dirt`）的**上方**：
1. 在 Layers 面板中，如果 `crops` 在 `Tilled_Dirt` 下方，用鼠标**拖动** `crops` 图层到 `Tilled_Dirt` 上方。
2. 或者：右键 `crops` 图层 -> Stack -> Raise（或用向上箭头按钮）。

（示意图：Layers 面板，图层顺序正确（crops 在最上面）

```
Layers 面板（从上到下）：
  ▼ crops         <- 顶层，最后渲染，会显示在上面 ✓
  ▼ Tilled_Dirt
  ▼ Hills
  ▼ Water
  ▼ Grass         <- 底层，最先渲染
```

这样放置的作物 tiles 就会显示在泥土的**上面**而不是后面。

**步骤 2：确保 crops tileset 已加入地图**
1. 检查右侧 Tilesets（tileset）面板，确保你已添加过 `crops` tileset（步骤见上文）。
2. 如果没有，点 + 或菜单 Map -> New Tileset，添加你的作物 PNG。

（示意图：Tilesets 面板，确认 crops tileset 已在列表中）
![Tilesets 面板](assets/docs/tiled_tilesets_panel.png)

**步骤 3：选择 crops tileset 并放置 tiles**
1. 在 Tilesets 面板中，选中 `crops` tileset 名称。
2. Tileset 的图像会在下方显示（若是 spritesheet，会看到网格；若是 Collection of Images，会看到一张张图片）。
3. 点击你要放置的 tile 图像（例如小麦秧苗的图片），选中它。

（示意图：在 Tileset 中选择一个 tile）
![选择 tile](assets/docs/tiled_select_tile.png)

4. 回到地图编辑区，左侧工具栏选择 Brush Tool（刷子，通常是默认）或按 B 键。
5. 在地图上点击或拖动，在 `crops` 图层（确保已选中）放置作物 tiles。例如在 Tilled Dirt 上点一下，就会放置刚选中的作物 tile。

（示意图：在地图上用刷子放置 crop tiles）
![放置 tiles](assets/docs/tiled_paint_crops.png)

**步骤 4（可选）：为每个 tile 设置自定义属性**
1. 选择 Select Tool（选择工具，快捷键 S）或菜单 Edit -> Select Objects。
2. 在地图上点击你放置的某个 crop tile。
3. 右侧应该出现该 tile 的信息面板。展开 Tile（或 Object）的 Properties 部分。
4. 点击 + 添加新属性，例如：
   - 属性名：`cropType`，值：`wheat`
   - 属性名：`stage`，值：`0`
   - 属性名：`planted`，值：`true`

（示意图：为 tile 添加自定义属性）
![设置属性](assets/docs/tiled_tile_properties.png)

**提示**
- 如果你想快速放置多个 tiles，继续用 Brush Tool 直接在地图上画。
- 如果 Tiled 没有响应或属性面板不显示，尝试：
  - 点击地图编辑区确保焦点在地图上。
  - 右侧窗口确保选中了 Layers 或 Tilesets 标签。
  - View -> Reset Windows Layout 来重置界面。
- 保存地图：Ctrl+S（Windows）或 Cmd+S（Mac），Tiled 会更新 `assets/tiles/level1.tmx`。

在项目中注册资源（pubspec.yaml）
确保 `pubspec.yaml` 包含资源路径：

  assets:
    - assets/tiles/
    - assets/images/

保存并运行 `flutter pub get`（或当你构建应用时会自动加载资源）。

运行时查找 GID（使用仓库脚本）
仓库包含脚本 `tools/get_tiled_gid_map.py`，用于打印 `tileset` 的 `firstGid` 以及每个 localId 对应的全局 GID（gid = firstGid + localId）。

用法：在仓库根目录运行：

```bash
python tools/get_tiled_gid_map.py assets/tiles/level1.tmx
```

脚本会输出类似：

Tileset: crops
  firstGid: 17  tile: 16x16
    localId=0 -> gid=17  image=... props={}
    localId=1 -> gid=18  image=... props={'stage':'1'}

记录下你关心的 localId（例如代表 stage 0..3 的 localId），并记下对应的 gid 值。

在 Flame 中切换 tile GID（示例）
在 `lib/engine/richi_farm_game.dart` 中，已加载 `TiledComponent`：

示例函数（伪代码）

```dart
void setTileGidAt(int col, int row, int newGid) {
  final map = _mapComponent.tileMap.map;
  final layer = map.layers.firstWhere((l) => l.name == 'crops') as TileLayer;
  final idx = row * map.width + col; // 注意：map.width 是 tiles count
  layer.data[idx] = newGid;
}
```

注意事项
- 一旦你在运行时修改了 layer.data，TiledComponent 的渲染会在之后的帧使用新的 GID 来绘制该格子。
- 不要试图在运行时把这些修改写回到 `.tmx` 文件（除非你明确要生成地图文件）。运行时改动应当同步到你的游戏存档（JSON/数据库），并在加载时恢复为 GID 或实体状态。

附录：建议工作流
- 使用 Tiled 完成初始关卡布置（含所有作物占位）。
- 将地图中作物图块看作“初始种植/野生植被”。
- 在运行时，将这些图块的 GID 映射到你的 `Tile` 模型中的初始 state（例如 `stage`、`cropType`）。
- 玩家操作（种植/收割）后，修改内存中的 `Tile` 数据并更新 layer GID（或替换为 Flame Component）。
