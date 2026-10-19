import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file. A tap that would land on something else
/// (e.g. a menu item hidden under the floating nav bar) fails the test
/// instead of printing a warning: that is exactly how "Delete" became
/// untappable on phones.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  WidgetController.hitTestWarningShouldBeFatal = true;
  await testMain();
}
