import 'dart:convert';

import 'package:adhd_tax/core/hlc.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/sync/replica.dart';
import 'package:adhd_tax/sync/replicas_controller.dart';
import 'package:adhd_tax/sync/sync_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_remote.dart';

void main() {
  var tick = DateTime.utc(2026, 10, 17);
  DateTime now() => tick = tick.add(const Duration(seconds: 1));

  test('a reloaded replica remembers its latest write, so a quiet round '
      'after a restart uploads nothing', () async {
    final remote = FakeRemote();
    final phone = Replica('phone')..put('tasks', '1', {'title': 'x'}, now());
    var state = (await syncOnce(
      replica: phone,
      remote: remote,
      workspace: 'personal',
      state: const SyncState(),
      now: now,
    )).state;

    final reloaded = Replica.decode(phone.encode(), node: 'phone');
    expect(reloaded.lastLocalWrite, phone.lastLocalWrite);
    final out = await syncOnce(
      replica: reloaded,
      remote: remote,
      workspace: 'personal',
      state: state,
      now: now,
    );
    expect(out.uploaded, isFalse);
    state = out.state;

    // Another device's file re-owned as ours brings none of its writes.
    final foreign = Replica.decode(phone.encode(), node: 'backup');
    expect(foreign.lastLocalWrite, isNull);
  });

  test('uploadedClock can be cleared', () {
    const s = SyncState(uploadedClock: 'abc');
    expect(s.copyWith().uploadedClock, 'abc');
    expect(s.copyWith(uploadedClock: null).uploadedClock, isNull);
  });

  test('a file with a clock that does not parse is skipped, and our own '
      'edits still upload', () async {
    final remote = FakeRemote();
    await remote.create(
      'state.personal.broken.json',
      utf8.encode(jsonEncode({'v': 1, 'node': 'broken', 'clock': 'nonsense'})),
    );
    final phone = Replica('phone')..put('tasks', '1', {'title': 'x'}, now());
    final out = await syncOnce(
      replica: phone,
      remote: remote,
      workspace: 'personal',
      state: const SyncState(),
      now: now,
    );
    expect(out.skipped, ['state.personal.broken.json']);
    expect(out.uploaded, isTrue);
    expect(() => Hlc.parse('nonsense'), throwsFormatException);
  });

  test('our own file holding writes we never made is reported as a clone, '
      'and is not overwritten', () async {
    final remote = FakeRemote();
    final a = Replica('same')..put('tasks', '1', {'title': 'x'}, now());
    var state = (await syncOnce(
      replica: a,
      remote: remote,
      workspace: 'personal',
      state: const SyncState(),
      now: now,
    )).state;
    final b = Replica.decode(a.encode(), node: 'same');

    // A writes more and uploads; B (a copy of A) then checks its file.
    a.put('tasks', '2', {'title': 'only on A'}, now());
    state = (await syncOnce(
      replica: a,
      remote: remote,
      workspace: 'personal',
      state: state,
      now: now,
    )).state;
    final before = remote.text(state.ownFileId!);
    b.put('tasks', '3', {'title': 'only on B'}, now());
    final out = await syncOnce(
      replica: b,
      remote: remote,
      workspace: 'personal',
      state: state,
      now: now,
      checkOwn: true,
    );
    expect(out.cloned, isTrue);
    expect(out.uploaded, isFalse);
    expect(remote.text(state.ownFileId!), before);
    expect(b.collection('tasks').keys, containsAll(['1', '2', '3']));

    // A checking its own file finds nothing it didn't write.
    final self = await syncOnce(
      replica: a,
      remote: remote,
      workspace: 'personal',
      state: state,
      now: now,
      checkOwn: true,
    );
    expect(self.cloned, isFalse);
  });

  test('a remembered file id for a different name is dropped, so a new '
      'device id gets its own file', () async {
    final remote = FakeRemote();
    final old = Replica('old')..put('tasks', '1', {'title': 'x'}, now());
    final state = (await syncOnce(
      replica: old,
      remote: remote,
      workspace: 'personal',
      state: const SyncState(),
      now: now,
    )).state;
    final renamed = Replica.decode(old.encode(), node: 'new');
    final out = await syncOnce(
      replica: renamed,
      remote: remote,
      workspace: 'personal',
      state: state,
      now: now,
    );
    expect(out.uploaded, isTrue);
    expect(remote.files.values.map((f) => f.$1).toSet(), {
      'state.personal.old.json',
      'state.personal.new.json',
    });
  });

  test('a clock far in the future only pulls ours along a little', () {
    final t0 = DateTime.utc(2026, 10, 17, 12);
    final far = Hlc(DateTime.utc(2030).millisecondsSinceEpoch, 0, 'b');
    final mine = const Hlc.zero('a').receive(far, t0);
    expect(
      mine.millis,
      lessThanOrEqualTo(t0.add(Hlc.maxDrift).millisecondsSinceEpoch + 1),
    );
  });

  test('saving a task leaves alone a value only a newer build knows', () {
    final r = Replica('phone');
    final t = Task(
      id: 't',
      title: 'Taxes',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
    r.put(collTasks, 't', taskFields(t), now());
    // A newer build sets a kind of repeat this build doesn't know.
    r.put(collTasks, 't', {'repeat': 'yearly'}, now());

    final read = taskFromRecord('t', r.get(collTasks, 't')!)!;
    putChanged(
      r,
      collTasks,
      't',
      taskFields(read.copyWith(title: 'Taxes 2026')),
      (j) => Task.fromJson(j).toJson(),
      now(),
    );
    final rec = r.get(collTasks, 't')!;
    expect(rec.values['repeat'], 'yearly');
    expect(rec.values['title'], 'Taxes 2026');
  });
}
