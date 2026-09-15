import 'dart:convert';

import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_database.dart';
import '../../../core/sde/sde_service.dart';
import '../../fitting/domain/format_parser.dart';
import '../../fitting/domain/models.dart';

/// Shared-parser factory used by AAR import. GREEN supplies the exact-name
/// resolver and `rethrowFailures`; the default constructs today's parser.
typedef AarSharedParserFactory =
    FittingFormatParser Function({
      required SdeService sdeService,
      Future<int?> Function(String name)? resolveTypeIdByName,
      bool rethrowFailures,
    });

enum AarFitImportFailureCode {
  malformedFit,
  unresolvedEntries,
  unsupportedLoadedAmmunition,
  localDataUnavailable,
}

final class AarFitImportException extends FormatException {
  AarFitImportException(
    super.message, {
    required this.code,
    this.sourceLines = const [],
  });

  final AarFitImportFailureCode code;
  final List<int> sourceLines;
}

/// Strict AAR fit-import adapter.
///
/// Resource limits (malformed if exceeded, never truncated):
/// 256 KiB UTF-8 input, 4,096 expanded modules, signed 32-bit quantities.
final class AarFitImportParser {
  AarFitImportParser({required this.sdeService, this.parserFactory});

  static const int maxUtf8Bytes = 256 * 1024;
  static const int maxExpandedModules = 4096;
  static const int maxQuantity = 2147483647;
  static const int shipCategoryId = 6;
  static const int moduleCategoryId = 7;
  static const int subsystemCategoryId = 32;
  static const int droneCategoryId = 18;
  static const int fighterCategoryId = 87;
  static const String genericHullMessage =
      'Unable to resolve the pasted fit. Paste an EFT fit with a known ship and modules.';

  static const _placeholders = {
    '[Empty Low slot]',
    '[Empty Med slot]',
    '[Empty High slot]',
    '[Empty Rig slot]',
    '[Empty Subsystem slot]',
  };

  static const _slotEffects = {
    11: SlotType.low,
    12: SlotType.high,
    13: SlotType.med,
    2663: SlotType.rig,
    3772: SlotType.subsystem,
  };

  final SdeService sdeService;
  final AarSharedParserFactory? parserFactory;

