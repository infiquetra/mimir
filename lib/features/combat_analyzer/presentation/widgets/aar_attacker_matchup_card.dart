import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aar_attacker_matchup.dart';

/// Pure expandable incoming source card. U3 GREEN renders identity, split, EHP.
class AarAttackerMatchupCard extends ConsumerWidget {
  const AarAttackerMatchupCard({
    super.key,
    required this.matchup,
    required this.encounterId,
    required this.expanded,
    required this.onToggle,
  });

  final AarAttackerMatchup matchup;
  final String encounterId;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
