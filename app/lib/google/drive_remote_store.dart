import 'dart:async';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../sync/remote_store.dart';

/// [RemoteStore] backed by the Drive app-data folder: a hidden, per-app
/// folder the user can't see or edit, and other apps can't read.
class DriveRemoteStore implements AccountRemoteStore {
  DriveRemoteStore(http.Client client) : _api = drive.DriveApi(client);

  final drive.DriveApi _api;

  @override
  Future<List<RemoteFile>> list(String prefix) async {
    final out = <RemoteFile>[];
    String? page;
    do {
      final res = await _api.files.list(
        spaces: 'appDataFolder',
        q: 'trashed = false',
        $fields: 'nextPageToken, files(id, name, md5Checksum)',
        pageSize: 100,
        pageToken: page,
      );
      for (final f in res.files ?? const <drive.File>[]) {
        final name = f.name ?? '';
        if (f.id != null && name.startsWith(prefix)) {
          out.add(RemoteFile(f.id!, name, f.md5Checksum ?? ''));
        }
      }
      page = res.nextPageToken;
    } while (page != null);
    return out;
  }

  @override
  Future<List<int>> read(String id) async {
    final media = await _api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  @override
  Future<String> create(String name, List<int> bytes) async {
    final f = await _api.files.create(
      drive.File(name: name, parents: ['appDataFolder']),
      uploadMedia: _media(bytes),
      $fields: 'id',
    );
    return f.id!;
  }

  @override
  Future<void> update(String id, List<int> bytes) =>
      _api.files.update(drive.File(), id, uploadMedia: _media(bytes));

  @override
  Future<String?> accountEmail() async {
    final about = await _api.about.get($fields: 'user(emailAddress)');
    return about.user?.emailAddress;
  }

  /// Writes a visible JSON backup to the root of the user's Drive.
  @override
  Future<String?> exportBackup(String name, List<int> bytes) async {
    final f = await _api.files.create(
      drive.File(name: name, mimeType: 'application/json'),
      uploadMedia: _media(bytes),
      $fields: 'id, webViewLink',
    );
    return f.webViewLink;
  }

  drive.Media _media(List<int> bytes) => drive.Media(
    Stream.value(bytes),
    bytes.length,
    contentType: 'application/json',
  );
}
