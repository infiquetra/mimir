import 'dart:io';
import 'package:mimir/core/sde/sde_database.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';

void main() async {
  final dbPath = '/Users/jefcox/Library/Application Support/com.infiquetra.mimir/mimir_sde.db';
  final db = SdeDatabase.forTesting(NativeDatabase(File(dbPath)));
  
  try {
    for (var effectId in [11, 12, 13, 2663, 3146]) {
      final query = db.select(db.sdeTypeEffects)..where((tbl) => tbl.effectId.equals(effectId));
      final rows = await query.get();
      print('Effect ID $effectId has ${rows.length} modules.');
    }
  } finally {
    await db.close();
    exit(0);
  }
}
