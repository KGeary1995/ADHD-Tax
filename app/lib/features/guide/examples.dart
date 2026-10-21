import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/task.dart';
import '../notes/notes_controller.dart';
import '../settings/device_workspaces.dart';
import '../tasks/tasks_controller.dart';

/// Example tasks, notes and a project for trying the app before adding
/// your own. Their ids are remembered on this device, so "Remove example
/// tasks" takes away exactly these and never touches anything you made.
final examplesProvider = NotifierProvider<ExamplesController, Set<String>>(
  ExamplesController.new,
);

/// True while any example task is still open or an example note exists.
final examplesShowingProvider = Provider<bool>((ref) {
  final ids = ref.watch(examplesProvider);
  if (ids.isEmpty) return false;
  return ref
          .watch(tasksProvider)
          .any((t) => t.isOpen && ids.contains('t:${t.id}')) ||
      ref.watch(notesProvider).any((n) => ids.contains('n:${n.id}'));
});

class ExamplesController extends Notifier<Set<String>> {
  static const _key = 'examples.ids';

  @override
  Set<String> build() {
    final raw = ref.read(keyValueStoreProvider).read(_key);
    if (raw == null) return const {};
    try {
      return {for (final id in jsonDecode(raw) as List) id as String};
    } on Object {
      return const {};
    }
  }

  void add() {
    final ws = ref.read(deviceWorkspacesProvider).primary;
    final tasks = ref.read(tasksProvider.notifier);
    final notes = ref.read(notesProvider.notifier);
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final ids = <String>{...state};

    final home = ref.read(projectsProvider.notifier).create('Home', ws);
    ids.add('p:${home.id}');

    Task t(Task task) {
      ids.add('t:${task.id}');
      return task;
    }

    t(
      tasks.create(
        title: 'Clear out the email inbox',
        workspace: ws,
        estimateMin: 30,
        priority: Priority.p2,
        ugh: 2,
        firstStep: 'Archive everything older than a month',
      ),
    );
    t(
      tasks.create(
        title: 'Plan meals for the week',
        workspace: ws,
        projectId: home.id,
        checklist:
            "[ ] Check what's in the fridge\n[ ] Pick three dinners\n"
            '[ ] Write the shopping list',
      ),
    );
    t(
      tasks.create(
        title: 'Book a dentist appointment',
        workspace: ws,
        estimateMin: 5,
        ugh: 2,
        firstStep: 'Look up their number',
      ),
    );
    t(
      tasks.create(
        title: 'Renew car registration',
        workspace: ws,
        estimateMin: 30,
        priority: Priority.p2,
        tags: 'car',
        dueAt: today.add(const Duration(days: 3, hours: 17)),
      ),
    );
    for (final (title, place, minutes) in [
      ('Pick up prescription', 'Pharmacy', 15),
      ('Post the birthday card', 'Post office', 10),
    ]) {
      final e = t(
        tasks.create(
          title: title,
          workspace: ws,
          estimateMin: minutes,
          requiresLeavingHouse: true,
        ),
      );
      tasks.save(e.copyWith(location: place));
    }
    final plants = t(
      tasks.create(
        title: 'Water the plants',
        workspace: ws,
        estimateMin: 5,
        energy: Energy.low,
        projectId: home.id,
        dueAt: today.add(const Duration(hours: 20)),
      ),
    );
    tasks.save(plants.copyWith(repeat: Repeat.weekly));
    final quote = t(
      tasks.create(
        title: 'Get the car repair quote',
        workspace: ws,
        estimateMin: 10,
      ),
    );
    tasks.setWaiting(quote.id, waitingOn: 'the garage', followUpAt: now);

    for (final (title, body) in [
      (
        'Gift ideas',
        'Mum: the blue scarf from the market\nSam: a board game #family',
      ),
      (
        'Book club notes',
        'Next book: pick by Friday\nBring snacks next time\n'
            'Ask Jo to host in March #friends',
      ),
    ]) {
      final n = notes.create(
        workspace: ws,
        title: title,
        body: body,
        projectId: title == 'Gift ideas' ? home.id : '',
      );
      ids.add('n:${n.id}');
    }
    _set(ids);
  }

  /// Deletes every example that's still there. XP earned while trying
  /// them stays: progress is never rewritten.
  void remove() {
    final tasks = ref.read(tasksProvider.notifier);
    final notes = ref.read(notesProvider.notifier);
    final projects = ref.read(projectsProvider.notifier);
    for (final id in state) {
      final raw = id.substring(2);
      switch (id[0]) {
        case 't':
          tasks.delete(raw);
        case 'n':
          notes.delete(raw);
        case 'p':
          projects.delete(raw);
      }
    }
    _set(const {});
  }

  void _set(Set<String> ids) {
    final store = ref.read(keyValueStoreProvider);
    if (ids.isEmpty) {
      store.remove(_key);
    } else {
      store.write(_key, jsonEncode(ids.toList()));
    }
    state = ids;
  }
}
