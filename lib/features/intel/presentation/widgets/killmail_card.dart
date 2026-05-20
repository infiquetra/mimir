import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mimir/core/widgets/eve_type_icon.dart';
import 'package:mimir/features/characters/data/character_status_providers.dart';
import '../../domain/killmail_models.dart';

final intelNameProvider = FutureProvider.family<String, int>((ref, id) async {
  final repo = ref.watch(characterStatusRepositoryProvider);
  final name = await repo.resolveName(id);
  return name ?? 'Unknown ($id)';
});

class KillmailCard extends ConsumerWidget {
  final ZKillmail killmail;

  const KillmailCard({super.key, required this.killmail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat.compact(locale: 'en_US');

    final systemNameAsync = ref.watch(
      intelNameProvider(killmail.solarSystemId),
    );
    final shipNameAsync = ref.watch(
      intelNameProvider(killmail.victim.shipTypeId),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Future: open killmail details
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ship Icon
              EveTypeIcon(typeId: killmail.victim.shipTypeId, size: 64),
              const SizedBox(width: 16),

              // Kill Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // System & Time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        systemNameAsync.when(
                          data: (name) => Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          loading: () => const Text('Loading...'),
                          error: (error, stack) =>
                              Text('System ${killmail.solarSystemId}'),
                        ),
                        Text(
                          DateFormat.Hm().format(
                            killmail.killmailTime.toLocal(),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Ship & Victim
                    shipNameAsync.when(
                      data: (name) =>
                          Text(name, style: theme.textTheme.bodyMedium),
                      loading: () => const Text('Loading ship...'),
                      error: (error, stack) =>
                          Text('Ship ${killmail.victim.shipTypeId}'),
                    ),

                    if (killmail.victim.characterName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        killmail.victim.characterName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Value & Attackers
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    numberFormat.format(killmail.totalValue),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.red[400],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${killmail.attackerCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
