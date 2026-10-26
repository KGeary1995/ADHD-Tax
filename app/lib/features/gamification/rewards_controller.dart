import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../data/models/reward.dart';
import '../../data/models/task.dart';
import '../../sync/replicas_controller.dart';
import '../settings/device_workspaces.dart';
import 'progress_controller.dart';
import 'progress_event.dart';

const _uuid = Uuid();

/// The reward shop's items, cheapest first.
final rewardsProvider = NotifierProvider<RewardsController, List<Reward>>(
  RewardsController.new,
);

class RewardsController extends Notifier<List<Reward>> {
  DateTime _now() => ref.read(clockProvider)();

  @override
  List<Reward> build() {
    ref.watch(replicasProvider.select((s) => s.docsVersion));
    final shown = ref.watch(deviceWorkspacesProvider).shown;
    return [
      for (final (ws, r) in ref.read(replicasProvider).entries)
        if (shown.contains(ws))
          for (final e in r.collection(collRewards).entries)
            ?docFromRecord(e.key, e.value, Reward.fromJson),
    ]..sort((a, b) {
      final c = a.cost.compareTo(b.cost);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  }

  Reward create(String name, int cost) {
    final r = Reward(
      id: _uuid.v4(),
      name: name.trim(),
      cost: cost.clamp(1, 1000000),
      workspace: ref.read(deviceWorkspacesProvider).primary,
      createdAt: _now(),
    );
    _write(r);
    return r;
  }

  void save(Reward r) => _write(r);

  void delete(Reward r) => ref
      .read(replicasProvider.notifier)
      .write(
        r.workspace,
        (rep, now) => rep.delete(collRewards, r.id, now),
        docs: true,
      );

  /// Spends the coins, as an event so it syncs like XP. Null when there
  /// aren't enough coins.
  ProgressEvent? redeem(Reward r) {
    if (ref.read(progressProvider).coins < r.cost) return null;
    final e = ProgressEvent(
      id: _uuid.v4(),
      at: _now(),
      kind: ProgressKind.redeemed,
      label: r.name,
      coins: -r.cost,
    );
    ref
        .read(replicasProvider.notifier)
        .write(
          r.workspace,
          (rep, now) => rep.put(collEvents, e.id, e.toJson(), now),
          events: true,
        );
    return e;
  }

  /// Undo for [redeem]: tombstones the event, so the coins come back on
  /// every device.
  void unredeem(ProgressEvent e) {
    for (final ws in Workspace.values) {
      ref
          .read(replicasProvider.notifier)
          .write(
            ws,
            (rep, now) => rep.delete(collEvents, e.id, now),
            events: true,
          );
    }
  }

  void _write(Reward r) => ref
      .read(replicasProvider.notifier)
      .write(
        r.workspace,
        (rep, now) => rep.put(collRewards, r.id, docFields(r.toJson()), now),
        docs: true,
      );
}

/// Rewards bought, newest first. A workspace this device doesn't show
/// keeps its reward names to itself, as in Progress.
final redemptionsProvider = Provider<List<ProgressEvent>>((ref) {
  ref.watch(replicasProvider.select((s) => s.eventsVersion));
  final shown = ref.watch(deviceWorkspacesProvider).shown;
  return [
    for (final (ws, r) in ref.read(replicasProvider).entries)
      for (final e in r.collection(collEvents).entries)
        if (!e.value.isDeleted && e.value.values['kind'] == 'redeemed')
          if (ProgressEvent.fromJson(e.key, e.value.values) case final event)
            shown.contains(ws)
                ? event
                : event.copyWith(label: hiddenLabel(event, ws)),
  ]..sort((a, b) => b.at.compareTo(a.at));
});
