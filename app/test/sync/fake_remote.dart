import 'dart:convert';

import 'package:adhd_tax/sync/remote_store.dart';
import 'package:crypto/crypto.dart' show md5;

/// In-memory stand-in for a Drive app-data folder. Several "devices" can
/// share one instance to simulate a shared account.
class FakeRemote implements RemoteStore {
  final Map<String, (String name, List<int> bytes)> files = {};
  int _ids = 0;
  int reads = 0;
  int writes = 0;
  bool failNextList = false;

  @override
  Future<List<RemoteFile>> list(String prefix) async {
    if (failNextList) {
      failNextList = false;
      throw Exception('network down');
    }
    return [
      for (final e in files.entries)
        if (e.value.$1.startsWith(prefix))
          RemoteFile(e.key, e.value.$1, md5.convert(e.value.$2).toString()),
    ];
  }

  @override
  Future<List<int>> read(String id) async {
    reads++;
    return files[id]!.$2;
  }

  @override
  Future<String> create(String name, List<int> bytes) async {
    writes++;
    final id = 'f${_ids++}';
    files[id] = (name, bytes);
    return id;
  }

  @override
  Future<void> update(String id, List<int> bytes) async {
    writes++;
    files[id] = (files[id]!.$1, bytes);
  }

  String text(String id) => utf8.decode(files[id]!.$2);
}
