import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../sync/replica.dart';
import '../../sync/replicas_controller.dart';
import '../tasks/tasks_controller.dart';

const _uuid = Uuid();

T? _fromRecord<T>(
  String id,
  Record rec,
  T Function(Map<String, Object?>) fromJson,
) {
  if (rec.isDeleted) return null;
  try {
    return fromJson({...rec.values, 'id': id});
  } on Object {
    return null; // Written by a newer build in a way we can't read: skip.
  }
}

Map<String, Object?> _fields(Map<String, Object?> json) => json
  ..remove('id')
  ..['deleted'] = false;

/// Notes from both workspaces, newest first.
final notesProvider = NotifierProvider<NotesController, List<Note>>(
  NotesController.new,
);

class NotesController extends Notifier<List<Note>> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  List<Note> build() {
    ref.watch(replicasProvider.select((s) => s.docsVersion));
    return [
      for (final (_, r) in ref.read(replicasProvider).entries)
        for (final e in r.collection(collNotes).entries)
          ?_fromRecord(e.key, e.value, Note.fromJson),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Note? byId(String id) {
    for (final (_, r) in ref.read(replicasProvider).entries) {
      final rec = r.get(collNotes, id);
      final n = rec == null ? null : _fromRecord(id, rec, Note.fromJson);
      if (n != null) return n;
    }
    return null;
  }

  Note create({
    Workspace workspace = Workspace.personal,
    String title = '',
    String body = '',
    String projectId = '',
    String taskId = '',
  }) {
    final now = _now();
    final n = Note(
      id: _uuid.v4(),
      workspace: workspace,
      title: title,
      body: body,
      projectId: projectId,
      taskId: taskId,
      createdAt: now,
      updatedAt: now,
    );
    _write(n);
    return n;
  }

  void save(Note n) => _write(n.copyWith(updatedAt: _now()));

  void delete(String id) {
    final n = byId(id);
    if (n == null) return;
    ref
        .read(replicasProvider.notifier)
        .write(
          n.workspace,
          (r, now) => r.delete(collNotes, id, now),
          docs: true,
        );
  }

  /// Undo for delete.
  void restore(Note n) => _write(n.copyWith(updatedAt: _now()));

  void togglePin(String id) {
    final n = byId(id);
    if (n != null) save(n.copyWith(pinned: !n.pinned));
  }

  /// Turns the chosen lines into tasks in the note's workspace and project.
  List<Task> makeTasks(Note n, Iterable<String> lines) {
    final tasks = ref.read(tasksProvider.notifier);
    return [
      for (final line in lines)
        if (line.trim().isNotEmpty)
          tasks.create(
            title: line.trim(),
            workspace: n.workspace,
            projectId: n.projectId,
            notes: 'From the note "${n.heading}"',
          ),
    ];
  }

  void _write(Note n) {
    final replicas = ref.read(replicasProvider.notifier);
    final previous = byId(n.id);
    // Same rule as tasks: moving it to the other workspace removes it from
    // the old workspace's Google account.
    if (previous != null && previous.workspace != n.workspace) {
      replicas.write(
        previous.workspace,
        (r, now) => r.delete(collNotes, n.id, now),
        docs: true,
      );
    }
    replicas.write(
      n.workspace,
      (r, now) => r.put(collNotes, n.id, _fields(n.toJson()), now),
      docs: true,
    );
  }
}

/// Projects from both workspaces, by name.
final projectsProvider = NotifierProvider<ProjectsController, List<Project>>(
  ProjectsController.new,
);

class ProjectsController extends Notifier<List<Project>> {
  @override
  List<Project> build() {
    ref.watch(replicasProvider.select((s) => s.docsVersion));
    return [
      for (final (_, r) in ref.read(replicasProvider).entries)
        for (final e in r.collection(collProjects).entries)
          ?_fromRecord(e.key, e.value, Project.fromJson),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Project? byId(String id) =>
      id.isEmpty ? null : state.where((p) => p.id == id).firstOrNull;

  List<Project> inWorkspace(Workspace ws) =>
      state.where((p) => p.workspace == ws).toList();

  Project create(String name, Workspace workspace) {
    final p = Project(
      id: _uuid.v4(),
      name: name.trim(),
      workspace: workspace,
      color: state.length,
      createdAt: ref.read(clockProvider)(),
    );
    _write(p);
    return p;
  }

  void rename(String id, String name) {
    final p = byId(id);
    if (p != null && name.trim().isNotEmpty) {
      _write(p.copyWith(name: name.trim()));
    }
  }

  /// Deletes the project. Its tasks and notes stay, without a project.
  void delete(String id) {
    final p = byId(id);
    if (p == null) return;
    final tasks = ref.read(tasksProvider.notifier);
    for (final t in ref.read(tasksProvider)) {
      if (t.projectId == id) tasks.save(t.copyWith(projectId: ''));
    }
    final notes = ref.read(notesProvider.notifier);
    for (final n in ref.read(notesProvider)) {
      if (n.projectId == id) notes.save(n.copyWith(projectId: ''));
    }
    ref
        .read(replicasProvider.notifier)
        .write(
          p.workspace,
          (r, now) => r.delete(collProjects, id, now),
          docs: true,
        );
  }

  void _write(Project p) => ref
      .read(replicasProvider.notifier)
      .write(
        p.workspace,
        (r, now) => r.put(collProjects, p.id, _fields(p.toJson()), now),
        docs: true,
      );
}
