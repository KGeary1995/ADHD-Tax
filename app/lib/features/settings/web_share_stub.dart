import 'dart:typed_data';

const isWeb = false;

/// Only browsers have a file share sheet worth preferring.
Future<bool?> shareFileOnWeb(String name, Uint8List bytes) async => null;
