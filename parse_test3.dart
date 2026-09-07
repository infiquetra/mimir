import 'dart:io';

void main() async {
  final file = File(
    'test/features/combat_analyzer/fixtures/merlin_combat_log.txt',
  );
  final lines = await file.readAsLines();

  int damageDealt = 0;
  int damageReceived = 0;

  final htmlTagRegex = RegExp(r'<[^>]*>');

  for (final line in lines) {
    if (line.startsWith('[ ')) {
      String cleanLine = line.replaceAll(htmlTagRegex, '');
      final timestampRegex = RegExp(
        r'^\[ \d{4}\.\d{2}\.\d{2} (\d{2}:\d{2}:\d{2}) \] \(combat\) (.*)',
      );
      final match = timestampRegex.firstMatch(cleanLine);

      if (match != null) {
        final actionText = match.group(2)!.trim();
        final dmgRegex = RegExp(r'^(\d+) (to|from) (.*?) - (.*?) - (.*)$');
        final dmgMatch = dmgRegex.firstMatch(actionText);

        if (dmgMatch != null) {
          final amount = int.parse(dmgMatch.group(1)!);
          final direction = dmgMatch.group(2)!;
          if (direction == 'to') {
            damageDealt += amount;
          } else if (direction == 'from') {
            damageReceived += amount;
          }
        }
      }
    }
  }

  print('Damage Dealt: $damageDealt');
  print('Damage Received: $damageReceived');
}
