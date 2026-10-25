import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models/task.dart';
import '../google/google_auth.dart' show NeedsReconnect;
import '../sync/remote_store.dart';

/// Whether this build can sync through iCloud: the iPhone/iPad app (which
/// also runs on Apple-silicon Macs). Not Android, Windows, the web, or the
/// Mac app yet.
bool get iCloudSupportedHere =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Prefix that marks a sync account as iCloud. iCloud doesn't tell apps the
/// Apple ID's email, so the account is stored as `icloud:<id>`, where the id
/// is a hash of the device's iCloud identity: enough to notice a different
/// Apple ID, and shown to the user simply as "iCloud".
const iCloudAccountPrefix = 'icloud:';

/// One workspace's files in a hidden folder of the app's iCloud Drive
/// container (not the Documents folder, so Files doesn't show it). The
/// native side is `ICloudBridge` in ios/Runner/AppDelegate.swift. Each
/// device writes only its own file per workspace, so iCloud never has two
/// versions of one file to reconcile; the sync engine merges the rest.
class ICloudStore implements AccountRemoteStore {
  ICloudStore(this.workspace, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('gumption/icloud');

  final Workspace workspace;
  final MethodChannel _channel;

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      if (e.code == 'unavailable') throw NeedsReconnect(_unavailable);
      rethrow;
    } on MissingPluginException {
      throw const NeedsReconnect(_unavailable);
    }
  }

  static const _unavailable =
      'iCloud isn\'t available. Check that this device is signed in to '
      'iCloud and that iCloud Drive is on for Gumption.';

  @override
  Future<String?> accountEmail() async {
    final id = await _call<String>('identity');
    if (id == null || id.isEmpty) throw const NeedsReconnect(_unavailable);
    return '$iCloudAccountPrefix$id';
  }

  @override
  Future<List<RemoteFile>> list(String prefix) async {
    final rows = await _call<List<Object?>>('list', {
      'workspace': workspace.name,
      'prefix': prefix,
    });
    return [
      for (final r in rows ?? const <Object?>[])
        if (r case {
          'id': final String id,
          'name': final String name,
          'checksum': final String checksum,
        })
          RemoteFile(id, name, checksum),
    ];
  }

  @override
  Future<List<int>> read(String id) async =>
      await _call<Uint8List>('read', {'id': id}) ?? Uint8List(0);

  @override
  Future<String> create(String name, List<int> bytes) async =>
      (await _call<String>('write', {
        'workspace': workspace.name,
        'name': name,
        'bytes': Uint8List.fromList(bytes),
      }))!;

  @override
  Future<void> update(String id, List<int> bytes) =>
      _call<String>('write', {'id': id, 'bytes': Uint8List.fromList(bytes)});

  /// Not offered for iCloud: Settings → Backup saves a file anywhere,
  /// including iCloud Drive, through the share sheet.
  @override
  Future<String?> exportBackup(String name, List<int> bytes) =>
      throw UnsupportedError('Use Settings → Backup → Save a backup file.');
}
