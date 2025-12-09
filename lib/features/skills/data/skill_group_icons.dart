import 'package:flutter/material.dart';

/// Icon mapping for EVE Online skill groups.
///
/// Maps skill group names to Material Icons that approximate the
/// EVE client's skill group icons visible in the Skills Catalogue.
///
/// Based on analysis of `example_skill_catalogue.png` screenshot.
class SkillGroupIcons {
  const SkillGroupIcons._();

  /// Returns the icon for a given skill group name.
  ///
  /// Falls back to [Icons.folder_outlined] if no mapping exists.
  static IconData getIcon(String groupName) {
    return _iconMap[groupName] ?? Icons.folder_outlined;
  }

  static const Map<String, IconData> _iconMap = {
    // Combat Skills
    'Armor': Icons.shield_outlined,
    'Drones': Icons.hub_outlined,
    'Electronic Systems': Icons.grid_view,
    'Gunnery': Icons.flash_on,
    'Missiles': Icons.rocket_launch_outlined,
    'Shields': Icons.shield,
    'Targeting': Icons.gps_fixed,

    // Engineering & Production
    'Engineering': Icons.architecture,
    'Production': Icons.factory_outlined,
    'Resource Processing': Icons.recycling,
    'Rigging': Icons.view_module,
    'Science': Icons.science,

    // Spaceship Skills
    'Fleet Support': Icons.settings,
    'Navigation': Icons.explore_outlined,
    'Spaceship Command': Icons.flight,
    'Subsystems': Icons.apps,

    // Social & Management
    'Corporation Management': Icons.star_outline,
    'Social': Icons.people_outline,
    'Trade': Icons.swap_horizontal_circle,

    // Planetary & Exploration
    'Planet Management': Icons.public,
    'Scanning': Icons.radar,
    'Structure Management': Icons.domain,

    // Neural
    'Neural Enhancement': Icons.psychology,

    // Additional groups (if found in SDE)
    'Sequencing': Icons.swap_horiz,
  };

  /// Returns all known skill group names.
  static Iterable<String> get allGroupNames => _iconMap.keys;

  /// Checks if an icon mapping exists for a group.
  static bool hasIcon(String groupName) => _iconMap.containsKey(groupName);
}
