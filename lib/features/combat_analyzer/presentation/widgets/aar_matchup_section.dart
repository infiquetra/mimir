import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/combat_damage_matchup.dart';

class AarMatchupSection extends ConsumerWidget {
  const AarMatchupSection({super.key, required this.matchup});

  final CombatDamageMatchup matchup;

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox.shrink();
}
