import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'insets_stub.dart' if (dart.library.js_interop) 'insets_web.dart';

/// On the web (the iPhone home-screen app), feeds the notch and
/// home-indicator insets into [MediaQuery], so SafeArea, the bottom
/// navigation bar and sheets keep clear of them as they do natively.
/// Elsewhere it does nothing.
class WebSafeArea extends StatefulWidget {
  const WebSafeArea({super.key, required this.child});
  final Widget child;

  @override
  State<WebSafeArea> createState() => _WebSafeAreaState();
}

class _WebSafeAreaState extends State<WebSafeArea> {
  EdgeInsets _insets = EdgeInsets.zero;
  late final void Function() _stop;

  @override
  void initState() {
    super.initState();
    _stop = watchSafeInsets((i) {
      if (mounted) setState(() => _insets = i);
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_insets == EdgeInsets.zero) return widget.child;
    final mq = MediaQuery.of(context);
    final vp = mq.viewPadding;
    final viewPadding = EdgeInsets.fromLTRB(
      math.max(vp.left, _insets.left),
      math.max(vp.top, _insets.top),
      math.max(vp.right, _insets.right),
      math.max(vp.bottom, _insets.bottom),
    );
    return MediaQuery(
      data: mq.copyWith(
        viewPadding: viewPadding,
        // As Flutter does natively: the keyboard covers the home indicator.
        padding: viewPadding.copyWith(
          bottom: math.max(0, viewPadding.bottom - mq.viewInsets.bottom),
        ),
      ),
      child: widget.child,
    );
  }
}
