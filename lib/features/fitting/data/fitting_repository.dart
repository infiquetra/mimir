import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/logging/logger.dart';
import '../domain/models.dart';

/// Repository for managing Saved Fittings.
class FittingRepository {
  final AppDatabase _database;

  FittingRepository(this._database);

  /// Get all saved fittings for a character (or shared fittings if characterId is null).
  Future<List<Fitting>> getFittings({required int? characterId}) async {
    Log.d('FITTING', 'getFittings(characterId: $characterId) - START');
    try {
      final query = _database.select(_database.savedFittings);
      if (characterId != null) {
        query.where((f) => f.characterId.equals(characterId) | f.characterId.isNull());
      } else {
        query.where((f) => f.characterId.isNull());
      }
      
      final records = await query.get();
      
      final fittings = records.map((record) {
        final jsonMap = jsonDecode(record.fittingJson) as Map<String, dynamic>;
        return Fitting.fromJson(jsonMap);
      }).toList();
      
      Log.d('FITTING', 'getFittings - SUCCESS, found ${fittings.length}');
      return fittings;
    } catch (e, stack) {
      Log.e('FITTING', 'getFittings - ERROR', e, stack);
      rethrow;
    }
  }
  
  /// Watch saved fittings for a character
  Stream<List<Fitting>> watchFittings({required int? characterId}) {
    final query = _database.select(_database.savedFittings);
    if (characterId != null) {
      query.where((f) => f.characterId.equals(characterId) | f.characterId.isNull());
    } else {
      query.where((f) => f.characterId.isNull());
    }
    
    return query.watch().map((records) {
      return records.map((record) {
        final jsonMap = jsonDecode(record.fittingJson) as Map<String, dynamic>;
        return Fitting.fromJson(jsonMap);
      }).toList();
    });
  }

  /// Save a fitting to the database.
  Future<void> saveFitting(Fitting fitting, {required int? characterId}) async {
    Log.d('FITTING', 'saveFitting(id: ${fitting.id}) - START');
    try {
      final jsonString = jsonEncode(fitting.toJson());
      
      final companion = SavedFittingsCompanion.insert(
        id: fitting.id,
        characterId: Value(characterId),
        name: fitting.name,
        description: Value(fitting.description),
        shipTypeId: fitting.shipTypeId,
        fittingJson: jsonString,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _database.into(_database.savedFittings).insertOnConflictUpdate(companion);
      Log.i('FITTING', 'saveFitting - SUCCESS');
    } catch (e, stack) {
      Log.e('FITTING', 'saveFitting - ERROR', e, stack);
      rethrow;
    }
  }

  /// Delete a fitting.
  Future<void> deleteFitting(String id) async {
    Log.d('FITTING', 'deleteFitting(id: $id) - START');
    try {
      await (_database.delete(_database.savedFittings)..where((f) => f.id.equals(id))).go();
      Log.i('FITTING', 'deleteFitting - SUCCESS');
    } catch (e, stack) {
      Log.e('FITTING', 'deleteFitting - ERROR', e, stack);
      rethrow;
    }
  }
}

/// Provider for the [FittingRepository].
final fittingRepositoryProvider = Provider<FittingRepository>((ref) {
  return FittingRepository(ref.watch(databaseProvider));
});
