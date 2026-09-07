import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_service.dart';
import 'models.dart';

/// Parses and generates EVE Online fitting formats.
/// Supports both EFT (text block) and DNA (in-game links).
class FittingFormatParser {
  final SdeService _sdeService;
  bool _reverseLookupUnavailableLogged = false;

  FittingFormatParser(this._sdeService);

  /// Parse an EFT format string into a [Fitting].
  ///
  /// Format example:
  /// [Rifter, PvP]
  /// Damage Control II
  /// Small Armor Repairer II
  ///
  /// 1MN Afterburner II
  /// Warp Scrambler II
  /// Stasis Webifier II
  ///
  /// 200mm AutoCannon II
  /// 200mm AutoCannon II
  /// 200mm AutoCannon II
  /// Rocket Launcher II
  ///
  /// Small Projectile Burst Aerator I
  /// Small Projectile Collision Accelerator I
  Future<Fitting?> parseEft(String eftString) async {
    Log.d('FITTING', 'Parsing EFT string:\n$eftString');
    try {
      final rawLines = eftString.split('\n').map((l) => l.trim()).toList();
      while (rawLines.isNotEmpty && rawLines.first.isEmpty) {
        rawLines.removeAt(0);
      }
      while (rawLines.isNotEmpty && rawLines.last.isEmpty) {
        rawLines.removeLast();
      }
      final lines = rawLines.where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) return null;

      // First line is [ShipType, FittingName]
      final headerMatch = RegExp(r'^\[(.*),\s*(.*)\]$').firstMatch(lines[0]);
      if (headerMatch == null) {
        Log.w('FITTING', 'Invalid EFT header: ${lines[0]}');
        return null;
      }

      final shipTypeName = headerMatch.group(1)!;
      final fittingName = headerMatch.group(2)!;
      final shipTypeId = await _resolveTypeIdByName(shipTypeName) ?? 0;
      final sections = _splitEftSections(rawLines.skip(1));
      final lowSlots = <FittedModule>[];
      final medSlots = <FittedModule>[];
      final highSlots = <FittedModule>[];
      final rigSlots = <FittedModule>[];

      for (
        var sectionIndex = 0;
        sectionIndex < sections.length;
        sectionIndex++
      ) {
        final fallbackSlot = switch (sectionIndex) {
          0 => SlotType.low,
          1 => SlotType.med,
          2 => SlotType.high,
          3 => SlotType.rig,
          _ => SlotType.high,
        };
        for (final line in sections[sectionIndex]) {
          final module = await _moduleFromEftLine(
            line,
            fallbackSlot: fallbackSlot,
            slotIndex: switch (fallbackSlot) {
              SlotType.low => lowSlots.length,
              SlotType.med => medSlots.length,
              SlotType.high => highSlots.length,
              SlotType.rig => rigSlots.length,
              SlotType.subsystem => 0,
            },
          );
          if (module == null) continue;
          switch (module.slotType) {
            case SlotType.low:
              lowSlots.add(module.copyWith(slotIndex: lowSlots.length));
            case SlotType.med:
              medSlots.add(module.copyWith(slotIndex: medSlots.length));
            case SlotType.high:
              highSlots.add(module.copyWith(slotIndex: highSlots.length));
            case SlotType.rig:
              rigSlots.add(module.copyWith(slotIndex: rigSlots.length));
            case SlotType.subsystem:
              break;
          }
        }
      }

      return Fitting(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: fittingName,
        shipTypeId: shipTypeId,
        shipName: shipTypeName,
        highSlots: highSlots,
        medSlots: medSlots,
        lowSlots: lowSlots,
        rigSlots: rigSlots,
      );
    } catch (e, stack) {
      Log.e('FITTING', 'Error parsing EFT', e, stack);
      return null;
    }
  }

  List<List<String>> _splitEftSections(Iterable<String> lines) {
    final sections = <List<String>>[];
    var current = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        if (current.isNotEmpty) {
          sections.add(current);
          current = <String>[];
        }
        continue;
      }
      current.add(line.trim());
    }
    if (current.isNotEmpty) sections.add(current);
    return sections;
  }

  Future<FittedModule?> _moduleFromEftLine(
    String line, {
    required SlotType fallbackSlot,
    required int slotIndex,
  }) async {
    final moduleName = line.split(',').first.trim();
    if (moduleName.isEmpty || moduleName.startsWith('[')) return null;

    final typeId = await _resolveTypeIdByName(moduleName);
    if (typeId == null) return null;
    final moduleType = await _sdeService.getModuleType(typeId);
    final slotType = moduleType?.slotType ?? fallbackSlot;
    return FittedModule(
      typeId: typeId,
      typeName: moduleType?.name ?? moduleName,
      slotType: slotType,
      slotIndex: slotIndex,
      state: ModuleState.online,
      attributes: moduleType?.baseAttributes ?? const {},
    );
  }

  Future<int?> _resolveTypeIdByName(String name) async {
    final normalized = _normalizeName(name);
    final matches = await _searchTypesByName(name);
    for (final match in matches) {
      if (_normalizeName(match.typeName) == normalized) return match.typeId;
    }
    return null;
  }

  Future<List<SdeType>> _searchTypesByName(String name) async {
    try {
      return _sdeService.database.searchTypesByName(name, limit: 20);
    } catch (e) {
      if (!_reverseLookupUnavailableLogged) {
        Log.w('FITTING', 'SDE reverse lookup unavailable; parsing shell fit');
        _reverseLookupUnavailableLogged = true;
      }
      return const [];
    }
  }

  String _normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Parse a DNA string into a [Fitting].
  ///
  /// Format example: 587:2048;1:3172;2::
  ///
  /// Each `typeId;quantity` segment is expanded into that many fitted modules
  /// and placed by the module's real slot type. Dropping the modules here
  /// (as an earlier TODO did) made every DNA import a bare hull, and the
  /// Combat Analyzer then recorded that empty hull as confirmed evidence.
  Future<Fitting?> parseDna(String dnaString) async {
    Log.d('FITTING', 'Parsing DNA string: $dnaString');
    try {
      final parts = dnaString.split(':');
      if (parts.length < 2) return null;

      final shipTypeId = int.tryParse(parts[0]);
      if (shipTypeId == null) return null;

      final shipTypeName = await _sdeService.getShipTypeName(shipTypeId);

      final lowSlots = <FittedModule>[];
      final medSlots = <FittedModule>[];
      final highSlots = <FittedModule>[];
      final rigSlots = <FittedModule>[];
      final subsystemSlots = <FittedModule>[];

      // Parse modules...
      // e.g. 2048;1 -> typeId 2048, qty 1
      for (int i = 1; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;

        final modParts = part.split(';');
        if (modParts.isEmpty) continue;

        final typeId = int.tryParse(modParts[0]);
        if (typeId == null) continue;

        final quantity = modParts.length > 1
            ? (int.tryParse(modParts[1]) ?? 1)
            : 1;

        // Load module type from SDE
        final modType = await _sdeService.getModuleType(typeId);
        if (modType == null) continue;

        for (var copy = 0; copy < quantity; copy++) {
          final target = switch (modType.slotType) {
            SlotType.low => lowSlots,
            SlotType.med => medSlots,
            SlotType.high => highSlots,
            SlotType.rig => rigSlots,
            SlotType.subsystem => subsystemSlots,
          };
          target.add(
            FittedModule(
              typeId: typeId,
              typeName: modType.name,
              slotType: modType.slotType,
              slotIndex: target.length,
              state: ModuleState.online,
              attributes: modType.baseAttributes,
            ),
          );
        }
      }

      final moduleCount =
          lowSlots.length +
          medSlots.length +
          highSlots.length +
          rigSlots.length +
          subsystemSlots.length;
      Log.i(
        'FITTING',
        'parseDna - ship $shipTypeId with $moduleCount modules',
      );

      return Fitting(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Imported $shipTypeName',
        shipTypeId: shipTypeId,
        shipName: shipTypeName,
        highSlots: highSlots,
        medSlots: medSlots,
        lowSlots: lowSlots,
        rigSlots: rigSlots,
        subsystems: subsystemSlots,
      );
    } catch (e, stack) {
      Log.e('FITTING', 'Error parsing DNA', e, stack);
      return null;
    }
  }

  /// Generate EFT format from a [Fitting].
  String generateEft(Fitting fitting) {
    final buffer = StringBuffer();
    buffer.writeln('[${fitting.shipName}, ${fitting.name}]');

    for (final mod in fitting.lowSlots) {
      buffer.writeln(mod.typeName);
    }
    buffer.writeln();

    for (final mod in fitting.medSlots) {
      buffer.writeln(mod.typeName);
    }
    buffer.writeln();

    for (final mod in fitting.highSlots) {
      buffer.writeln(mod.typeName);
    }
    buffer.writeln();

    for (final mod in fitting.rigSlots) {
      buffer.writeln(mod.typeName);
    }

    return buffer.toString().trim();
  }

  /// Generate DNA format from a [Fitting].
  String generateDna(Fitting fitting) {
    final buffer = StringBuffer();
    buffer.write('${fitting.shipTypeId}:');

    final counts = <int, int>{};
    for (final mod in fitting.allModules) {
      counts[mod.typeId] = (counts[mod.typeId] ?? 0) + 1;
    }

    for (final entry in counts.entries) {
      buffer.write('${entry.key};${entry.value}:');
    }

    buffer.write(':'); // End with double colon
    return buffer.toString();
  }
}
