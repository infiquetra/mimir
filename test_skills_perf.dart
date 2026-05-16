import 'package:mimir/core/database/app_database.dart';
import 'package:drift/native.dart';

void main() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final start = DateTime.now();
  final skills = await db.getAllSkills();
  final end = DateTime.now();
  print('Loaded ${skills.length} skills in ${end.difference(start).inMilliseconds}ms');
}
