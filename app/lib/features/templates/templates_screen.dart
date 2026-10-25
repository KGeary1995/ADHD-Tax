import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_themes.dart';
import '../../data/models/task.dart' show formatMinutes;
import '../../data/models/template.dart';
import '../../widgets/ui.dart';
import 'templates_controller.dart';
import '../../core/theme/ph.dart';

/// Opens a new task (in the editor, unsaved) or note from [t].
void useTemplate(BuildContext context, WidgetRef ref, Template t) {
  final templates = ref.read(templatesProvider.notifier);
  switch (t.kind) {
    case TemplateKind.task:
      context.push('/task/new', extra: templates.taskDraft(t));
    case TemplateKind.note:
      context.push('/note/${templates.createNote(t).id}');
  }
}

/// Picks a template of [kind]. With none yet, offers the Templates screen.
Future<Template?> pickTemplate(
  BuildContext context,
  WidgetRef ref,
  TemplateKind kind,
) {
  final list = ref
      .read(templatesProvider)
      .where((t) => t.kind == kind)
      .toList();
  return showAppSheet<Template>(
    context: context,
    builder: (ctx) {
      final s = ctx.spec;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                kind == TemplateKind.task ? 'Task templates' : 'Note templates',
                style: s.display(22),
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'None yet. Make one for anything you do over and over.',
                  style: TextStyle(color: s.muted),
                ),
              ),
            for (final t in list)
              ListTile(
                title: Text(t.name),
                subtitle: Text(templateSummary(t)),
                onTap: () => Navigator.pop(ctx, t),
              ),
            ListTile(
              leading: const Icon(Ph.slidersHorizontal),
              title: const Text('Manage templates'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/templates');
              },
            ),
          ],
        ),
      );
    },
  );
}

String templateSummary(Template t) => switch (t.kind) {
  TemplateKind.task => [
    if (t.stepCount > 0)
      '${t.stepCount} ${t.stepCount == 1 ? 'step' : 'steps'}',
    formatMinutes(t.estimateMin),
  ].join(' · '),
  TemplateKind.note =>
    t.body.trim().isEmpty
        ? 'Note'
        : t.body.trim().split('\n').first.replaceAll(RegExp(r'\s+'), ' '),
};

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final all = ref.watch(templatesProvider);
    final now = ref.read(clockProvider)();
    final narrow = MediaQuery.sizeOf(context).width < 420;

    List<Widget> section(TemplateKind kind, String title) {
      final list = all.where((t) => t.kind == kind).toList();
      if (list.isEmpty) return const [];
      return [
        SectionTitle(title, count: list.length),
        for (final t in list) _TemplateTile(template: t),
        const SizedBox(height: 22),
      ];
    }

    return Scaffold(
      appBar: topBar(context, title: 'Templates'),
      body: ContentWidth(
        maxWidth: 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            narrow ? 16 : 22,
            8,
            narrow ? 16 : 22,
            48,
          ),
          children: [
            Text(
              'Things you do again and again: an opening checklist, a '
              'meeting note layout. Use one and everything is filled in.',
              style: TextStyle(color: s.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            ...section(TemplateKind.task, 'Tasks'),
            ...section(TemplateKind.note, 'Notes'),
            if (all.isEmpty) ...[
              const FieldLabel('Start from an example'),
              for (final t in exampleTemplates(now))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    radius: 18,
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: s.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${t.kind.label} · ${templateSummary(t)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, color: s.muted),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.read(templatesProvider.notifier).save(t),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final k in TemplateKind.values)
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/template/new?kind=${k.name}'),
                    icon: const Icon(Ph.plusBold),
                    label: Text('New ${k.label.toLowerCase()} template'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template});
  final Template template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final t = template;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Panel(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        onTap: () => useTemplate(context, ref, t),
        child: Row(
          children: [
            Icon(
              t.kind == TemplateKind.task ? Ph.listChecks : Ph.note,
              color: s.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    templateSummary(t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: s.muted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              useRootNavigator: true,
              tooltip: 'Template options',
              icon: Icon(Ph.dotsThreeVertical, color: s.muted),
              onSelected: (v) => switch (v) {
                'use' => useTemplate(context, ref, t),
                'edit' => context.push('/template/${t.id}'),
                _ => ref.read(templatesProvider.notifier).delete(t),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'use',
                  child: Text('New ${t.kind.label.toLowerCase()}'),
                ),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
