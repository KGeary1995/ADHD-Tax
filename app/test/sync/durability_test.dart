// Saving and syncing when things go wrong partway: a failed upload, a
// failed disk write, a Disconnect while a round is on the network.

import 'dart:async';
import 'dart:convert';

import 'package:adhd_tax/core/providers.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/data/storage/key_value_store.dart';
import 'package:adhd_tax/features/tasks/tasks_controller.dart';
import 'package:adhd_tax/sync/remote_store.dart';
import 'package:adhd_tax/sync/replica.dart';
import 'package:adhd_tax/sync/replicas_controller.dart';
import 'package:adhd_tax/sync/sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widget/app_flow_test.dart' show pumpApp;
import 'fake_remote.dart';
import 'sync_controller_test.dart' show FakeAccount, FakeAuth;

/// A Drive folder that can fail uploads or hold a listing until released.
class FaultRemote implements AccountRemoteStore {
  final data = FakeRemote();
  bool failUpdate = false;
  Completer<void>? listGate;
  Completer<void>? listEntered;

  @override
  Future<String?> accountEmail() async => 'me@example.com';
  @override
  Future<String?> exportBackup(String name, List<int> bytes) async => null;
  @override
  Future<List<RemoteFile>> list(String prefix) async {
    listEntered?.complete();
    await listGate?.future;
    return data.list(prefix);
  }

  @override
  Future<List<int>> read(String id) => data.read(id);
  @override
  Future<String> create(String name, List<int> bytes) =>
      data.create(name, bytes);
  @override
  Future<void> update(String id, List<int> bytes) async {
    if (failUpdate) throw Exception('upload failed');
    await data.update(id, bytes);
  }
}

/// Storage that can refuse replica writes, like a full disk.
class FailingStore extends MemoryStore {
  bool fail = false;
  @override
  Future<void> write(String key, String value) {
    if (fail && key.startsWith('replica.')) {
      return Future.error(const StorageWriteFailed('replica'));
    }
    return super.write(key, value);
  }
}

ProviderContainer device(FaultRemote remote, {KeyValueStore? store}) {
  final c = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store ?? MemoryStore()),
      googleAuthProvider.overrideWithValue(
        FakeAuth({
          for (final ws in Workspace.values) ws: FakeAccount('me@example.com'),
        }),
      ),
      remoteFactoryProvider.overrideWithValue((_) => remote),
      iCloudSupportedProvider.overrideWithValue(false),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Another device's sync file holding one task.
Future<void> otherDeviceAdds(FaultRemote remote, String title) async {
  final now = DateTime.now();
  final other = Replica('other');
  other.put(
    collTasks,
    'remote-task',
    taskFields(
      Task(id: 'remote-task', title: title, createdAt: now, updatedAt: now),
    ),
    now,
  );
  await remote.data.create(
    'state.personal.other.json',
    utf8.encode(other.encode()),
  );
}

void main() {
  test('a download shows and is saved even when the upload after it fails, '
      'and the next round uploads it', () async {
    final remote = FaultRemote();
    final store = MemoryStore();
    final c = device(remote, store: store);
    final sync = c.read(syncProvider(Workspace.personal).notifier);
    await sync.connect();
    await otherDeviceAdds(remote, 'From the other device');

    remote.failUpdate = true;
    await sync.syncNow();
    expect(c.read(syncProvider(Workspace.personal)).phase, SyncPhase.error);
    expect(c.read(tasksProvider).map((t) => t.title), [
      'From the other device',
    ]);
    expect(store.read('replica.v1.personal'), contains('From the other'));

    remote.failUpdate = false;
    await sync.syncNow();
    expect(c.read(syncProvider(Workspace.personal)).phase, SyncPhase.synced);
    final own = (await remote.data.list('state.personal.'))
        .firstWhere((f) => f.name != 'state.personal.other.json');
    expect(utf8.decode(await remote.data.read(own.id)), contains('From the'));
  });

  test(
    'a failed disk write is flagged, and the next good write clears it',
    () async {
      final store = FailingStore();
      final c = device(FaultRemote(), store: store);
      final tasks = c.read(tasksProvider.notifier);
      store.fail = true;
      tasks.create(title: 'Not on disk yet');
      await pumpEventQueue();
      expect(c.read(replicasProvider).unsaved, {Workspace.personal});
      expect(store.read('replica.v1.personal'), isNull);

      store.fail = false;
      tasks.create(title: 'Second');
      await pumpEventQueue();
      expect(c.read(replicasProvider).unsaved, isEmpty);
      expect(store.read('replica.v1.personal'), contains('Not on disk yet'));
    },
  );

  test('a failed disk write is retried by itself', () async {
    final store = FailingStore();
    final c = device(FaultRemote(), store: store);
    store.fail = true;
    c.read(tasksProvider.notifier).create(title: 'Retried');
    await pumpEventQueue();
    expect(c.read(replicasProvider).unsaved, isNotEmpty);
    store.fail = false;
    await Future<void>.delayed(
      ReplicasController.retryAfter.first + const Duration(milliseconds: 200),
    );
    expect(c.read(replicasProvider).unsaved, isEmpty);
    expect(store.read('replica.v1.personal'), contains('Retried'));
  });

  test(
    'downloaded files aren\'t recorded as read until they\'re on disk',
    () async {
      final remote = FaultRemote();
      final store = FailingStore();
      final c = device(remote, store: store);
      final sync = c.read(syncProvider(Workspace.personal).notifier);
      await sync.connect();
      final before = store.read('sync.v1.personal');
      await otherDeviceAdds(remote, 'Downloaded');
      store.fail = true;
      await sync.syncNow();
      // After a restart this device must fetch the file again.
      expect(store.read('sync.v1.personal'), before);
    },
  );

  test('Disconnect stays disconnected when a round on the network finishes '
      'after it', () async {
    final remote = FaultRemote();
    final c = device(remote);
    final sync = c.read(syncProvider(Workspace.personal).notifier);
    await sync.connect();
    remote.listGate = Completer<void>();
    remote.listEntered = Completer<void>();
    final pending = sync.syncNow();
    await remote.listEntered!.future;
    await sync.disconnect();
    remote.listGate!.complete();
    await pending;
    expect(
      c.read(syncProvider(Workspace.personal)).phase,
      SyncPhase.disconnected,
    );
    expect(c.read(keyValueStoreProvider).read('sync.v1.personal'), isNull);
  });

  testWidgets('the app says so while a change isn\'t saved on this device', (
    tester,
  ) async {
    final store = FailingStore();
    final c = await pumpApp(tester, size: const Size(360, 800), store: store);
    expect(find.textContaining('Couldn\'t save'), findsNothing);
    store.fail = true;
    c.read(tasksProvider.notifier).create(title: 'Unsaved');
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn\'t save'), findsOneWidget);
    store.fail = false;
    c.read(tasksProvider.notifier).create(title: 'Saved');
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn\'t save'), findsNothing);
  });
}
