import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mimir/main.dart' as app;

void main() {
  patrolWidgetTest(
    'Smoke test - verify app launches and renders',
    ($) async {
      // Launch the app
      app.main([]);
      await $.pumpAndSettle();

      // Find any element to ensure rendering was successful
      expect($(RegExp('.*')), findsWidgets);
    },
  );
}
