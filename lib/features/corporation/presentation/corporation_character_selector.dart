import 'package:flutter/material.dart';
import 'package:mimir/core/database/app_database.dart';

class CorporationCharacterOption {
  const CorporationCharacterOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// Naive C7: local selection only; does not call [AppDatabase.selectCharacterWithRevision].
class CorporationCharacterSelectorController {
  CorporationCharacterSelectorController(this.database);

  final AppDatabase database;
  int? activeCharacterId;
  String transientFilter = '';

  Future<void> select(int characterId) async {
    activeCharacterId = characterId;
  }
}

/// Naive C7: decorative Chars control; taps do not invoke [onSelected].
class CorporationCharacterSelector extends StatelessWidget {
  const CorporationCharacterSelector({
    this.characters = const [],
    this.activeId,
    this.onSelected,
    super.key,
  });

  final List<CorporationCharacterOption> characters;
  final int? activeId;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Chars'),
        for (final character in characters)
          TextButton(onPressed: () {}, child: Text(character.name)),
      ],
    );
  }
}
