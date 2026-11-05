import 'package:flutter/material.dart';

/// Icons for the names stored with each category. Flutter can't look an icon up
/// by name when icons are tree-shaken, so they are listed here.
IconData categoryIcon(String name) => switch (name) {
  'checkroom' => Icons.checkroom_rounded,
  'devices' => Icons.devices_rounded,
  'chair' => Icons.chair_rounded,
  'spa' => Icons.spa_rounded,
  'sports_soccer' => Icons.sports_soccer_rounded,
  'menu_book' => Icons.menu_book_rounded,
  _ => Icons.category_rounded,
};
