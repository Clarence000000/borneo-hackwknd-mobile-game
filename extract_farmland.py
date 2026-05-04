import xml.etree.ElementTree as ET

# 解析TMX文件
tree = ET.parse('assets/tiles/level1.tmx')
root = tree.getroot()

# 找到Tilled_Dirt图层
tilled_dirt_layer = None
for layer in root.findall('.//layer'):
    if layer.get('name') == 'Tilled_Dirt':
        tilled_dirt_layer = layer
        break

if tilled_dirt_layer is None:
    print("未找到Tilled_Dirt图层")
    exit(1)

# 解析数据
data_str = tilled_dirt_layer.find('data').text.strip()
tiles = [int(x.strip()) for x in data_str.split(',') if x.strip()]

width = int(tilled_dirt_layer.get('width'))
height = int(tilled_dirt_layer.get('height'))

print(f"地图大小: {width}x{height}")
print(f"总tile数: {len(tiles)}")

# 找出所有farmland的位置
farmland_positions = []
for idx, gid in enumerate(tiles):
    if gid != 0:  # 有tile
        col = idx % width
        row = idx // width
        farmland_positions.append((col, row))

print(f"\n找到 {len(farmland_positions)} 个farmland tiles\n")

# 找出分离的块（通过flood fill）
visited = set()
regions = []

def flood_fill(start_col, start_row):
    stack = [(start_col, start_row)]
    region = set()
    while stack:
        c, r = stack.pop()
        if (c, r) in visited or (c, r) not in farmland_positions:
            continue
        visited.add((c, r))
        region.add((c, r))
        # 检查相邻的4个方向
        for dc, dr in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
            stack.append((c + dc, r + dr))
    return region

for col, row in farmland_positions:
    if (col, row) not in visited:
        region = flood_fill(col, row)
        if region:
            regions.append(region)

print(f"找到 {len(regions)} 个独立farmland区域：\n")

region_data = []
for i, region in enumerate(regions):
    region_cols = [c for c, r in region]
    region_rows = [r for c, r in region]
    min_c, max_c = min(region_cols), max(region_cols)
    min_r, max_r = min(region_rows), max(region_rows)
    size = (max_c - min_c + 1, max_r - min_r + 1)
    region_data.append({
        'id': i + 1,
        'col_range': (min_c, max_c),
        'row_range': (min_r, max_r),
        'size': size,
        'count': len(region)
    })
    print(f"区域 {i+1}:")
    print(f"  列: {min_c} - {max_c}")
    print(f"  行: {min_r} - {max_r}")
    print(f"  大小: {size[0]}x{size[1]}")
    print(f"  tile数: {len(region)}\n")

# 生成Dart代码片段
print("\n" + "="*60)
print("Dart代码片段 (_initGrid方法中使用):")
print("="*60 + "\n")

dart_code = "void _initGrid() {\n  grid = List.generate(\n    kGridRows,\n    (row) => List.generate(kGridCols, (col) {\n      // Buildings\n      if (col == 0 && row == 0) {\n        return Tile(col: col, row: row, type: TileType.building);\n      }\n      if (col == 0 && row == 1) {\n        return Tile(col: col, row: row, type: TileType.building);\n      }\n      // Water\n      if (col == 7 && row == 7) {\n        return Tile(col: col, row: row, type: TileType.water);\n      }\n      // Farmland regions\n"

for region in region_data:
    min_c, max_c = region['col_range']
    min_r, max_r = region['row_range']
    dart_code += f"      if (col >= {min_c} && col <= {max_c} && row >= {min_r} && row <= {max_r}) {{\n"
    dart_code += f"        return Tile(col: col, row: row, type: TileType.farmland);\n"
    dart_code += "      }\n"

dart_code += "      return Tile(col: col, row: row, type: TileType.grass);\n    }),\n  );\n}"

print(dart_code)
