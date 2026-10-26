import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/drive/v3.dart' show DetailedApiRequestError;
import 'package:http/http.dart' as http;

import '../core/providers.dart';
import '../data/models/task.dart';
import '../google/auth_factory.dart';
import '../google/drive_remote_store.dart';
import '../google/google_auth.dart';
import '../icloud/icloud_store.dart';
import '../microsoft/auth_factory.dart';
import '../microsoft/onedrive_store.dart';
import 'remote_store.dart';
import 'replicas_controller.dart';
import 'sync_engine.dart';

enum SyncPhase {
  /// No sync service is available in this build (no client ids, not an
  /// iPhone), or the one this workspace used isn't.
  notConfigured,
  disconnected,
  connecting,
  syncing,
  synced,

  /// Couldn't sync this round (often just offline); retried automatically.
  error,

  /// The sign-in can't be used without the user. "Reconnect" fixes it.
  needsReconnect,
}

class WorkspaceSync {
  const WorkspaceSync(
    this.phase, {
    this.email,
    this.lastSyncedAt,
    this.message,
  });

  final SyncPhase phase;
  final String? email;
  final DateTime? lastSyncedAt;
  final String? message;

  bool get isConnected => email != null && phase != SyncPhase.disconnected;

  /// Synced through iCloud rather than Google.
  bool get isICloud => email?.startsWith(iCloudAccountPrefix) ?? false;

  /// What to show for the account: the Google email, or "iCloud".
  String? get accountLabel => isICloud ? 'iCloud' : email;

  /// A Work workspace on a consumer Gmail or Outlook.com account is
  /// probably a mistake.
  bool get looksLikePersonalAccount {
    final e = email?.toLowerCase() ?? '';
    return const [
      '@gmail.com',
      '@googlemail.com',
      '@outlook.com',
      '@hotmail.com',
      '@live.com',
      '@msn.com',
    ].any(e.endsWith);
  }
}

final googleAuthProvider = Provider<GoogleAuth>((ref) => createGoogleAuth());

final remoteFactoryProvider =
    Provider<AccountRemoteStore Function(http.Client)>(
      (ref) => DriveRemoteStore.new,
    );

final microsoftAuthProvider = Provider<AccountAuth>(
  (ref) => createMicrosoftAuth(),
);

final oneDriveFactoryProvider =
    Provider<AccountRemoteStore Function(http.Client)>(
      (ref) => OneDriveStore.new,
    );

/// Where a workspace syncs. Google works everywhere; iCloud only in the
/// iPhone/iPad app; OneDrive everywhere but the web.
enum SyncService {
  google('Google'),
  icloud('iCloud'),
  onedrive('Microsoft');

  const SyncService(this.signInName);

  /// Whose sign-in this is ("Waiting for Microsoft sign-in…").
  final String signInName;

  /// Where the files live, for messages ("the copy in OneDrive").
  String get storeName => switch (this) {
    google => 'Google Drive',
    icloud => 'iCloud',
    onedrive => 'OneDrive',
  };
}

/// The services this build can offer, in the order the chooser lists them.
final availableSyncServicesProvider = Provider<List<SyncService>>(
  (ref) => [
    if (ref.watch(iCloudSupportedProvider)) SyncService.icloud,
    if (ref.watch(googleAuthProvider).isConfigured) SyncService.google,
    if (ref.watch(microsoftAuthProvider).isConfigured) SyncService.onedrive,
  ],
);

/// Whether this device can offer iCloud (tests override it).
final iCloudSupportedProvider = Provider<bool>((ref) => iCloudSupportedHere);

final iCloudStoreProvider = Provider<AccountRemoteStore Function(Workspace)>(
  (ref) => ICloudStore.new,
);

final syncProvider =
    NotifierProvider.family<SyncController, WorkspaceSync, Workspace>(
      SyncController.new,
    );

/// Keeps one workspace's replica in sync with its account (Google,
/// iCloud or OneDrive): on start, a few seconds after local edits, every few minutes, on resume,
/// and on demand.
class SyncController extends Notifier<WorkspaceSync> {
  SyncController(this.workspace);

  final Workspace workspace;

  static const periodic = Duration(minutes: 3);
  static const afterEdit = Duration(seconds: 4);

  /// Waits between silent sign-in retries before asking the user to
  /// reconnect. Right after an Android update (a cold start), Google's
  /// first silent token request can come back empty or fail even though
  /// the grant is still there; a few seconds later it works.
  static const restoreRetries = [
    Duration(seconds: 5),
    Duration(seconds: 20),
    Duration(minutes: 1),
  ];

