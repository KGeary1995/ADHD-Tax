import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/models/note.dart';
import '../../data/models/task.dart';
import '../../data/models/template.dart';
import '../../sync/replicas_controller.dart';
import '../notes/notes_controller.dart';
import '../settings/device_workspaces.dart';
import '../tasks/tasks_controller.dart';

const _uuid = Uuid();

/// Templates from the workspaces this device shows, by name.
final templatesProvider = NotifierProvider<TemplatesController, List<Template>>(
  TemplatesController.new,
);

class TemplatesController extends Notifier<List<Template>> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  List<Template> build() {
    ref.watch(replicasProvider.select((s) => s.docsVersion));
    final shown = ref.watch(deviceWorkspacesProvider).shown;
    return [
      for (final (ws, r) in ref.read(replicasProvider).entries)
        if (shown.contains(ws))
          for (final e in r.collection(collTemplates).entries)
            ?docFromRecord(e.key, e.value, Template.fromJson),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Template? byId(String id) => state.where((t) => t.id == id).firstOrNull;

  /// Saves [t]; one with an empty id is new and gets one. A workspace this
  /// device doesn't show is swapped for one it does.
  Template save(Template t) {
    final device = ref.read(deviceWorkspacesProvider);
    var saved = t.id.isEmpty
        ? Template.fromJson({...t.toJson(), 'id': _uuid.v4()})
        : t;
    if (!device.shown.contains(saved.workspace)) {
      saved = saved.copyWith(workspace: device.primary);
    }
    final previous = byId(saved.id);
    final replicas = ref.read(replicasProvider.notifier);
    if (previous != null && previous.workspace != saved.workspace) {
      replicas.write(
        previous.workspace,
        (r, now) => r.delete(collTemplates, saved.id, now),
        docs: true,
      );
    }
    final fields = docFields(saved.toJson());
    replicas.write(
      saved.workspace,
      (r, now) => r.put(collTemplates, saved.id, fields, now),
      docs: true,
    );
    return saved;
  }

  /// The editor's Save: applies only what changed between [original] (as
  /// the editor opened) and [edited], on top of the template as it is now,
  /// so a change synced in meanwhile isn't undone. Deleted meanwhile, it
  /// comes back as edited.
  Template saveEdits(Template original, Template edited) {
    final latest = byId(original.id);
    if (latest == null) return save(edited);
    final before = original.toJson();
    final merged = latest.toJson();
    edited.toJson().forEach((k, v) {
      if (before[k] != v) merged[k] = v;
    });
    return save(Template.fromJson(merged));
  }

  void delete(Template t) => ref
      .read(replicasProvider.notifier)
      .write(
        t.workspace,
        (r, now) => r.delete(collTemplates, t.id, now),
        docs: true,
      );

  /// A template made from an existing task: its checklist comes along
  /// unticked.
  Template fromTask(Task t) => save(
    Template(
      id: '',
      kind: TemplateKind.task,
      name: t.title,
      workspace: t.workspace,
      title: t.title,
      checklist: resetChecklist(t.checklist),
      estimateMin: t.estimateMin,
      tags: t.tags,
      createdAt: _now(),
    ),
  );

  Template fromNote(Note n) => save(
    Template(
      id: '',
      kind: TemplateKind.note,
      name: n.heading,
      workspace: n.workspace,
      title: n.title,
      body: n.body,
      createdAt: _now(),
    ),
  );

  /// A new task to open in the editor; nothing is saved yet.
  Task taskDraft(Template t) {
    final now = _now();
    return Task(
      id: '',
      title: fillTemplate(t.title.isEmpty ? t.name : t.title, now),
      workspace: t.workspace,
      checklist: resetChecklist(t.checklist),
      estimateMin: t.estimateMin,
      chunkable: t.estimateMin >= 60,
      tags: t.tags,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Creates the task straight away (Quick add's template picker).
  Task createTask(Template t) {
    final d = taskDraft(t);
    return ref
        .read(tasksProvider.notifier)
        .create(
          title: d.title,
          workspace: d.workspace,
          checklist: d.checklist,
          estimateMin: d.estimateMin,
          tags: d.tags,
        );
  }

  Note createNote(Template t) {
    final now = _now();
    return ref
        .read(notesProvider.notifier)
        .create(
          workspace: t.workspace,
          title: fillTemplate(t.title, now),
          body: fillTemplate(t.body, now),
        );
  }
}
