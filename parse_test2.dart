import 'dart:io';

void main() async {
  final file = File(
    'test/features/combat_analyzer/fixtures/merlin_combat_log.txt',
  );
  final lines = await file.readAsLines();

  String listener = '';
  final htmlTagRegex = RegExp(r'<[^>]*>');
  final List<String> optimizedLines = [];

  String? lastActionText;
  String? firstTime;
  String? lastTime;
  int count = 0;

  void flush() {
    if (count > 0 && lastActionText != null) {
      if (count == 1) {
        optimizedLines.add('[$firstTime] $lastActionText');
      } else {
        optimizedLines.add(
          '[$firstTime - $lastTime] ${count}x $lastActionText',
        );
      }
      count = 0;
      lastActionText = null;
      firstTime = null;
      lastTime = null;
    }
  }

  for (final line in lines) {
    if (line.startsWith('Listener: ')) {
      listener = line.substring('Listener: '.length).trim();
      continue;
    }
    if (line.startsWith('[ ')) {
      String cleanLine = line.replaceAll(htmlTagRegex, '');
      final timestampRegex = RegExp(
        r'^\[ \d{4}\.\d{2}\.\d{2} (\d{2}:\d{2}:\d{2}) \] \(combat\) (.*)',
      );
      final match = timestampRegex.firstMatch(cleanLine);

      if (match != null) {
        final timeOnly = match.group(1)!;
        final actionText = match.group(2)!.trim();

        if (actionText == lastActionText) {
          count++;
          lastTime = timeOnly;
        } else {
          flush();
          lastActionText = actionText;
          firstTime = timeOnly;
          lastTime = timeOnly;
          count = 1;
        }
      } else {
        flush();
        optimizedLines.add(cleanLine);
      }
    } else {
      flush();
    }
  }
  flush();

  print('Listener: $listener');
  print('--- Optimized Lines ---');
  for (final l in optimizedLines) {
    print(l);
  }
}