  late SyncState _sync;
  http.Client? _client;
  AccountRemoteStore? _remote;
  Timer? _periodic;
  Timer? _debounce;
  Timer? _retry;
  int _restoreFailures = 0;
  bool _running = false;
  bool _again = false;

  /// Bumped by [connect] and [disconnect]. A sync round that started under
  /// an older number finds out after its next network call and stops,
  /// so a reply arriving after Disconnect can't mark it Synced again.
  int _generation = 0;

  /// A round merged other devices' changes but couldn't upload them:
  /// upload on the next one even if nothing else changed.
  bool _uploadOwed = false;

  /// The sign-in for this workspace's service (not used for iCloud).
  AccountAuth get _auth => service == SyncService.onedrive
      ? ref.read(microsoftAuthProvider)
      : ref.read(googleAuthProvider);
  String get _key => 'sync.v1.${workspace.name}';
  String get _serviceKey => 'sync.service.v1.${workspace.name}';

  /// The service this workspace syncs through on this device. Nothing
  /// saved (before 1.2) means Google.
  SyncService get service => SyncService.values.firstWhere(
    (s) => s.name == ref.read(keyValueStoreProvider).read(_serviceKey),
    orElse: () => SyncService.google,
  );

  bool get _iCloud => service == SyncService.icloud;

  bool get _configured =>
      _iCloud ? ref.read(iCloudSupportedProvider) : _auth.isConfigured;

  AccountRemoteStore _remoteFor(http.Client client) =>
      service == SyncService.onedrive
      ? ref.read(oneDriveFactoryProvider)(client)
      : ref.read(remoteFactoryProvider)(client);
  DateTime _now() => ref.read(clockProvider)();

  @override
  WorkspaceSync build() {
    final raw = ref.read(keyValueStoreProvider).read(_key);
    _sync = raw == null
        ? const SyncState()
        : SyncState.fromJson(jsonDecode(raw) as Map<String, Object?>);
    ref.onDispose(() {
      _periodic?.cancel();
      _debounce?.cancel();
      _retry?.cancel();
      _client?.close();
    });

    // Not connected: usable if any service is. Connected: only if its own.
    final usable = _sync.email == null
        ? ref.read(availableSyncServicesProvider).isNotEmpty
        : _configured;
    if (!usable) {
      return WorkspaceSync(SyncPhase.notConfigured, email: _sync.email);
    }
    ref.listen(
      replicasProvider.select((s) => s.localWrites[workspace] ?? 0),
      (_, _) => _soon(),
    );
    if (_sync.email == null) return const WorkspaceSync(SyncPhase.disconnected);

    _startTimer();
    scheduleMicrotask(syncNow);
    return WorkspaceSync(
      SyncPhase.synced,
      email: _sync.email,
      lastSyncedAt: _sync.lastSyncedAt,
    );
  }

  /// Bumped by [cancelConnect], so a sign-in that finishes after the user
  /// gave up is ignored.
  int _attempt = 0;

  /// How long a sign-in may take before the spinner gives up.
  static const connectTimeout = Duration(minutes: 5);

  /// Interactive sign-in, then a first sync. Also used for "Reconnect".
  /// [via] picks the service (and remembers it); left out, it's the one
  /// this workspace already uses.
  Future<void> connect({SyncService? via}) async {
    // A different service is a different place, even for the same email.
    final switched = via != null && via != service;
    if (switched) ref.read(keyValueStoreProvider).write(_serviceKey, via.name);
    final attempt = ++_attempt;
    _generation++;
    state = WorkspaceSync(SyncPhase.connecting, email: _sync.email);
    try {
      final http.Client? client;
      final AccountRemoteStore remote;
      if (_iCloud) {
        // Nothing to sign in to: the device's own iCloud account is used.
        client = null;
        remote = ref.read(iCloudStoreProvider)(workspace);
      } else {
        client = await _auth
            .connect(workspace, email: _sync.email)
            .timeout(connectTimeout);
        if (!ref.mounted) return;
        if (attempt != _attempt) {
          client.close();
          return;
        }
        remote = _remoteFor(client);
      }
      final email = await remote.accountEmail();
      if (!ref.mounted || attempt != _attempt) return;
      _client?.close();
      _client = client;
      _remote = remote;
      // A different account is a different Drive: start its sync state
      // fresh so everything local gets uploaded there.
      if (email != _sync.email || switched) _sync = SyncState(email: email);
      _restoreFailures = 0;
      _retry?.cancel();
      _save();
      _startTimer();
      await syncNow();
    } on Object catch (e) {
      if (!ref.mounted || attempt != _attempt) return;
      state = WorkspaceSync(
        _sync.email == null ? SyncPhase.disconnected : SyncPhase.needsReconnect,
        email: _sync.email,
        lastSyncedAt: _sync.lastSyncedAt,
        message: e is TimeoutException
            ? 'Sign-in didn\'t finish. Try again.'
            : e is NeedsReconnect
            ? e.reason
            : 'Couldn\'t connect: ${_describe(e)}',
      );
    }
  }

