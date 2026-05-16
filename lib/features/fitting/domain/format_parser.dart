import '../../../core/logging/logger.dart';
import '../../../core/sde/sde_service.dart';
import 'models.dart';

/// Parses and generates EVE Online fitting formats.
/// Supports both EFT (text block) and DNA (in-game links).
class FittingFormatParser {
  final SdeService _sdeService;

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
      final lines = eftString.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) return null;

      // First line is [ShipType, FittingName]
      final headerMatch = RegExp(r'^\[(.*),\s*(.*)\]$').firstMatch(lines[0]);
      if (headerMatch == null) {
        Log.w('FITTING', 'Invalid EFT header: ${lines[0]}');
        return null;
      }

      final shipTypeName = headerMatch.group(1)!;
      final fittingName = headerMatch.group(2)!;

      // We need to resolve ShipType name to typeId.
      // SDE service doesn't have a reverse lookup (name -> ID) out of the box,
      // so this requires an SDE database query or an in-memory map.
      // For now, we will just use a placeholder or require the user to pass ShipTypeId.
      
      // TODO: Implement actual SDE lookups for name -> ID.
      // This is a placeholder that will need the SDE service to support reverse lookups.

      return Fitting(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: fittingName,
        shipTypeId: 0, // Placeholder
        shipName: shipTypeName,
        highSlots: [],
        medSlots: [],
        lowSlots: [],
        rigSlots: [],
      );
    } catch (e, stack) {
      Log.e('FITTING', 'Error parsing EFT', e, stack);
      return null;
    }
  }

  /// Parse a DNA string into a [Fitting].
  ///
  /// Format example: 587:2048;1:3172;2::
  Future<Fitting?> parseDna(String dnaString) async {
    Log.d('FITTING', 'Parsing DNA string: $dnaString');
    try {
      final parts = dnaString.split(':');
      if (parts.length < 2) return null;

      final shipTypeId = int.tryParse(parts[0]);
      if (shipTypeId == null) return null;

      final shipTypeName = await _sdeService.getShipTypeName(shipTypeId);
      
      final fitting = Fitting(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Imported $shipTypeName',
        shipTypeId: shipTypeId,
        shipName: shipTypeName,
        highSlots: [],
        medSlots: [],
        lowSlots: [],
        rigSlots: [],
      );

      // Parse modules...
      // e.g. 2048;1 -> typeId 2048, qty 1
      for (int i = 1; i < parts.length; i++) {
        final part = parts[i];
        if (part.isEmpty) continue;
        
        final modParts = part.split(';');
        if (modParts.isEmpty) continue;
        
        final typeId = int.tryParse(modParts[0]);
        if (typeId == null) continue;
        
        final qty = modParts.length > 1 ? int.tryParse(modParts[1]) ?? 1 : 1;
        
        // Load module type from SDE
        final modType = await _sdeService.getModuleType(typeId);
        if (modType == null) continue;
        
        // Add to appropriate slot
        // TODO: Actually add to fitting slots based on modType.slotType
      }
      
      return fitting;
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
