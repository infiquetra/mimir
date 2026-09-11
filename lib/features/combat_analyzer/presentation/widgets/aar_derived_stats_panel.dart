import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aar_fit_derivation.dart';
import '../../domain/combat_damage_matchup.dart';

class AarDerivedStatsPanel extends ConsumerWidget {
  const AarDerivedStatsPanel({
    super.key,
    required this.derivation,
    required this.title,
    this.matchup,
  });

  final AarFitDerivation derivation;
  final String title;
  final CombatDamageMatchup? matchup;

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}