  /// Gives up on a sign-in that's still open (the user closed the Google
  /// page, or it's stuck), so the row isn't left spinning.
  void cancelConnect() {
    if (state.phase != SyncPhase.connecting) return;
    _attempt++;
    state = WorkspaceSync(
      _sync.email == null ? SyncPhase.disconnected : SyncPhase.needsReconnect,
      email: _sync.email,
      lastSyncedAt: _sync.lastSyncedAt,
    );
  }

  /// Stops syncing this workspace. Local data stays on this device, and the
  /// copy in Drive stays there for other devices.
  Future<void> disconnect() async {
    _generation++;
    _attempt++;
    _uploadOwed = false;
    _periodic?.cancel();
    _debounce?.cancel();
    _retry?.cancel();
    _restoreFailures = 0;
    final email = _sync.email;
    _client?.close();
    _client = null;
    _remote = null;
    _sync = const SyncState();
    // iCloud has no sign-in of ours to revoke. Read before the service
    // is forgotten.
    final auth = _iCloud ? null : _auth;
    ref.read(keyValueStoreProvider)
      ..remove(_key)
      ..remove(_serviceKey);
    state = const WorkspaceSync(SyncPhase.disconnected);
    if (auth == null) return;
    try {
      await auth.disconnect(workspace, email: email);
    } on Object {
      // Revoking is best effort; local credentials are already gone.
    }
  }

