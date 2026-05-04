#!/usr/bin/env python3
"""
find_tile_png.py

查询 Tiled 地图上某个格子的 GID，以及对应的 PNG 文件或 spritesheet 坐标。

用法：
  python tools/find_tile_png.py assets/tiles/level1.tmx crops 10 5
  
  参数：
    - assets/tiles/level1.tmx: TMX 文件路径
    - crops: 图层名称（默认 'crops'）
    - 10 5: 格子坐标 (col, row)，从 0 开始

输出：
  - GID（全局 tile ID）
  - tileset 名称与 firstGid
  - localId 与对应的图片路径
"""
import sys
import os
import xml.etree.ElementTree as ET


def load_xml(path):
    try:
        return ET.parse(path).getroot()
    except Exception as e:
        print(f"Failed to parse {path}: {e}")
        return None


def resolve_path(base_dir, ref):
    if os.path.isabs(ref):
        return ref
    return os.path.normpath(os.path.join(base_dir, ref))


def parse_tileset_element(tileset_elem, tmx_dir):
    source = tileset_elem.get('source')
    firstgid = int(tileset_elem.get('firstgid', '0'))
    if source:
        tsx_path = resolve_path(tmx_dir, source)
        root = load_xml(tsx_path)
        if root is None:
            return None
        return parse_tileset_root(root, firstgid, os.path.dirname(tsx_path))
    else:
        return parse_tileset_root(tileset_elem, firstgid, tmx_dir)


def parse_tileset_root(root, firstgid, base_dir):
    name = root.get('name') or '<unnamed>'
    tilewidth = root.get('tilewidth')
    tileheight = root.get('tileheight')
    tiles = {}

    for tile in root.findall('tile'):
        local_id = int(tile.get('id'))
        image = None
        img_elem = tile.find('image')
        if img_elem is not None:
            image = img_elem.get('source')
        tiles[local_id] = {'image': image}

    tilecount = root.get('tilecount')
    if tilecount is not None and len(tiles) == 0:
        tilecount = int(tilecount)
        for i in range(tilecount):
            tiles[i] = {'image': None}

    # Get tileset image (spritesheet)
    image_elem = root.find('image')
    tileset_image = None
    if image_elem is not None:
        tileset_image = image_elem.get('source')

    return {
        'name': name,
        'firstgid': firstgid,
        'tilewidth': tilewidth,
        'tileheight': tileheight,
        'tileset_image': tileset_image,
        'tiles': tiles
    }


def find_tile_png(tmx_path, layer_name, col, row):
    root = load_xml(tmx_path)
    if root is None:
        return None
    
    tmx_dir = os.path.dirname(tmx_path)
    
    # Parse tilesets
    tilesets = []
    for ts in root.findall('tileset'):
        parsed = parse_tileset_element(ts, tmx_dir)
        if parsed:
            tilesets.append(parsed)
    
    # Find target layer
    target_layer = None
    for layer in root.findall('layer'):
        if layer.get('name') == layer_name:
            target_layer = layer
            break
    
    if target_layer is None:
        print(f"Layer '{layer_name}' not found")
        return None
    
    # Get map width & height
    map_width = int(root.get('width'))
    map_height = int(root.get('height'))
    
    if col < 0 or col >= map_width or row < 0 or row >= map_height:
        print(f"Coordinates ({col}, {row}) out of map bounds ({map_width}x{map_height})")
        return None
    
    # Get GID from layer data
    data_elem = target_layer.find('data')
    if data_elem is None:
        print("Layer has no tile data")
        return None
    
    data_text = data_elem.text.strip() if data_elem.text else ''
    gids = [int(x) for x in data_text.split(',')]
    
    idx = row * map_width + col
    if idx >= len(gids):
        print(f"Index {idx} out of layer data bounds")
        return None
    
    gid = gids[idx]
    print(f"Coordinates: ({col}, {row})")
    print(f"GID: {gid}")
    
    if gid == 0:
        print("This tile is empty (GID=0)")
        return None
    
    # Find tileset
    tileset = None
    for ts in tilesets:
        if ts['firstgid'] <= gid < (ts['firstgid'] + len(ts['tiles'])):
            tileset = ts
            break
    
    if tileset is None:
        print(f"No tileset found for GID {gid}")
        return None
    
    local_id = gid - tileset['firstgid']
    print(f"Tileset: {tileset['name']} (firstGid={tileset['firstgid']})")
    print(f"Local ID: {local_id}")
    
    # Find image
    if local_id in tileset['tiles']:
        tile_info = tileset['tiles'][local_id]
        if tile_info['image']:
            # Collection of Images
            img_path = tile_info['image']
            resolved = resolve_path(tmx_dir, img_path)
            print(f"Image: {img_path}")
            print(f"Resolved path: {resolved}")
            return resolved
    
    # Spritesheet mode
    if tileset['tileset_image']:
        spritesheet = tileset['tileset_image']
        resolved = resolve_path(tmx_dir, spritesheet)
        print(f"Spritesheet: {spritesheet}")
        print(f"Resolved path: {resolved}")
        
        # Calculate tile position in spritesheet
        tile_w = int(tileset['tilewidth'])
        tile_h = int(tileset['tileheight'])
        sheet_img = ET.parse(resolved.replace('.png', '_meta.xml')).getroot() if os.path.exists(resolved.replace('.png', '_meta.xml')) else None
        
        # Estimate columns (try to load image to get width, or read from XML)
        # For simplicity, we'll just print the localId and let user calculate
        print(f"In spritesheet: assume W tiles per row")
        print(f"  tile_col = {local_id} % W")
        print(f"  tile_row = {local_id} // W")
        print(f"  pixel_x = tile_col * {tile_w}")
        print(f"  pixel_y = tile_row * {tile_h}")
        
        return resolved
    
    print("No image found for this tile")
    return None


def main():
    if len(sys.argv) < 4:
        print("Usage: python tools/find_tile_png.py <tmx_path> <layer_name> <col> <row>")
        print("Example: python tools/find_tile_png.py assets/tiles/level1.tmx crops 10 5")
        sys.exit(1)
    
    tmx_path = sys.argv[1]
    layer_name = sys.argv[2]
    col = int(sys.argv[3])
    row = int(sys.argv[4])
    
    find_tile_png(tmx_path, layer_name, col, row)


if __name__ == '__main__':
    main()
