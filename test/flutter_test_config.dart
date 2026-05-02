import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:network_image_mock/network_image_mock.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() async {
    // Load fonts so they render correctly in golden tests
    await loadAppFonts();
  });
  return mockNetworkImagesFor(() => testMain());
}
