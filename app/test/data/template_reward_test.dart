import 'package:adhd_tax/data/models/reward.dart';
import 'package:adhd_tax/data/models/task.dart';
import 'package:adhd_tax/data/models/template.dart';
import 'package:adhd_tax/features/safety/phi_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 19, 9);

  test('template JSON round trip, with defaults for missing fields', () {
    final t = exampleTemplates(now).first.copyWith(tags: 'opening');
    final back = Template.fromJson({...t.toJson(), 'id': 'x'});
    expect(back.toJson(), {...t.toJson(), 'id': 'x'});
    final bare = Template.fromJson({'id': 'y'});
    expect(bare.kind, TemplateKind.task);
    expect(bare.estimateMin, 15);
    expect(bare.workspace, Workspace.personal);
  });

  test('{date} and {weekday} fill in', () {
    expect(fillTemplate('Huddle {date}', now), 'Huddle Oct 19');
    expect(fillTemplate('{weekday} plan', now), 'Monday plan');
  });

  test('the examples carry no patient-looking details', () {
    for (final t in exampleTemplates(now)) {
      expect(
        scanForPhi('${t.name}\n${t.title}\n${t.body}\n${t.checklist}'),
        isEmpty,
        reason: t.name,
      );
    }
  });

  test('reward JSON round trip; a bad price is clamped', () {
    final r = Reward(id: 'r', name: 'Coffee', cost: 25, createdAt: now);
    expect(Reward.fromJson(r.toJson()).toJson(), r.toJson());
    expect(Reward.fromJson({'id': 'z', 'cost': -4}).cost, 1);
  });
}
