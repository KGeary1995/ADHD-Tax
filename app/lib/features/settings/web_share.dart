import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

const isWeb = true;

/// Opens the phone's share sheet with the file. Returns true when shared,
/// false when the user closed the sheet, and null when there is no share
/// sheet (desktop browsers), so the caller downloads instead.
///
/// Nothing is awaited before `share()`: Safari only allows it straight
/// after the tap.
Future<bool?> shareFileOnWeb(String name, Uint8List bytes) async {
  if (!web.window.matchMedia('(pointer: coarse)').matches) return null;
  final file = web.File(
    [bytes.toJS].toJS,
    name,
    web.FilePropertyBag(type: 'application/json'),
  );
  final data = web.ShareData(files: [file].toJS, title: name);
  try {
    if (!web.window.navigator.canShare(data)) return null;
  } on Object {
    return null; // No canShare at all (older browsers).
  }
  try {
    await web.window.navigator.share(data).toDart;
    return true;
  } on Object catch (e) {
    // AbortError: the user closed the sheet. Anything else: fall back.
    return e.toString().contains('AbortError') ? false : null;
  }
}
