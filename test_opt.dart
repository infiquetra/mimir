
void main() {
  final lines = [
    '---------------------------------------------------------------',
    '  Combat Log - 2026.05.20 18:30:00',
    '---------------------------------------------------------------',
    'Listener: Test Character',
    'Session Started: 2026.05.20 18:30:00',
    '---------------------------------------------------------------',
    '',
    '[ 2026.05.20 18:32:10 ] (combat) State Protector Merlin misses you completely - Light Electron Blaster I',
    '[ 2026.05.20 18:32:11 ] (combat) State Protector Merlin misses you completely - Light Electron Blaster I',
    '[ 2026.05.20 18:32:12 ] (combat) 42 from State Protector Merlin - Light Electron Blaster I - Grazes',
    '[ 2026.05.20 18:32:28 ] (combat) Warp drive active',
    '[ 2026.05.20 18:32:29 ] (combat) Warp drive active',
  ];

  final filtered = <String>[];
  String? lastMsg;
  int count = 1;
  String? lastTime;
  
  void flush() {
    if (lastMsg != null) {
      if (count > 1) {
        filtered.add('[$lastTime] ${count}x $lastMsg');
      } else {
        filtered.add('[$lastTime] $lastMsg');
      }
    }
  }

  final timestampRegex = RegExp(r'\[\s*(.*?)\s*\]\s*\(combat\)\s*(.*)');
  
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('-----')) continue;
    
    if (line.startsWith('Listener:') || line.startsWith('Session Started:')) {
      filtered.add(line.trim());
      continue;
    }
    
    final match = timestampRegex.firstMatch(line);
    if (match != null) {
       final timeFull = match.group(1)!;
       final timeOnly = timeFull.split(' ').last;
       final msg = match.group(2)!;
       
       if (msg == lastMsg) {
         count++;
       } else {
         flush();
         lastMsg = msg;
         count = 1;
         lastTime = timeOnly;
       }
    } else {
       flush();
       lastMsg = null;
       filtered.add(line.trim());
    }
  }
  flush();
  print(filtered.join('\n'));
}
