import 'dart:io';

import 'package:adhd_tax/core/links.dart';
import 'package:flutter_test/flutter_test.dart';

/// The privacy and support pages ship inside the web build; the app, the
/// store listings and Google's sign-in screen all link to them.
void main() {
  for (final (link, file) in [
    (Links.privacy, 'web/privacy/index.html'),
    (Links.support, 'web/support/index.html'),
  ]) {
    test('$link is a page in web/', () {
      expect(link, '${Links.site}/${file.split('/')[1]}/');
      final html = File(file).readAsStringSync();
      expect(html, contains('info@ophthalmicacademy.com'));
      expect(html, contains('href="../legal.css"'));
      expect(html, isNot(contains('Unstuck')));
    });
  }
}
