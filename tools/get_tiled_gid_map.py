#!/usr/bin/env python3
"""
get_tiled_gid_map.py

解析 Tiled (.tmx/.tsx) 文件并打印每个 tileset 的 firstGid 与 local tile id -> 全局 GID 映射。

用法:
  python tools/get_tiled_gid_map.py assets/tiles/level1.tmx


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
    # tileset_elem may reference an external .tsx via 'source' attribute
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
    # root is <tileset> either from .tsx or embedded in .tmx
    name = root.get('name') or '<unnamed>'
    tilewidth = root.get('tilewidth')
    tileheight = root.get('tileheight')
    tiles = {}

    # Tiles can be declared with <tile id="N"> children
    for tile in root.findall('tile'):
        local_id = int(tile.get('id'))
        props = {}
        props_elem = tile.find('properties')
        if props_elem is not None:
            for p in props_elem.findall('property'):
                props[p.get('name')] = p.get('value')
        image = None
        img_elem = tile.find('image')
        if img_elem is not None:
            image = img_elem.get('source')
        tiles[local_id] = {'props': props, 'image': image}

    # If no per-tile entries, try to infer tilecount from image or attribute
    tilecount = root.get('tilecount')
    if tilecount is not None and len(tiles) == 0:
        tilecount = int(tilecount)
        for i in range(tilecount):
            tiles[i] = {'props': {}, 'image': None}

    return {'name': name, 'firstgid': firstgid, 'tilewidth': tilewidth, 'tileheight': tileheight, 'tiles': tiles}


def parse_tmx(path):
    root = load_xml(path)
    if root is None:
        return None
    tmx_dir = os.path.dirname(path)
    tilesets = []
    for ts in root.findall('tileset'):
        parsed = parse_tileset_element(ts, tmx_dir)
        if parsed:
            tilesets.append(parsed)
    return tilesets


def print_mapping(tilesets):
    for ts in tilesets:
        print(f"Tileset: {ts['name']}")
        print(f"  firstGid: {ts['firstgid']}  tile: {ts['tilewidth']}x{ts['tileheight']}")
        sorted_ids = sorted(ts['tiles'].keys())
        for local in sorted_ids:
            info = ts['tiles'][local]
            gid = ts['firstgid'] + local
            props = info.get('props') or {}
            image = info.get('image')
            print(f"    localId={local} -> gid={gid}  image={image} props={props}")
        print("")


def main():
    if len(sys.argv) < 2:
        print("Usage: python tools/get_tiled_gid_map.py path/to/map.tmx")
        sys.exit(1)
    tmx_path = sys.argv[1]
    if not os.path.exists(tmx_path):
        print(f"File not found: {tmx_path}")
        sys.exit(2)
    tilesets = parse_tmx(tmx_path)
    if tilesets is None:
        sys.exit(3)
    print_mapping(tilesets)


if __name__ == '__main__':
    main()
