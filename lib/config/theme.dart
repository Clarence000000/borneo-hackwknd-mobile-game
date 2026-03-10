import 'package:flutter/material.dart';

/// Game color palette — curated for pixel-art farming aesthetic
class GameColors {
  GameColors._();

  // ─── Terrain ───────────────────────────────────────────────
  static const Color grassLight = Color(0xFF7EC850);
  static const Color grassDark = Color(0xFF5EA832);
  static const Color dirt = Color(0xFF8B6914);
  static const Color dirtDark = Color(0xFF6B4F10);
  static const Color water = Color(0xFF4A90D9);
  static const Color waterDeep = Color(0xFF2E6BB0);

  // ─── Crops ─────────────────────────────────────────────────
  static const Color wheatYoung = Color(0xFF90C040);
  static const Color wheatMature = Color(0xFFD4A017);
  static const Color riceYoung = Color(0xFF80B830);
  static const Color riceMature = Color(0xFFC8B040);
  static const Color cornYoung = Color(0xFF68A828);
  static const Color cornMature = Color(0xFFE8C820);
  static const Color seed = Color(0xFF5C3A1E);

  // ─── Buildings ─────────────────────────────────────────────
  static const Color buildingWall = Color(0xFFD2B48C);
  static const Color buildingRoof = Color(0xFF8B4513);
  static const Color buildingWindow = Color(0xFF87CEEB);
  static const Color bankWall = Color(0xFFE8E0D0);
  static const Color bankRoof = Color(0xFF2F4F4F);
  static const Color merchantWall = Color(0xFFFFD700);
  static const Color merchantRoof = Color(0xFFB8860B);

  // ─── UI ────────────────────────────────────────────────────
  static const Color uiBackground = Color(0xFF1A1A2E);
  static const Color uiPanel = Color(0xFF16213E);
  static const Color uiAccent = Color(0xFF0F3460);
  static const Color uiHighlight = Color(0xFFE94560);
  static const Color uiGold = Color(0xFFFFD700);
  static const Color uiGreen = Color(0xFF4CAF50);
  static const Color uiRed = Color(0xFFEF5350);
  static const Color uiText = Color(0xFFF5F5F5);
  static const Color uiTextDim = Color(0xFF9E9E9E);

  // ─── Weather / Disaster ────────────────────────────────────
  static const Color rainDrop = Color(0xFF6EC6FF);
  static const Color floodWater = Color(0x8844AAFF);
  static const Color droughtTint = Color(0x44FF8800);
  static const Color stormCloud = Color(0xFF3D3D5C);

  // ─── Tile selection ────────────────────────────────────────
  static const Color tileSelected = Color(0x66FFFFFF);
  static const Color tileHover = Color(0x33FFFFFF);
}

/// App theme
class GameTheme {
  GameTheme._();

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GameColors.uiBackground,
        fontFamily: 'RobotoMono',
        colorScheme: const ColorScheme.dark(
          primary: GameColors.uiHighlight,
          secondary: GameColors.uiGold,
          surface: GameColors.uiPanel,
        ),
      );
}
