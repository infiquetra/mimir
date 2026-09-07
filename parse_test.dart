import 'dart:io';

void main() async {
  final file = File(
    'test/features/combat_analyzer/fixtures/merlin_combat_log.txt',
  );
  final lines = await file.readAsLines();

  String listener = '';
  String sessionStarted = '';

  final htmlTagRegex = RegExp(r'<[^>]*>');

  final List<String> optimizedLines = [];

  for (final line in lines) {
    if (line.startsWith('Listener: ')) {
      listener = line.substring('Listener: '.length).trim();
      continue;
    }
    if (line.startsWith('Session Started: ')) {
      sessionStarted = line.substring('Session Started: '.length).trim();
      continue;
    }
    if (line.startsWith('[ ')) {
      // It's a log line
      // Strip html tags
      final cleanLine = line.replaceAll(htmlTagRegex, '');

      // Simplify timestamp if needed
      // Format is [ YYYY.MM.DD HH:MM:SS ]
      final timestampRegex = RegExp(
        r'^\[ \d{4}\.\d{2}\.\d{2} (\d{2}:\d{2}:\d{2}) \]',
      );
      final match = timestampRegex.firstMatch(cleanLine);

      String resultLine = cleanLine;
      if (match != null) {
        final timeOnly = match.group(1);
        resultLine = cleanLine.replaceFirst(
          RegExp(r'^\[ .*? \] \(combat\) '),
          '[$timeOnly] ',
        );
      }

      optimizedLines.add(resultLine);
    }
  }

  print('Listener: $listener');
  print('Session Started: $sessionStarted');
  print('--- Optimized Lines ---');
  for (final l in optimizedLines) {
    print(l);
  }
}
