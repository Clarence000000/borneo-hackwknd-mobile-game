import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:farm_fintech/config/constants.dart';

/// Loads and caches crop stage images.
class CropImageRegistry {
  CropImageRegistry._();

  static final Map<CropType, List<ui.Image?>> _cache = {};

  /// Attempt to load images for each crop and stage (0..3).
  /// Asset path pattern: assets/images/crops/{crop}_{stage}.png
  static Future<void> loadAll() async {
    developer.log('loadAll starting', name: 'CropImageRegistry');
    final availableAssets = await _readAvailableAssets();
    for (final crop in CropType.values) {
      final List<ui.Image?> stages = List.filled(4, null);
      for (var stage = 0; stage <= 3; stage++) {
        final path = 'assets/images/crops/${_cropName(crop)}_$stage.png';
        if (!availableAssets.contains(path)) {
          stages[stage] = null;
          continue;
        }
        try {
          final data = await rootBundle.load(path);
          final bytes = data.buffer.asUint8List();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          stages[stage] = frame.image;
          developer.log(
            'Loaded $path (${bytes.length} bytes)',
            name: 'CropImageRegistry',
          );
        } catch (_) {
          // Missing asset — leave null to fallback to procedural drawing
          stages[stage] = null;
          developer.log('Failed to load $path', name: 'CropImageRegistry');
        }
      }
      _cache[crop] = stages;
    }
    // Print a summary of loaded assets for quick verification
    for (final crop in CropType.values) {
      final loaded = getLoadedStages(
        crop,
      ).asMap().entries.map((e) => e.value ? '${e.key}' : '_').join(',');
      developer.log(
        'Summary for ${_cropName(crop)}: $loaded',
        name: 'CropImageRegistry',
      );
    }
  }

  static ui.Image? getImage(CropType crop, int stage) {
    final stages = _cache[crop];
    if (stages == null) return null;
    if (stage < 0 || stage >= stages.length) return null;
    return stages[stage];
  }

  /// Returns a list of booleans indicating which stages are loaded for [crop].
  static List<bool> getLoadedStages(CropType crop) {
    final stages = _cache[crop];
    if (stages == null) return List.filled(4, false);
    return stages.map((e) => e != null).toList(growable: false);
  }

  static Future<Set<String>> _readAvailableAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().toSet();
    } catch (e) {
      developer.log(
        'Failed to read asset manifest: $e',
        name: 'CropImageRegistry',
      );
      return const {};
    }
  }

  static String _cropName(CropType c) {
    switch (c) {
      case CropType.wheat:
        return 'wheat';
      case CropType.rice:
        return 'rice';
      case CropType.corn:
        return 'corn';
    }
  }
}
