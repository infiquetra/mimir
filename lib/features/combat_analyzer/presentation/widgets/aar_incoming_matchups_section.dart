import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/parsed_combat_encounter.dart';

/// Provider shell. U3 GREEN watches [aarIncomingMatchupsProvider].
class AarIncomingMatchupsSection extends ConsumerWidget {
  const AarIncomingMatchupsSection({super.key, required this.encounter});

  final ParsedCombatEncounter encounter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
