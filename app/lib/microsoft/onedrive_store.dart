/// [AccountRemoteStore] on OneDrive, through Microsoft Graph. Pure Dart
/// apart from the HTTP clients it's given.
///
/// Everything lives in the app's own OneDrive folder (`Apps/Gumption`, the
/// app folder): sync files in `Sync/`, backups in `Backups/`. The
/// Files.ReadWrite.AppFolder permission reaches nothing else in OneDrive.
/// Unlike Google Drive's app-data folder, the user can see this folder.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../sync/account_auth.dart';
import '../sync/remote_store.dart';

const _graph = 'https://graph.microsoft.com/v1.0';
const _root = '$_graph/me/drive/special/approot';

/// Graph said no, for a reason other than the sign-in (that's
/// [NeedsReconnect]). Shown to the user as the sync row's message.
class OneDriveError implements Exception {
  const OneDriveError(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => switch (status) {
    403 =>
      'OneDrive refused access. A work or school account may need its '
          'admin to allow Gumption.',
    429 || 503 => 'OneDrive is busy. Will retry automatically.',
    507 => 'This OneDrive is full.',
    _ => 'OneDrive error $status${message.isEmpty ? '' : ': $message'}',
  };
}

class OneDriveStore implements AccountRemoteStore {
  /// [client] adds the Microsoft sign-in to each request. Downloads come
  /// from pre-signed links, fetched with [download] (no sign-in attached).
  OneDriveStore(this._client, {http.Client? download})
    : _download = download ?? http.Client();

  final http.Client _client;
  final http.Client _download;

  /// Graph's simple upload takes up to 4 MB; bigger files need an upload
  /// session, sent in pieces that are multiples of 320 KiB.
  static const simpleUploadLimit = 4000000;
  static const chunk = 320 * 1024 * 12;

  @override
  Future<List<RemoteFile>> list(String prefix) async {
    final out = <RemoteFile>[];
    String? next =
        '$_root:/Sync:/children?\$select=id,name,file,cTag,eTag&\$top=200';
    while (next != null) {
      final res = await _client.get(Uri.parse(next));
      // No Sync folder yet: nothing has been uploaded to this account.
      if (res.statusCode == 404) return out;
      final body = _json(_check(res));
      for (final f in (body['value'] as List? ?? const [])) {
        if (f is! Map || f['file'] == null) continue;
        final name = '${f['name'] ?? ''}';
        if (!name.startsWith(prefix)) continue;
        // cTag changes only when the content does.
        out.add(RemoteFile('${f['id']}', name, '${f['cTag'] ?? f['eTag']}'));
      }
      next = body['@odata.nextLink'] as String?;
    }
    return out;
  }

  @override
  Future<List<int>> read(String id) async {
    final item = _json(
      _check(
        await _client.get(
          Uri.parse(
            '$_graph/me/drive/items/$id?\$select=id,@microsoft.graph.downloadUrl',
          ),
        ),
      ),
    );
    final url = item['@microsoft.graph.downloadUrl'];
    if (url is! String) throw const OneDriveError(404, 'File not found');
    final res = await _download.get(Uri.parse(url));
    return _check(res).bodyBytes;
  }

  @override
  Future<String> create(String name, List<int> bytes) async =>
      _id(await _upload('$_root:/Sync/${Uri.encodeComponent(name)}:', bytes));

  @override
  Future<void> update(String id, List<int> bytes) =>
      _upload('$_graph/me/drive/items/$id', bytes);

  @override
  Future<String?> accountEmail() async {
    final me = _json(
      _check(
        await _client.get(
          Uri.parse('$_graph/me?\$select=mail,userPrincipalName'),
        ),
      ),
    );
    final mail = me['mail'] ?? me['userPrincipalName'];
    return mail is String && mail.isNotEmpty ? mail : null;
  }

  /// A readable copy in Apps/Gumption/Backups, which the user can open in
  /// OneDrive. Returns its web link.
  @override
  Future<String?> exportBackup(String name, List<int> bytes) async {
    final item = await _upload(
      '$_root:/Backups/${Uri.encodeComponent(name)}:',
      bytes,
    );
    return item['webUrl'] as String?;
  }

  /// Uploads to an item ([item] is `…/items/{id}` or `…:/path:`), replacing
  /// what's there. Returns the item.
  Future<Map<String, Object?>> _upload(String item, List<int> bytes) async {
    if (bytes.length <= simpleUploadLimit) {
      final res = await _client.put(
        Uri.parse('$item/content'),
        headers: {'Content-Type': 'application/json'},
        body: bytes,
      );
      return _json(_check(res));
    }
    final session = _json(
      _check(
        await _client.post(
          Uri.parse('$item/createUploadSession'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'item': {'@microsoft.graph.conflictBehavior': 'replace'},
          }),
        ),
      ),
    );
    final url = Uri.parse(session['uploadUrl'] as String);
    http.Response? last;
    for (var start = 0; start < bytes.length; start += chunk) {
      final end = (start + chunk).clamp(0, bytes.length);
      // The upload URL is pre-signed: no sign-in header.
      last = _check(
        await _download.put(
          url,
          headers: {'Content-Range': 'bytes $start-${end - 1}/${bytes.length}'},
          body: bytes.sublist(start, end),
        ),
      );
    }
    return _json(last!);
  }

  http.Response _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    if (res.statusCode == 401) {
      throw const NeedsReconnect('Microsoft signed this device out.');
    }
    var message = '';
    try {
      final error = (jsonDecode(res.body) as Map)['error'];
      if (error is Map) message = '${error['message'] ?? ''}';
    } on Object {
      // Not JSON: the status code says enough.
    }
    throw OneDriveError(res.statusCode, message);
  }

  static Map<String, Object?> _json(http.Response res) => res.body.isEmpty
      ? const {}
      : jsonDecode(res.body) as Map<String, Object?>;

  static String _id(Map<String, Object?> item) => '${item['id']}';
}
