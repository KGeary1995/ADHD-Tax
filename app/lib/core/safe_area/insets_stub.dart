import 'package:flutter/painting.dart';

/// Only the web needs this; native platforms report insets themselves.
void Function() watchSafeInsets(void Function(EdgeInsets) onChange) => () {};