  Future<void> syncNow() async {
    if (!_configured || _sync.email == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    final generation = _generation;
    bool current() => ref.mounted && generation == _generation;
    try {
      do {
        _again = false;
        state = WorkspaceSync(
          SyncPhase.syncing,
          email: _sync.email,
          lastSyncedAt: _sync.lastSyncedAt,
        );
        final AccountRemoteStore? remote;
        try {
          remote = await _ensureRemote();
        } on Object catch (e) {
          // iCloud being off isn't a hiccup to wait out: say so at once.
          final retry = e is! WrongAccount && !(_iCloud && e is NeedsReconnect);
          if (!current()) return;
          if (retry && _retryRestore()) return;
          rethrow;
        }
        if (!current()) return;
        if (remote == null) {
          if (!_iCloud && _auth.restoreMayRecover && _retryRestore()) return;
          state = WorkspaceSync(
            SyncPhase.needsReconnect,
            email: _sync.email,
            lastSyncedAt: _sync.lastSyncedAt,
            message: 'Sign in again to keep syncing.',
          );
          return;
        }
        _restoreFailures = 0;
        var saved = true;
        final out = await syncOnce(
          replica: ref.read(replicasProvider)[workspace],
          remote: remote,
          workspace: workspace.name,
          state: _sync,
          now: _now,
          forceUpload: _uploadOwed,
          current: current,
          // Saved and shown before the upload, which may still fail.
          onMerged: () async {
            _uploadOwed = true;
            saved = await ref
                .read(replicasProvider.notifier)
                .remoteMerged(workspace);
          },
        );
        if (!current()) return;
        _uploadOwed = false;
        _sync = out.state;
        // Not on disk: keep the stored record of which files were read as
        // it was, so after a restart they're downloaded again.
        if (saved) _save();
        state = WorkspaceSync(
          SyncPhase.synced,
          email: _sync.email,
          lastSyncedAt: _sync.lastSyncedAt,
          message: out.skipped.isEmpty
              ? null
              : '${out.skipped.length} file(s) from another device couldn\'t be read.',
        );
      } while (_again);
    } on SyncCancelled {
      // Disconnected or switched account mid-round: nothing to report.
    } on NeedsReconnect catch (e) {
      if (current()) _dropClient();
      if (current()) {
        state = WorkspaceSync(
          SyncPhase.needsReconnect,
          email: _sync.email,
          lastSyncedAt: _sync.lastSyncedAt,
          message: e.reason,
        );
      }
    } on DetailedApiRequestError catch (e) {
      if (e.status == 401 && current()) _dropClient();
      if (current()) {
        state = WorkspaceSync(
          e.status == 401 ? SyncPhase.needsReconnect : SyncPhase.error,
          email: _sync.email,
          lastSyncedAt: _sync.lastSyncedAt,
          message: e.status == 401
              ? 'Google signed this device out.'
              : 'Google Drive error ${e.status}: ${e.message ?? ''}',
        );
      }
    } on Object catch (e) {
      if (current()) {
        state = WorkspaceSync(
          SyncPhase.error,
          email: _sync.email,
          lastSyncedAt: _sync.lastSyncedAt,
          message: _describe(e),
        );
      }
    } finally {
      _running = false;
      // A stale round ended: run what was asked for meanwhile (a reconnect
      // calls syncNow while the old round is still waiting on the network).
      if (!current() && ref.mounted && _again) {
        _again = false;
        scheduleMicrotask(syncNow);
      }
    }
  }

  /// Saves a readable JSON copy of this workspace to the user's Drive or
  /// OneDrive. Returns a link to the file when there is one.
  Future<String?> exportBackup() async {
    final remote = await _ensureRemote();
    if (remote == null) throw const NeedsReconnect();
    final replica = ref.read(replicasProvider)[workspace];
    final now = _now();
    final doc = {
      'app': 'Gumption',
      'workspace': workspace.name,
      'exportedAt': now.toIso8601String(),
      'tasks': [
        for (final e in replica.collection(collTasks).entries)
          if (taskFromRecord(e.key, e.value) case final t?) t.toJson(),
      ],
      'xpEvents': [
        for (final e in replica.collection(collEvents).entries)
          if (!e.value.isDeleted) {'id': e.key, ...e.value.values},
      ],
    };
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return remote.exportBackup(
      'Gumption backup - ${workspace.label} - $date.json',
      utf8.encode(const JsonEncoder.withIndent('  ').convert(doc)),
    );
  }

  Future<AccountRemoteStore?> _ensureRemote() async {
    if (_iCloud) {
      // Checked every round, not once: the device's Apple ID can change
      // (Settings → sign out) while Gumption keeps running.
      final remote = _remote ?? ref.read(iCloudStoreProvider)(workspace);
      final generation = _generation;
      // Signed in to a different Apple ID now: its iCloud is a different
      // place, so ask before syncing everything into it.
      final who = await remote.accountEmail();
      if (!ref.mounted || generation != _generation) {
        throw const SyncCancelled();
      }
      if (who != _sync.email) {
        throw const WrongAccount(
          'This device is signed in to a different iCloud account. '
          'Reconnect to sync with it.',
        );
      }
      return _remote = remote;
    }
    if (_remote != null) return _remote;
    final generation = _generation;
    final client = await _auth.restore(workspace, email: _sync.email);
    if (client == null) return null;
    if (!ref.mounted || generation != _generation) {
      // Disconnected meanwhile: don't bring this sign-in back.
      client.close();
      throw const SyncCancelled();
    }
    final remote = _remoteFor(client);
    // Check whose Drive this is before writing anything: a sign-in shared
    // between workspaces (iPhone's Google Sign-In did this) could otherwise put
    // Work tasks in the Personal account, or the other way round.
    final who = await remote.accountEmail();
    if (!ref.mounted || generation != _generation) {
      client.close();
      throw const SyncCancelled();
    }
    final want = _sync.email;
    if (who != null &&
        want != null &&
        who.toLowerCase() != want.toLowerCase()) {
      client.close();
      throw WrongAccount(
        'Signed in to ${service.signInName} as $who. Reconnect with $want.',
      );
    }
    _client = client;
    return _remote = remote;
  }

  /// The silent sign-in didn't work: try again shortly, quietly, before
  /// telling the user to reconnect. False once the retries are used up.
  bool _retryRestore() {
    if (_restoreFailures >= restoreRetries.length) return false;
    final wait = restoreRetries[_restoreFailures++];
    _retry?.cancel();
    _retry = Timer(wait, syncNow);
    state = WorkspaceSync(
      SyncPhase.syncing,
      email: _sync.email,
      lastSyncedAt: _sync.lastSyncedAt,
      message: 'Reconnecting…',
    );
    return true;
  }

  void _dropClient() {
    _client?.close();
    _client = null;
    _remote = null;
  }

  void _soon() {
    if (_sync.email == null) return;
    _debounce?.cancel();
    _debounce = Timer(afterEdit, syncNow);
  }

  void _startTimer() {
    _periodic?.cancel();
    _periodic = Timer.periodic(periodic, (_) => syncNow());
  }

  void _save() =>
      ref.read(keyValueStoreProvider).write(_key, jsonEncode(_sync.toJson()));
}

String _describe(Object e) {
  final s = e.toString();
  if (s.contains('SocketException') ||
      s.contains('ClientException') ||
      s.contains('Failed host lookup') ||
      s.contains('XMLHttpRequest')) {
    return 'Offline. Will retry automatically.';
  }
  return s.length > 160 ? '${s.substring(0, 160)}…' : s;
}
