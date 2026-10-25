import 'dart:async';
import 'dart:convert';

import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/data/storage/key_value_store.dart';
import 'package:adhd_tax/features/gamification/progress_controller.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/google/google_auth.dart';
import 'package:adhd_tax/sync/remote_store.dart';
import 'package:adhd_tax/sync/replicas_controller.dart';
import 'package:adhd_tax/sync/sync_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:adhd_tax/features/notes/notes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_remote.dart';

/// One Google account's Drive app folder.
class FakeAccount {
  FakeAccount(this.email);
  final String email;
  final drive = FakeRemote();
  final backups = <String, String>{};
  bool reject = false;
}

class _AccountRemote implements AccountRemoteStore {
  _AccountRemote(this.account);
  final FakeAccount account;

  void _check() {
    if (account.reject) throw const NeedsReconnect('token revoked');
  }

  @override
  Future<String?> accountEmail() async => account.email;
  @override
  Future<String?> exportBackup(String name, List<int> bytes) async {
    account.backups[name] = utf8.decode(bytes);
    return 'https://drive.example/$name';
  }

  @override
  Future<List<RemoteFile>> list(String prefix) async {
    _check();
    return account.drive.list(prefix);
  }

  @override
  Future<List<int>> read(String id) => account.drive.read(id);
  @override
  Future<String> create(String name, List<int> bytes) =>
      account.drive.create(name, bytes);
  @override
  Future<void> update(String id, List<int> bytes) =>
      account.drive.update(id, bytes);
}

/// Hands out a client tagged with the account the "user" picks.
class FakeAuth implements GoogleAuth {
  FakeAuth(this.accounts);
  final Map<Workspace, FakeAccount> accounts;
  final connected = <Workspace>{};

  @override
  bool get isConfigured => true;

  @override
  bool restoreMayRecover = true;

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) async {
    connected.add(ws);
    return _TaggedClient(accounts[ws]!);
  }

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async =>
      connected.contains(ws) ? _TaggedClient(accounts[ws]!) : null;

  @override
  Future<void> disconnect(Workspace ws, {String? email}) async =>
      connected.remove(ws);
}

/// Like a phone just after an app update: the first few silent sign-ins
/// come back empty even though the account is still authorized.
class FlakyRestoreAuth extends FakeAuth {
  FlakyRestoreAuth(super.accounts, {required this.failures});
  int failures;

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async {
    if (failures > 0) {
      failures--;
      return null;
    }
    return super.restore(ws, email: email);
  }
}

/// Like Google Sign-In on iPhone: one signed-in account at a time, handed
/// back to whichever workspace asks.
class OneAccountAuth extends FakeAuth {
  OneAccountAuth(super.accounts);
  FakeAccount? current;

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) async {
    current = accounts[ws];
    return super.connect(ws, email: email);
  }

  @override
  Future<http.Client?> restore(Workspace ws, {String? email}) async =>
      connected.contains(ws) && current != null
      ? _TaggedClient(current!)
      : null;
}

/// A sign-in page the user never finishes.
class StuckAuth extends FakeAuth {
  StuckAuth(super.accounts);
  final pending = Completer<http.Client>();

  @override
  Future<http.Client> connect(Workspace ws, {String? email}) => pending.future;
}

class _TaggedClient extends http.BaseClient {
  _TaggedClient(this.account);
  final FakeAccount account;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();
}

