import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/combat_attacker_correlation.dart';
import '../../domain/parsed_combat_encounter.dart';

/// Provider shell. U4 GREEN watches [combatAttackerCorrelationProvider].
class AarAttackerCorrelationSection extends ConsumerWidget {
  const AarAttackerCorrelationSection({super.key, required this.encounter});

  final ParsedCombatEncounter encounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}

/// Pure body rendered by Group H tests.
class AarAttackerCorrelationBody extends ConsumerStatefulWidget {
  const AarAttackerCorrelationBody({
    super.key,
    required this.correlation,
    required this.incomingBySource,
  });

  final AttackerCorrelation? correlation;
  final Map<String, int> incomingBySource;

  @override
  ConsumerState<AarAttackerCorrelationBody> createState() =>
      _AarAttackerCorrelationBodyState();
}

class _AarAttackerCorrelationBodyState
    extends ConsumerState<AarAttackerCorrelationBody> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