  Future<Fitting> parse(String rawFit) async {
    Log.d(
      'AAR',
      'AarFitImportParser.parse bytes=${utf8.encode(rawFit).length}',
    );
    if (utf8.encode(rawFit).length > maxUtf8Bytes) {
      throw AarFitImportException(
        'Fit text exceeds the 256 KiB import limit.',
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    final text = rawFit.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (text.isEmpty) {
      throw AarFitImportException(
        'Fit text is empty.',
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    try {
      return await sdeService.database.transaction(() async {
        if (_firstNonemptyStartsWithBracket(text)) {
          return _parseEft(text);
        }
        return _parseDna(text);
      });
    } on AarFitImportException {
      rethrow;
    } catch (e, stack) {
      Log.e('AAR', 'fit import local SDE unavailable', e, stack);
      throw AarFitImportException(
        'Local fitting data is unavailable.',
        code: AarFitImportFailureCode.localDataUnavailable,
      );
    }
  }

  bool _firstNonemptyStartsWithBracket(String text) {
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      return trimmed.startsWith('[');
    }
    return false;
  }

  Future<Fitting> _parseEft(String text) async {
    final lines = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (lines.isEmpty) {
      throw AarFitImportException(
        genericHullMessage,
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    final headerMatch = RegExp(r'^\[(.*),\s*(.*)\]$').firstMatch(lines.first);
    if (headerMatch == null) {
      throw AarFitImportException(
        genericHullMessage,
        code: AarFitImportFailureCode.malformedFit,
        sourceLines: const [1],
      );
    }
    final shipName = headerMatch.group(1)!.trim();
    final fitName = headerMatch.group(2)!.trim();
    if (shipName.isEmpty) {
      throw AarFitImportException(
        genericHullMessage,
        code: AarFitImportFailureCode.malformedFit,
        sourceLines: const [1],
      );
    }

    final index = await _loadNameIndex();
    final hullId = _uniqueName(
      index,
      shipName,
      unknownCode: AarFitImportFailureCode.malformedFit,
      unknownMessage: genericHullMessage,
    );
    final hull = await _struct(hullId);
    if (hull.categoryId != shipCategoryId) {
      throw AarFitImportException(
        genericHullMessage,
        code: AarFitImportFailureCode.malformedFit,
        sourceLines: const [1],
      );
    }

    final expectedModules = <_CountKey, int>{};
    final expectedDrones = <int, int>{};
    final expectedFighters = <int, int>{};
    var expanded = 0;

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (_placeholders.contains(line)) continue;
      if (line.startsWith('[')) {
        throw AarFitImportException(
          'Unrecognized bracketed fit line.',
          code: AarFitImportFailureCode.malformedFit,
          sourceLines: [i + 1],
        );
      }
      if (line.contains(',')) {
        throw AarFitImportException(
          'Loaded ammunition in EFT is not supported by this import.',
          code: AarFitImportFailureCode.unsupportedLoadedAmmunition,
          sourceLines: [i + 1],
        );
      }
      final stack = RegExp(r'^(.+?) x(\d+)$').firstMatch(line);
      if (stack != null) {
        final qty = _parseQuantity(stack.group(2)!, lineNumber: i + 1);
        final typeId = _uniqueName(index, stack.group(1)!.trim());
        final item = await _struct(typeId);
        if (item.categoryId == droneCategoryId) {
          _addCount(expectedDrones, typeId, qty);
        } else if (item.categoryId == fighterCategoryId) {
          _addCount(expectedFighters, typeId, qty);
        } else {
          throw AarFitImportException(
            'Stacked EFT lines must be drones or fighters.',
            code: AarFitImportFailureCode.malformedFit,
            sourceLines: [i + 1],
          );
        }
        expanded = _addExpanded(expanded, qty);
        continue;
      }

      final typeId = _uniqueName(index, line);
      final item = await _struct(typeId);
      if (item.categoryId != moduleCategoryId) {
        throw AarFitImportException(
          'EFT body items must be modules, drones, or fighters.',
          code: AarFitImportFailureCode.malformedFit,
          sourceLines: [i + 1],
        );
      }
      final slot = _slotIdentity(item.effects);
      if (slot == null || slot == SlotType.subsystem) {
        throw AarFitImportException(
          'Module slot identity is missing or unsupported.',
          code: AarFitImportFailureCode.malformedFit,
          sourceLines: [i + 1],
        );
      }
      _addKeyCount(expectedModules, _CountKey(typeId, slot), 1);
      expanded = _addExpanded(expanded, 1);
    }

    final parsed = await _sharedParser(index).parseEft(text);
    _compare(
      parsed: parsed,
      hullId: hullId,
      shipName: hull.type.typeName,
      fitName: fitName,
      modules: expectedModules,
      drones: expectedDrones,
      fighters: expectedFighters,
      requireFitName: true,
    );
    Log.i('AAR', 'imported EFT ship=$shipName modules=$expanded name=$fitName');
    return parsed!;
  }

  Future<Fitting> _parseDna(String text) async {
    final compact = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (compact.length != 1) {
      throw AarFitImportException(
        genericHullMessage,
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    final dna = compact.single;
    final parts = dna.split(':');
    if (parts.length < 2) {
      throw AarFitImportException(
        genericHullMessage,
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    var end = parts.length;
    var trailing = 0;
    while (end > 1 && parts[end - 1].isEmpty) {
      trailing++;
      end--;
    }
    if (trailing > 2) {
      throw AarFitImportException(
        'DNA has too many trailing delimiters.',
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    final hullId = _parsePositiveId(parts[0]);
    final hullType = await sdeService.database.getType(hullId);
    if (hullType == null) {
      throw AarFitImportException(
        genericHullMessage,
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    final hull = await _struct(hullId);
    if (hull.categoryId != shipCategoryId) {
      throw AarFitImportException(
        genericHullMessage,
        code: AarFitImportFailureCode.malformedFit,
      );
    }

    final expectedModules = <_CountKey, int>{};
    var expanded = 0;
    for (var i = 1; i < end; i++) {
      if (parts[i].isEmpty) {
        throw AarFitImportException(
          'DNA contains an empty interior segment.',
          code: AarFitImportFailureCode.malformedFit,
        );
      }
      final fields = parts[i].split(';');
      if (fields.length > 2) {
        throw AarFitImportException(
          'DNA segment has extra fields.',
          code: AarFitImportFailureCode.malformedFit,
        );
      }
      final typeId = _parsePositiveId(fields[0]);
      final qty = fields.length == 2 ? _parseQuantity(fields[1]) : 1;
      final item = await _struct(typeId);
      final slot = _slotIdentity(item.effects);
      final isModule = item.categoryId == moduleCategoryId && slot != null;
      final isSubsystem =
          item.categoryId == subsystemCategoryId && slot == SlotType.subsystem;
      if (!isModule && !isSubsystem) {
        throw AarFitImportException(
          'DNA entries must be modules or subsystems with explicit slots.',
          code: AarFitImportFailureCode.malformedFit,
        );
      }
      _addKeyCount(expectedModules, _CountKey(typeId, slot!), qty);
      expanded = _addExpanded(expanded, qty);
    }

    final parsed = await _sharedParser(const {}).parseDna(dna);
    _compare(
      parsed: parsed,
      hullId: hullId,
      shipName: hull.type.typeName,
      fitName: null,
      modules: expectedModules,
      drones: const {},
      fighters: const {},
      requireFitName: false,
    );
    Log.i('AAR', 'imported DNA ship=${hull.type.typeName} modules=$expanded');
    return parsed!;
  }

  FittingFormatParser _sharedParser(Map<String, List<int>> index) {
    Future<int?> resolve(String name) async {
      final ids = index[_normalize(name)];
      if (ids == null || ids.length != 1) return null;
      return ids.single;
    }

    final factory = parserFactory ?? _defaultFactory;
    return factory(
      sdeService: sdeService,
      resolveTypeIdByName: resolve,
      rethrowFailures: true,
    );
  }

  static FittingFormatParser _defaultFactory({
    required SdeService sdeService,
    Future<int?> Function(String name)? resolveTypeIdByName,
    bool rethrowFailures = false,
  }) {
    return FittingFormatParser(
      sdeService,
      resolveTypeIdByName: resolveTypeIdByName,
      rethrowFailures: rethrowFailures,
    );
  }

  Future<Map<String, List<int>>> _loadNameIndex() async {
    final types = await sdeService.database
        .select(sdeService.database.sdeTypes)
        .get();
    final index = <String, List<int>>{};
    for (final type in types) {
      index.putIfAbsent(_normalize(type.typeName), () => []).add(type.typeId);
    }
    return index;
  }

  int _uniqueName(
    Map<String, List<int>> index,
    String name, {
    AarFitImportFailureCode unknownCode =
        AarFitImportFailureCode.unresolvedEntries,
    String unknownMessage = 'Some fit entries could not be resolved.',
  }) {
    final ids = index[_normalize(name)];
    if (ids == null || ids.isEmpty) {
      throw AarFitImportException(unknownMessage, code: unknownCode);
    }
    if (ids.length != 1) {
      throw AarFitImportException(
        'Some fit entries could not be resolved.',
        code: AarFitImportFailureCode.unresolvedEntries,
      );
    }
    return ids.single;
  }

  Future<_TypeStruct> _struct(int typeId) async {
    final type = await sdeService.database.getType(typeId);
    if (type == null) {
      throw AarFitImportException(
        'Some fit entries could not be resolved.',
        code: AarFitImportFailureCode.unresolvedEntries,
      );
    }
    final group = await sdeService.database.getGroup(type.groupId);
    if (group == null) {
      throw AarFitImportException(
        'Some fit entries could not be resolved.',
        code: AarFitImportFailureCode.unresolvedEntries,
      );
    }
    final effects = await sdeService.database.getTypeEffects(typeId);
    return _TypeStruct(
      type: type,
      categoryId: group.categoryId,
      effects: effects,
    );
  }

  SlotType? _slotIdentity(List<int> effects) {
    SlotType? found;
    for (final effectId in effects) {
      final slot = _slotEffects[effectId];
      if (slot == null) continue;
      if (found != null && found != slot) return null;
      found = slot;
    }
    return found;
  }

  void _compare({
    required Fitting? parsed,
    required int hullId,
    required String shipName,
    required String? fitName,
    required Map<_CountKey, int> modules,
    required Map<int, int> drones,
    required Map<int, int> fighters,
    required bool requireFitName,
  }) {
    if (parsed == null || parsed.shipTypeId != hullId) {
      throw AarFitImportException(
        'Some fit entries could not be resolved.',
        code: AarFitImportFailureCode.unresolvedEntries,
      );
    }
    if (parsed.shipName != shipName) {
      throw AarFitImportException(
        'Some fit entries could not be resolved.',
        code: AarFitImportFailureCode.unresolvedEntries,
      );
    }
    if (requireFitName && parsed.name != fitName) {
      throw AarFitImportException(
        'Some fit entries could not be resolved.',
        code: AarFitImportFailureCode.unresolvedEntries,
      );
    }
    if (parsed.cargo.isNotEmpty ||
        parsed.allModules.any((module) => module.chargeTypeId != null)) {
      throw AarFitImportException(
        'Some fit entries could not be resolved.',
        code: AarFitImportFailureCode.unresolvedEntries,
      );
    }
    final gotModules = <_CountKey, int>{};
    for (final module in parsed.allModules) {
      _addKeyCount(gotModules, _CountKey(module.typeId, module.slotType), 1);
    }
    if (!_sameKeyCounts(gotModules, modules) ||
        !_sameCounts(_droneCounts(parsed), drones) ||
        !_sameCounts(_fighterCounts(parsed), fighters)) {
      throw AarFitImportException(
        'Some fit entries could not be resolved.',
        code: AarFitImportFailureCode.unresolvedEntries,
      );
    }
  }

  Map<int, int> _droneCounts(Fitting fitting) {
    final counts = <int, int>{};
    for (final drone in fitting.drones) {
      _addCount(counts, drone.typeId, drone.quantity);
    }
    return counts;
  }

  Map<int, int> _fighterCounts(Fitting fitting) {
    final counts = <int, int>{};
    for (final fighter in fitting.fighters) {
      _addCount(counts, fighter.typeId, fighter.quantity);
    }
    return counts;
  }

  bool _sameKeyCounts(Map<_CountKey, int> a, Map<_CountKey, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool _sameCounts(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _addCount(Map<int, int> counts, int typeId, int quantity) {
    final next = (counts[typeId] ?? 0) + quantity;
    if (next > maxQuantity) {
      throw AarFitImportException(
        'Fit quantity exceeds the import limit.',
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    counts[typeId] = next;
  }

  void _addKeyCount(Map<_CountKey, int> counts, _CountKey key, int quantity) {
    final next = (counts[key] ?? 0) + quantity;
    if (next > maxQuantity) {
      throw AarFitImportException(
        'Fit quantity exceeds the import limit.',
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    counts[key] = next;
  }

  int _addExpanded(int current, int quantity) {
    final next = current + quantity;
    if (next > maxExpandedModules) {
      throw AarFitImportException(
        'Fit exceeds the 4096-module import limit.',
        code: AarFitImportFailureCode.malformedFit,
      );
    }
    return next;
  }

  int _parsePositiveId(String raw) => _parseQuantity(raw);

  int _parseQuantity(String raw, {int? lineNumber}) {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(raw)) {
      throw AarFitImportException(
        'Fit quantity is invalid.',
        code: AarFitImportFailureCode.malformedFit,
        sourceLines: lineNumber == null ? const [] : [lineNumber],
      );
    }
    final value = int.parse(raw);
    if (value > maxQuantity) {
      throw AarFitImportException(
        'Fit quantity exceeds the import limit.',
        code: AarFitImportFailureCode.malformedFit,
        sourceLines: lineNumber == null ? const [] : [lineNumber],
      );
    }
    return value;
  }

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

final class _CountKey {
  const _CountKey(this.typeId, this.slot);

  final int typeId;
  final SlotType slot;

  @override
  bool operator ==(Object other) =>
      other is _CountKey && other.typeId == typeId && other.slot == slot;

  @override
  int get hashCode => Object.hash(typeId, slot);
}

final class _TypeStruct {
  const _TypeStruct({
    required this.type,
    required this.categoryId,
    required this.effects,
  });

  final SdeType type;
  final int categoryId;
  final List<int> effects;
}
