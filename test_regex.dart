import 'dart:io';

void main() {
  final file = File('test/features/combat_analyzer/fixtures/merlin_combat_log.txt');
  final lines = file.readAsLinesSync();

  final timestampRegex = RegExp(r'\[\s*(.*?)\s*\]\s*\(combat\)\s*(.*)');
  final incomingDamagePattern = RegExp(r'^(\d+) from (.*?)\s+-\s+(.*?)\s+-\s+(.*)$');
  final outgoingDamagePattern = RegExp(r'^(\d+) to (.*?)\s+-\s+(.*?)\s+-\s+(.*)$');
  final incomingMissPattern = RegExp(r'^(.*?) misses you completely\s+-\s+(.*)$');
  final outgoingMissPattern = RegExp(r'^Your (.*?) misses (.*?) completely$');

  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('-----')) continue;
    print('LINE: $line');
    
    final match = timestampRegex.firstMatch(line);
    if (match != null) {
      final timeStr = match.group(1);
      final msg = match.group(2)!;
      print('  Time: $timeStr | Msg: $msg');
      
      final inDam = incomingDamagePattern.firstMatch(msg);
      if (inDam != null) {
        print('  => INCOMING DAMAGE: ${inDam.group(1)} from ${inDam.group(2)} (${inDam.group(3)})');
      }
      
      final outDam = outgoingDamagePattern.firstMatch(msg);
      if (outDam != null) {
        print('  => OUTGOING DAMAGE: ${outDam.group(1)} to ${outDam.group(2)} (${outDam.group(3)})');
      }
      
      final inMiss = incomingMissPattern.firstMatch(msg);
      if (inMiss != null) {
        print('  => INCOMING MISS from ${inMiss.group(1)}');
      }
    } else {
      if (line.startsWith('Listener:')) {
        print('  => LISTENER: ${line.substring(9).trim()}');
      }
    }
  }
}