ProviderContainer device(FakeAuth auth, {KeyValueStore? store}) {
  final c = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store ?? MemoryStore()),
      googleAuthProvider.overrideWithValue(auth),
      remoteFactoryProvider.overrideWithValue(
        (client) => _AccountRemote((client as _TaggedClient).account),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  late FakeAccount personal;
  late FakeAccount work;

  setUp(() {
    personal = FakeAccount('kyle@gmail.com');
    work = FakeAccount('kyle@clinic.org');
  });

  Map<Workspace, FakeAccount> accounts() => {
    Workspace.personal: personal,
    Workspace.work: work,
  };

  Future<void> connectBoth(ProviderContainer c) async {
    for (final ws in Workspace.values) {
      await c.read(syncProvider(ws).notifier).connect();
    }
  }

  Future<void> syncAll(ProviderContainer c) async {
    for (final ws in Workspace.values) {
      await c.read(syncProvider(ws).notifier).syncNow();
    }
  }

  test('starts disconnected; connect syncs and records the account', () async {
    final phone = device(FakeAuth(accounts()));
    expect(
      phone.read(syncProvider(Workspace.personal)).phase,
      SyncPhase.disconnected,
    );
    await phone.read(syncProvider(Workspace.personal).notifier).connect();
    final s = phone.read(syncProvider(Workspace.personal));
    expect(s.phase, SyncPhase.synced);
    expect(s.email, 'kyle@gmail.com');
    expect(s.lastSyncedAt, isNotNull);
  });

  test(
    'tasks and XP reach the other device, each in its own account',
    () async {
      final phone = device(FakeAuth(accounts()));
      final pc = device(FakeAuth(accounts()));
      await connectBoth(phone);
      await connectBoth(pc);

      final tasks = phone.read(tasksProvider.notifier);
      final laundry = tasks.create(title: 'Laundry');
      tasks.create(title: 'Template for Dr. Lee', workspace: Workspace.work);
      phone.read(progressProvider.notifier).recordStart(laundry);
      tasks.complete(laundry.id, minutesWorked: 20);
      phone
          .read(progressProvider.notifier)
          .recordCompletion(laundry, actualMin: 20);
      await syncAll(phone);
      await syncAll(pc);

      final pcTasks = pc.read(tasksProvider);
      expect(pcTasks.map((t) => t.title).toSet(), {
        'Laundry',
        'Template for Dr. Lee',
      });
      expect(
        pcTasks.firstWhere((t) => t.title == 'Laundry').status,
        TaskStatus.done,
      );
      expect(pc.read(progressProvider).xp, phone.read(progressProvider).xp);
      expect(pc.read(progressProvider).completed, 1);

      // Work data never touches the personal account, and vice versa.
      final personalFiles = personal.drive.files.values
          .map((f) => utf8.decode(f.$2))
          .join();
      final workFiles = work.drive.files.values
          .map((f) => utf8.decode(f.$2))
          .join();
      expect(personalFiles, isNot(contains('Dr. Lee')));
      expect(workFiles, isNot(contains('Laundry')));
    },
  );

  test('notes and projects sync too, and moving a note to Work scrubs it '
      'from the Personal account', () async {
    final phone = device(FakeAuth(accounts()));
    final pc = device(FakeAuth(accounts()));
    await connectBoth(phone);
    await connectBoth(pc);

    final project = phone
        .read(projectsProvider.notifier)
        .create('Move house', Workspace.personal);
    final notes = phone.read(notesProvider.notifier);
    notes.create(
      title: 'Movers',
      body: 'Quote from two companies #moving',
      projectId: project.id,
    );
    final rota = notes.create(title: 'Rota swap ideas');
    await syncAll(phone);
    await syncAll(pc);

    expect(pc.read(projectsProvider).single.name, 'Move house');
    final movers = pc
        .read(notesProvider)
        .firstWhere((n) => n.title == 'Movers');
    expect(movers.projectId, project.id);
    expect(movers.allTags, ['moving']);

    // Edit on the PC, move the other note to Work on the phone.
    pc.read(notesProvider.notifier).save(movers.copyWith(pinned: true));
    notes.save(rota.copyWith(workspace: Workspace.work));
    await syncAll(pc);
    await syncAll(phone);
    await syncAll(pc);

    expect(
      phone.read(notesProvider).firstWhere((n) => n.title == 'Movers').pinned,
      isTrue,
    );
    expect(
      pc
          .read(notesProvider)
          .firstWhere((n) => n.title == 'Rota swap ideas')
          .workspace,
      Workspace.work,
    );
    final personalFiles = personal.drive.files.values
        .map((f) => utf8.decode(f.$2))
        .join();
    expect(personalFiles, isNot(contains('Rota swap')));
  });

  test('moving a task to Work scrubs it from the Personal account', () async {
    final pc = device(FakeAuth(accounts()));
    await connectBoth(pc);
    final tasks = pc.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Call pt about refill');
    await syncAll(pc);
    tasks.save(t.copyWith(workspace: Workspace.work));
    await syncAll(pc);

    final personalFile = personal.drive.files.values.single;
    expect(utf8.decode(personalFile.$2), isNot(contains('refill')));
    expect(pc.read(tasksProvider).single.workspace, Workspace.work);
  });

  test('a moved-back task comes back (tombstone revived)', () async {
    final pc = device(FakeAuth(accounts()));
    final tasks = pc.read(tasksProvider.notifier);
    final t = tasks.create(title: 'Back and forth');
    tasks.save(t.copyWith(workspace: Workspace.work));
    tasks.save(t.copyWith(workspace: Workspace.personal));
    final all = pc.read(tasksProvider);
    expect(all.length, 1);
    expect(all.single.workspace, Workspace.personal);
  });

  test('deletes sync too', () async {
    final phone = device(FakeAuth(accounts()));
    final pc = device(FakeAuth(accounts()));
    await connectBoth(phone);
    await connectBoth(pc);
    final t = phone.read(tasksProvider.notifier).create(title: 'Gone soon');
    await syncAll(phone);
    await syncAll(pc);
    expect(pc.read(tasksProvider), hasLength(1));
    pc.read(tasksProvider.notifier).delete(t.id);
    await syncAll(pc);
    await syncAll(phone);
    expect(phone.read(tasksProvider), isEmpty);
  });

  test('progress reset applies on every device', () async {
    final phone = device(FakeAuth(accounts()));
    final pc = device(FakeAuth(accounts()));
    await connectBoth(phone);
    await connectBoth(pc);
    final t = phone.read(tasksProvider.notifier).create(title: 'x');
    phone.read(progressProvider.notifier).recordStart(t);
    await syncAll(phone);
    await syncAll(pc);
    expect(pc.read(progressProvider).xp, greaterThan(0));

    await Future<void>.delayed(const Duration(milliseconds: 5));
    pc.read(progressProvider.notifier).reset();
    await syncAll(pc);
    await syncAll(phone);
    expect(phone.read(progressProvider).xp, 0);
  });

  test('a revoked token asks to reconnect, and reconnect recovers', () async {
    final pc = device(FakeAuth(accounts()));
    await pc.read(syncProvider(Workspace.personal).notifier).connect();
    personal.reject = true;
    await pc.read(syncProvider(Workspace.personal).notifier).syncNow();
    expect(
      pc.read(syncProvider(Workspace.personal)).phase,
      SyncPhase.needsReconnect,
    );

    personal.reject = false;
    await pc.read(syncProvider(Workspace.personal).notifier).connect();
    expect(pc.read(syncProvider(Workspace.personal)).phase, SyncPhase.synced);
  });

  test('restart restores the session silently', () async {
    final auth = FakeAuth(accounts());
    final store = MemoryStore();
    final first = device(auth, store: store);
    await first.read(syncProvider(Workspace.personal).notifier).connect();
    first.read(tasksProvider.notifier).create(title: 'Persisted');
    first.dispose();

    final again = device(auth, store: store);
    expect(again.read(tasksProvider).single.title, 'Persisted');
    expect(
      again.read(syncProvider(Workspace.personal)).email,
      'kyle@gmail.com',
    );
    await again.read(syncProvider(Workspace.personal).notifier).syncNow();
    expect(
      again.read(syncProvider(Workspace.personal)).phase,
      SyncPhase.synced,
    );
  });

  test('after an update, a silent sign-in that fails at first is retried '
      'quietly instead of asking to reconnect', () async {
    final store = MemoryStore();
    final first = device(FakeAuth(accounts()), store: store);
    await first.read(syncProvider(Workspace.personal).notifier).connect();
    first.dispose();

    final auth = FlakyRestoreAuth(accounts(), failures: 2)
      ..connected.add(Workspace.personal);
    final updated = device(auth, store: store);
    final ctl = updated.read(syncProvider(Workspace.personal).notifier);
    await ctl.syncNow();
    var s = updated.read(syncProvider(Workspace.personal));
    expect(s.phase, SyncPhase.syncing);
    expect(s.message, contains('Reconnecting'));
    await ctl.syncNow();
    expect(
      updated.read(syncProvider(Workspace.personal)).phase,
      isNot(SyncPhase.needsReconnect),
    );
    await ctl.syncNow();
    s = updated.read(syncProvider(Workspace.personal));
    expect(s.phase, SyncPhase.synced);
    expect(s.email, 'kyle@gmail.com');
  });

  test(
    'a sign-in that stays gone asks to reconnect after the retries',
    () async {
      final store = MemoryStore();
      final first = device(FakeAuth(accounts()), store: store);
      await first.read(syncProvider(Workspace.personal).notifier).connect();
      first.dispose();

      final again = device(FakeAuth(accounts()), store: store);
      final ctl = again.read(syncProvider(Workspace.personal).notifier);
      for (var i = 0; i <= SyncController.restoreRetries.length; i++) {
        await ctl.syncNow();
      }
      expect(
        again.read(syncProvider(Workspace.personal)).phase,
        SyncPhase.needsReconnect,
      );
    },
  );

  test('Work on a personal Gmail account is flagged', () async {
    final mixedUp = {Workspace.personal: personal, Workspace.work: personal};
    final pc = device(FakeAuth(mixedUp));
    await pc.read(syncProvider(Workspace.work).notifier).connect();
    expect(
      pc.read(syncProvider(Workspace.work)).looksLikePersonalAccount,
      isTrue,
    );
  });

  test('backup export writes readable JSON', () async {
    final pc = device(FakeAuth(accounts()));
    await pc.read(syncProvider(Workspace.personal).notifier).connect();
    pc.read(tasksProvider.notifier).create(title: 'Back me up');
    final link = await pc
        .read(syncProvider(Workspace.personal).notifier)
        .exportBackup();
    expect(link, startsWith('https://'));
    final doc = jsonDecode(personal.backups.values.single) as Map;
    expect((doc['tasks'] as List).single['title'], 'Back me up');
  });

  test('disconnect stops syncing but keeps local tasks', () async {
    final pc = device(FakeAuth(accounts()));
    await pc.read(syncProvider(Workspace.personal).notifier).connect();
    pc.read(tasksProvider.notifier).create(title: 'Stay');
    await pc.read(syncProvider(Workspace.personal).notifier).disconnect();
    expect(
      pc.read(syncProvider(Workspace.personal)).phase,
      SyncPhase.disconnected,
    );
    expect(pc.read(tasksProvider), hasLength(1));
  });

  test('a sign-in shared between workspaces never syncs into the wrong '
      'account', () async {
    final auth = OneAccountAuth(accounts());
    final store = MemoryStore();
    final phone = device(auth, store: store);
    await phone.read(syncProvider(Workspace.personal).notifier).connect();
    phone.read(tasksProvider.notifier).create(title: 'Laundry');
    await phone.read(syncProvider(Workspace.work).notifier).connect();

    // Signing in to Work replaced the shared sign-in. A fresh start of the
    // app (no client held yet) must not let Personal sync through it.
    final fresh = device(auth, store: MemoryStore({...store.data}));
    await fresh.read(syncProvider(Workspace.personal).notifier).syncNow();
    final s = fresh.read(syncProvider(Workspace.personal));
    expect(s.phase, SyncPhase.needsReconnect);
    expect(s.message, contains('kyle@clinic.org'));
    expect(
      work.drive.files.values
          .map((f) => f.$1)
          .where((name) => name.startsWith('state.personal.')),
      isEmpty,
    );
  });

  test('with no saved sign-in to wait for, Reconnect shows at once', () async {
    final store = MemoryStore();
    final first = device(FakeAuth(accounts()), store: store);
    await first.read(syncProvider(Workspace.personal).notifier).connect();
    // The saved sign-in is gone (an iPhone after the switch to browser
    // sign-in): nothing comes back, and retrying won't change that.
    final after = FakeAuth(accounts())..restoreMayRecover = false;
    final phone = device(after, store: MemoryStore({...store.data}));
    await phone.read(syncProvider(Workspace.personal).notifier).syncNow();
    expect(
      phone.read(syncProvider(Workspace.personal)).phase,
      SyncPhase.needsReconnect,
    );
  });

  test(
    'a sign-in left open can be cancelled; a late answer is ignored',
    () async {
      final auth = StuckAuth(accounts());
      final phone = device(auth);
      final ctl = phone.read(syncProvider(Workspace.work).notifier);
      final connecting = ctl.connect();
      expect(
        phone.read(syncProvider(Workspace.work)).phase,
        SyncPhase.connecting,
      );
      ctl.cancelConnect();
      expect(
        phone.read(syncProvider(Workspace.work)).phase,
        SyncPhase.disconnected,
      );
      auth.pending.complete(_TaggedClient(work));
      await connecting;
      expect(
        phone.read(syncProvider(Workspace.work)).phase,
        SyncPhase.disconnected,
      );
      expect(work.drive.files, isEmpty);
    },
  );

  test('Phase 1 data migrates into the replicas once', () async {
    final now = DateTime.now();
    final legacyTask = Task(
      id: 'legacy',
      title: 'Old task',
      createdAt: now,
      updatedAt: now,
    );
    final store = MemoryStore({
      'tasks.v1': jsonEncode([legacyTask.toJson()]),
      'progress.v1': jsonEncode({'xp': 640, 'coins': 61, 'completed': 19}),
    });
    final pc = device(FakeAuth(accounts()), store: store);
    expect(pc.read(tasksProvider).single.title, 'Old task');
    expect(pc.read(progressProvider).xp, 640);
    expect(store.read('tasks.v1'), isNull);
    expect(
      pc.read(replicasProvider)[Workspace.personal].lastLocalWrite,
      isNotNull,
    );
  });
}
