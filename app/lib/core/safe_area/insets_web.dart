import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

/// Reports the iPhone's notch / home-indicator insets (CSS
/// `env(safe-area-inset-*)`), which Flutter's web engine doesn't pass on.
/// Returns a function that stops watching.
void Function() watchSafeInsets(void Function(EdgeInsets) onChange) {
  _extendUnderSystemBars();

  // Safari only exposes env() values through CSS, so measure an invisible
  // element padded by them.
  final probe = web.document.createElement('div') as web.HTMLDivElement;
  probe.style.cssText =
      'position:fixed;top:0;left:0;width:0;height:0;visibility:hidden;'
      'pointer-events:none;padding:env(safe-area-inset-top) '
      'env(safe-area-inset-right) env(safe-area-inset-bottom) '
      'env(safe-area-inset-left);';
  web.document.body?.append(probe);

  EdgeInsets read() {
    final cs = web.window.getComputedStyle(probe);
    double px(String v) => double.tryParse(v.replaceAll('px', '')) ?? 0;
    return EdgeInsets.fromLTRB(
      px(cs.paddingLeft),
      px(cs.paddingTop),
      px(cs.paddingRight),
      px(cs.paddingBottom),
    );
  }

  var last = EdgeInsets.zero;
  void check() {
    final now = read();
    if (now != last) {
      last = now;
      onChange(now);
    }
  }

  final onResize = ((web.Event _) => check()).toJS;
  web.window.addEventListener('resize', onResize);
  // The viewport change above applies after the next layout.
  final timers = [
    for (final ms in [0, 100, 600]) Timer(Duration(milliseconds: ms), check),
  ];
  return () {
    for (final t in timers) {
      t.cancel();
    }
    web.window.removeEventListener('resize', onResize);
    probe.remove();
  };
}

/// Flutter rewrites the viewport tag at startup, dropping `viewport-fit`.
/// Without `cover`, Safari reports every inset as zero.
void _extendUnderSystemBars() {
  final metas = web.document.querySelectorAll('meta[name="viewport"]');
  for (var i = 0; i < metas.length; i++) {
    final node = metas.item(i);
    if (node == null || !node.isA<web.HTMLMetaElement>()) continue;
    final m = node as web.HTMLMetaElement;
    if (!m.content.contains('viewport-fit')) {
      m.content = '${m.content}, viewport-fit=cover';
    }
  }
}
