import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../fitting_providers.dart';

class ShipBrowser extends ConsumerWidget {
  const ShipBrowser({super.key});

  static const _popularShips = [
    (587, 'Rifter'),
    (597, 'Punisher'),
    (603, 'Incursus'),
    (608, 'Merlin'),
    (644, 'Megathron'),
    (24698, 'Drake'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFit = ref.watch(activeFittingProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _popularShips.length,
      itemBuilder: (context, index) {
        final ship = _popularShips[index];
        final typeId = ship.$1;
        final name = ship.$2;
        final isSelected = activeFit?.shipTypeId == typeId;

        return Card(
          color: isSelected ? EveColors.surfaceBright : EveColors.surfaceDefault,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: EveTypeIcon(
              typeId: typeId,
              size: 40,
            ),
            title: Text(
              name,
              style: TextStyle(
                color: isSelected ? EveColors.photonBlue : EveColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: EveColors.photonBlue)
                : const Icon(Icons.chevron_right, color: EveColors.textSecondary),
            onTap: () {
              ref.read(activeFittingProvider.notifier).setShip(typeId, name);
            },
          ),
        );
      },
    );
  }
}
