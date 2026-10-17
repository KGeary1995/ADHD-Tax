import 'package:adhd_tax/sync/replica.dart';
import 'package:adhd_tax/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_remote.dart';

/// A simulated device: its replica plus its remembered sync state.
class Device {
  Device(this.id) : replica = Replica(id);
  final String id;
  Replica replica;
  SyncState state = const SyncState();
}

void main() {
  var tick = DateTime.utc(2026, 10, 17);
  DateTime now() => tick = tick.add(const Duration(seconds: 1));

  Future<SyncOutcome> sync(
    Device d,
    FakeRemote remote, {
    String ws = 'personal',
  }) async {
    final out = await syncOnce(
      replica: d.replica,
      remote: remote,
      workspace: ws,
      state: d.state,
      now: now,
    );
    d.state = out.state;
    return out;
  }

  test('first sync creates our file; quiet rounds upload nothing', () async {
    final remote = FakeRemote();
    final phone = Device('phone')
      ..replica.put('tasks', '1', {'title': 'x'}, now());
    final first = await sync(phone, remote);
    expect(first.uploaded, isTrue);
    expect(remote.files.values.single.$1, 'state.personal.phone.json');

    final second = await sync(phone, remote);
    expect(second.uploaded, isFalse);
    expect(remote.writes, 1);
  });

  test('two devices exchange edits and then go quiet (no ping-pong)', () async {
    final remote = FakeRemote();
    final phone = Device('phone')
      ..replica.put('tasks', '1', {'title': 'from phone'}, now());
    final pc = Device('pc')
      ..replica.put('tasks', '2', {'title': 'from pc'}, now());

    await sync(phone, remote);
    await sync(pc, remote);
    final back = await sync(phone, remote);
    expect(back.merged, isTrue);

    for (final d in [phone, pc]) {
      expect(d.replica.collection('tasks').keys.toSet(), {'1', '2'});
    }

    // Nothing new on either side: further rounds neither upload nor download.
    final writes = remote.writes;
    final reads = remote.reads;
    for (var i = 0; i < 3; i++) {
      await sync(phone, remote);
      await sync(pc, remote);
    }
    expect(remote.writes, writes);
    expect(remote.reads, reads);
  });

  test('offline edits on both devices converge after reconnecting', () async {
    final remote = FakeRemote();
    final phone = Device('phone')
      ..replica.put('tasks', '1', {'title': 'Taxes', 'ugh': 0}, now());
    final pc = Device('pc');
    await sync(phone, remote);
    await sync(pc, remote);

    // Both edit while "offline".
    phone.replica.put('tasks', '1', {'ugh': 3}, now());
    pc.replica.put('tasks', '1', {'title': 'File taxes'}, now());

    await sync(phone, remote);
    await sync(pc, remote);
    await sync(phone, remote);

    for (final d in [phone, pc]) {
      expect(d.replica.get('tasks', '1')!.values, {
        'title': 'File taxes',
        'ugh': 3,
      });
    }
  });

  test('workspaces are separate files even on the same account', () async {
    final remote = FakeRemote();
    final personal = Device('pc')
      ..replica.put('tasks', 'p', {'title': 'Laundry'}, now());
    final work = Device('pc')
      ..replica.put('tasks', 'w', {'title': 'Template'}, now());
    await sync(personal, remote, ws: 'personal');
    await sync(work, remote, ws: 'work');
    expect(remote.files.values.map((f) => f.$1).toSet(), {
      'state.personal.pc.json',
      'state.work.pc.json',
    });

    final other = Device('phone');
    await sync(other, remote, ws: 'work');
    expect(other.replica.collection('tasks').keys, ['w']);
  });

  test('a corrupt remote file is skipped, not fatal', () async {
    final remote = FakeRemote();
    await remote.create('state.personal.broken.json', [1, 2, 3, 0x7b]);
    final d = Device('pc')..replica.put('tasks', '1', {'title': 'x'}, now());
    final out = await sync(d, remote);
    expect(out.skipped, ['state.personal.broken.json']);
    expect(out.uploaded, isTrue);
  });

  test('our file deleted remotely gets recreated', () async {
    final remote = FakeRemote();
    final d = Device('pc')..replica.put('tasks', '1', {'title': 'x'}, now());
    await sync(d, remote);
    remote.files.clear();
    final out = await sync(d, remote);
    expect(out.uploaded, isTrue);
    expect(remote.files.length, 1);
  });

  test('network failure propagates and leaves state untouched', () async {
    final remote = FakeRemote()..failNextList = true;
    final d = Device('pc')..replica.put('tasks', '1', {'title': 'x'}, now());
    final before = d.state;
    await expectLater(sync(d, remote), throwsException);
    expect(d.state, same(before));
  });

  test('a brand-new device pulls everything', () async {
    final remote = FakeRemote();
    final a = Device('a');
    for (var i = 0; i < 20; i++) {
      a.replica.put('tasks', '$i', {'title': 'task $i'}, now());
    }
    a.replica.delete('tasks', '3', now());
    await sync(a, remote);
    final fresh = Device('new');
    await sync(fresh, remote);
    final tasks = fresh.replica.collection('tasks');
    expect(tasks.length, 20);
    expect(tasks['3']!.isDeleted, isTrue);
  });
}
