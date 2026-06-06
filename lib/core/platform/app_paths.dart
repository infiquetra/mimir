import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/logger.dart';

String? _applicationSupportPath;

/// Sets the resolved application support path for secondary Flutter engines.
void setMimirApplicationSupportPath(String path) {
  _applicationSupportPath = path;
  Log.d('PATH', 'Application support path set');
}

/// Returns Mimir's application support directory.
///
/// The main window resolves this through path_provider and passes it to
/// sub-windows, because sub-window engines do not have native plugins
/// registered.
Future<String> getMimirApplicationSupportPath() async {
  if (_applicationSupportPath != null) return _applicationSupportPath!;

  final directory = await getApplicationSupportDirectory();
  _applicationSupportPath = directory.path;
  Log.d('PATH', 'Resolved application support path');
  return _applicationSupportPath!;
}

/// Returns the app-owned auth store path.
Future<String> getMimirAuthFilePath() async {
  final supportPath = await getMimirApplicationSupportPath();
  return p.join(supportPath, 'auth.json');
}

@visibleForTesting
void resetMimirApplicationSupportPathForTesting() {
  _applicationSupportPath = null;
}
