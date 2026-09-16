import 'package:flutter/material.dart';
import 'package:mimir/core/database/app_database.dart';

class CorporationCharacterOption {
  const CorporationCharacterOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// Selects the corporation owner through [AppDatabase.selectCharacterWithRevision].
class CorporationCharacterSelectorController {
  CorporationCharacterSelectorController(this.database);

  final AppDatabase database;
  int? activeCharacterId;
  String transientFilter = '';

  Future<void> select(int characterId) async {
    await database.selectCharacterWithRevision(characterId);
    activeCharacterId = characterId;
    transientFilter = '';
  }
}

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
    return Semantics(
      container: true,
      label: 'Corporation character selector',
      child: Row(
        children: [
          for (final character in characters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: TextButton(
                  onPressed: () => onSelected?.call(character.id),
                  child: Text(
                    character.name,
                    style: TextStyle(
                      fontWeight: character.id == activeId
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
