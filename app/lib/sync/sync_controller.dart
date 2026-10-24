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
import 'remote_store.dart';
import 'replicas_controller.dart';
import 'sync_engine.dart';

enum SyncPhase {
  /// This build has no Google client id for the platform.
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

  /// A Work workspace on a consumer Gmail account is probably a mistake.
  bool get looksLikePersonalAccount {
    final e = email?.toLowerCase() ?? '';
    return e.endsWith('@gmail.com') || e.endsWith('@googlemail.com');
  }
}

final googleAuthProvider = Provider<GoogleAuth>((ref) => createGoogleAuth());

final remoteFactoryProvider =
    Provider<AccountRemoteStore Function(http.Client)>(
      (ref) => DriveRemoteStore.new,
    );

final syncProvider =
    NotifierProvider.family<SyncController, WorkspaceSync, Workspace>(
      SyncController.new,
    );

/// Keeps one workspace's replica in sync with its Google account: on
/// start, a few seconds after local edits, every few minutes, on resume,
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

  GoogleAuth get _auth => ref.read(googleAuthProvider);
  String get _key => 'sync.v1.${workspace.name}';
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

    if (!_auth.isConfigured) {
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
  Future<void> connect() async {
    final attempt = ++_attempt;
    state = WorkspaceSync(SyncPhase.connecting, email: _sync.email);
    try {
      final client = await _auth
          .connect(workspace, email: _sync.email)
          .timeout(connectTimeout);
      if (!ref.mounted) return;
      if (attempt != _attempt) {
        client.close();
        return;
      }
      final remote = ref.read(remoteFactoryProvider)(client);
      final email = await remote.accountEmail();
      if (!ref.mounted) return;
      _client?.close();
      _client = client;
      _remote = remote;
      // A different account is a different Drive: start its sync state
      // fresh so everything local gets uploaded there.
      if (email != _sync.email) _sync = SyncState(email: email);
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
    _periodic?.cancel();
    _debounce?.cancel();
    _retry?.cancel();
    _restoreFailures = 0;
    final email = _sync.email;
    _client?.close();
    _client = null;
    _remote = null;
    _sync = const SyncState();
    ref.read(keyValueStoreProvider).remove(_key);
    state = const WorkspaceSync(SyncPhase.disconnected);
    try {
      await _auth.disconnect(workspace, email: email);
    } on Object {
      // Revoking is best effort; local credentials are already gone.
    }
  }

  Future<void> syncNow() async {
    if (!_auth.isConfigured || _sync.email == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
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
          if (e is! WrongAccount && ref.mounted && _retryRestore()) return;
          rethrow;
        }
        if (!ref.mounted) return;
        if (remote == null) {
          if (_retryRestore()) return;
          state = WorkspaceSync(
            SyncPhase.needsReconnect,
            email: _sync.email,
            lastSyncedAt: _sync.lastSyncedAt,
            message: 'Sign in again to keep syncing.',
          );
          return;
        }
        _restoreFailures = 0;
        final out = await syncOnce(
          replica: ref.read(replicasProvider)[workspace],
          remote: remote,
          workspace: workspace.name,
          state: _sync,
          now: _now,
        );
        if (!ref.mounted) return;
        _sync = out.state;
        _save();
        if (out.merged) {
          ref.read(replicasProvider.notifier).remoteMerged(workspace);
        }
        state = WorkspaceSync(
          SyncPhase.synced,
          email: _sync.email,
          lastSyncedAt: _sync.lastSyncedAt,
          message: out.skipped.isEmpty
              ? null
              : '${out.skipped.length} file(s) from another device couldn\'t be read.',
        );
      } while (_again);
    } on NeedsReconnect catch (e) {
      _dropClient();
      if (ref.mounted) {
        state = WorkspaceSync(
          SyncPhase.needsReconnect,
          email: _sync.email,
          lastSyncedAt: _sync.lastSyncedAt,
          message: e.reason,
        );
      }
    } on DetailedApiRequestError catch (e) {
      if (e.status == 401) _dropClient();
      if (ref.mounted) {
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
      if (ref.mounted) {
        state = WorkspaceSync(
          SyncPhase.error,
          email: _sync.email,
          lastSyncedAt: _sync.lastSyncedAt,
          message: _describe(e),
        );
      }
    } finally {
      _running = false;
    }
  }

  /// Saves a readable JSON copy of this workspace to the user's Drive.
  /// Returns a link to the file when Drive provides one.
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
    if (_remote != null) return _remote;
    final client = await _auth.restore(workspace, email: _sync.email);
    if (client == null) return null;
    final remote = ref.read(remoteFactoryProvider)(client);
    // Check whose Drive this is before writing anything: a sign-in shared
    // between workspaces (iPhone's Google Sign-In did this) could otherwise put
    // Work tasks in the Personal account, or the other way round.
    final who = await remote.accountEmail();
    final want = _sync.email;
    if (who != null &&
        want != null &&
        who.toLowerCase() != want.toLowerCase()) {
      client.close();
      throw WrongAccount('Signed in to Google as $who. Reconnect with $want.');
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
      message: 'Reconnecting to Google…',
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
