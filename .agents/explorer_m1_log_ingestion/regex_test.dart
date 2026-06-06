import 'dart:io';

void main() async {
  final file = File('test/features/combat_analyzer/fixtures/merlin_combat_log.txt');
  final lines = await file.readAsLines();

  final listenerRegex = RegExp(r'^Listener:\s+(.*)$');
  final incomingDamageRegex = RegExp(r'^\[ (.*?) \] \(combat\) (\d+) from (.*?) - (.*?) - (.*)$');
  final outgoingDamageRegex = RegExp(r'^\[ (.*?) \] \(combat\) (\d+) to (.*?) - (.*?) - (.*)$');
  final missRegex = RegExp(r'^\[ (.*?) \] \(combat\) (.*?) misses you completely - (.*)$');

  String? characterName;
  for (var line in lines) {
    if (listenerRegex.hasMatch(line)) {
      characterName = listenerRegex.firstMatch(line)!.group(1);
      print('Found character: $characterName');
    } else if (incomingDamageRegex.hasMatch(line)) {
      final match = incomingDamageRegex.firstMatch(line)!;
      print('Incoming: ${match.group(2)} dmg from ${match.group(3)}');
    } else if (outgoingDamageRegex.hasMatch(line)) {
      final match = outgoingDamageRegex.firstMatch(line)!;
      print('Outgoing: ${match.group(2)} dmg to ${match.group(3)}');
    } else if (missRegex.hasMatch(line)) {
      final match = missRegex.firstMatch(line)!;
      print('Miss from: ${match.group(2)}');
    }
  }
}
