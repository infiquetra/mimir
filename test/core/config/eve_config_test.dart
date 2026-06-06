import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/core/config/eve_config.dart';

void main() {
  group('EveConfig', () {
    test('requests killmail read scope for future logins', () {
      expect(EveConfig.scopesString, contains(EveConfig.killmailReadScope));
    });
  });
}
