import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/device_workspaces.dart';
import '../../core/providers.dart';
import '../../data/models/task.dart';
import '../settings/settings_controller.dart';
import '../tasks/tasks_controller.dart';
import '../insights/estimate_calibration.dart';
import 'picker_engine.dart';

/// Time-available chips on the dashboard, in minutes.
const timeOptions = [10, 15, 30, 45, 60, 90, 120];

class PickerInputs {
  const PickerInputs({
    this.availableMin = 30,
    this.willingToLeave = false,
    this.energy,
    this.workspaces = const {Workspace.personal, Workspace.work},
    this.rejected = const {},
    this.chosen,
  });

  final int availableMin;
  final bool willingToLeave;
  final Energy? energy;
  final Set<Workspace> workspaces;

  /// Tasks passed on with "Not this one" during this session.
  final Set<String> rejected;

  /// Chosen from "Pick one of these three": shown first until done or
  /// passed on.
  final String? chosen;

  /// After two rerolls we stop rerolling and ask the user to commit.
  bool get shouldCommit => rejected.length >= 2;

  PickerInputs copyWith({
    int? availableMin,
    bool? willingToLeave,
    Energy? Function()? energy,
    Set<Workspace>? workspaces,
    Set<String>? rejected,
    String? Function()? chosen,
  }) => PickerInputs(
    availableMin: availableMin ?? this.availableMin,
    willingToLeave: willingToLeave ?? this.willingToLeave,
    energy: energy != null ? energy() : this.energy,
    workspaces: workspaces ?? this.workspaces,
    rejected: rejected ?? this.rejected,
    chosen: chosen != null ? chosen() : this.chosen,
  );
}

final pickerInputsProvider =
    NotifierProvider<PickerInputsController, PickerInputs>(
      PickerInputsController.new,
    );

class PickerInputsController extends Notifier<PickerInputs> {
  @override
  PickerInputs build() {
    // A Personal-only or Work-only install picks from that one.
    final device = ref.watch(deviceWorkspacesProvider);
    return device.single
        ? PickerInputs(workspaces: {device.primary})
        : const PickerInputs();
  }

  // Changing the situation is a fresh question, so rerolls reset.
  void setTime(int min) =>
      state = state.copyWith(availableMin: min, rejected: const {});

  void setWillingToLeave(bool v) =>
      state = state.copyWith(willingToLeave: v, rejected: const {});

  void setEnergy(Energy? e) =>
      state = state.copyWith(energy: () => e, rejected: const {});

  void setWorkspaces(Set<Workspace> w) =>
      state = state.copyWith(workspaces: w, rejected: const {});

  void reject(String taskId) {
    ref.read(tasksProvider.notifier).skip(taskId);
    state = state.copyWith(
      rejected: {...state.rejected, taskId},
      chosen: state.chosen == taskId ? () => null : null,
    );
  }

  void resetRejections() => state = state.copyWith(rejected: const {});

  /// "Pick one of these three": that one, and no more rerolling.
  void choose(String taskId) =>
      state = state.copyWith(rejected: const {}, chosen: () => taskId);
}

const pickerEngine = PickerEngine();

PickerContext _context(
  PickerInputs i,
  DateTime now, [
  Calibrations calibration = const Calibrations(),
]) => PickerContext(
  availableMin: i.availableMin,
  willingToLeave: i.willingToLeave,
  energy: i.energy,
  workspaces: i.workspaces,
  now: now,
  calibration: calibration,
);

/// How long tasks really take you compared with your estimates.
final calibrationProvider = Provider<Calibrations>(
  (ref) => calibrate(ref.watch(tasksProvider)),
);

/// When the picks were last worked out, and when they next need to be
/// ([nextPickerBoundary]). Invalidating it makes them look again:
/// `OutsideBootstrap` does that at `next` and on resume, since nothing else
/// they watch changes just because time passes (a task snoozed until 10
/// stayed hidden after 10). Anything else that sorts tasks by the time
/// watches it too: the errand run, the Tasks list and board (Coming up),
/// Today's check-back.
final pickerTickProvider = Provider<({DateTime now, DateTime next})>((ref) {
  // Rebuilt with the tasks too, so a new snooze moves `next`.
  final tasks = ref.watch(tasksProvider);
  final now = ref.read(clockProvider)();
  return (now: now, next: nextPickerBoundary(tasks, now));
});

/// Rebuilds when the part of the day changes (noon, 5 pm, 10 pm, midnight):
/// Home's "Wrap up" link appears at 5 pm and the desktop header says
/// "morning" or "evening". Watch it, then read the clock. The app shell
/// (OutsideBootstrap) invalidates it at [nextDayPart] and on resume.
final dayPartProvider = Provider<DateTime>((ref) => ref.read(clockProvider)());

/// The next of today's noon, 5 pm and 10 pm, or else midnight.
DateTime nextDayPart(DateTime now) {
  for (final h in const [12, 17, 22]) {
    final at = DateTime(now.year, now.month, now.day, h);
    if (at.isAfter(now)) return at;
  }
  return DateTime(now.year, now.month, now.day + 1);
}

/// When what's eligible next changes by itself: the earliest start time
/// of a snoozed or scheduled open task or check-back date of a waiting
/// one, or else midnight (last night's wrap-up pick lapses).
DateTime nextPickerBoundary(Iterable<Task> tasks, DateTime now) {
  var next = DateTime(now.year, now.month, now.day + 1);
  for (final t in tasks) {
    final at = t.isOpen
        ? t.scheduledStart
        : t.status == TaskStatus.waiting
        ? t.followUpAt
        : null;
    if (at != null && at.isAfter(now) && at.isBefore(next)) next = at;
  }
  return next;
}

/// The one task the dashboard shows.
final pickResultProvider = Provider<PickResult>((ref) {
  ref.watch(pickerTickProvider);
  final tasks = ref.watch(tasksProvider);
  final inputs = ref.watch(pickerInputsProvider);
  final now = ref.read(clockProvider)();
  final ctx = _context(inputs, now, ref.watch(calibrationProvider));
  // Chosen just now from three, or in last night's wrap-up: first, until
  // done or passed on.
  final pinnedId =
      inputs.chosen ??
      ref.watch(settingsProvider.select((s) => s.pinnedFor(now)));
  final pinned = pinnedId == null || inputs.rejected.contains(pinnedId)
      ? null
      : tasks
            .where(
              (t) =>
                  t.id == pinnedId &&
                  t.isOpen &&
                  inputs.workspaces.contains(t.workspace),
            )
            .firstOrNull;
  if (pinned != null) {
    final real = ctx.realMinutes(pinned);
    final chunk = real > inputs.availableMin && pinned.chunkable;
    return PickResult.found(
      Suggestion(
        task: pinned,
        score: double.infinity,
        plannedMin: chunk ? inputs.availableMin : real,
        isChunk: chunk,
        reasons: [
          inputs.chosen == pinned.id
              ? 'You chose this one'
              : 'You chose this last night',
        ],
      ),
    );
  }
  return pickerEngine.pick(tasks, ctx, exclude: inputs.rejected);
});

/// What else would fit right now, best first, for the large home-screen
/// widget's "Next up" list.
final nextUpProvider = Provider<List<Suggestion>>((ref) {
  ref.watch(pickerTickProvider);
  final inputs = ref.watch(pickerInputsProvider);
  return pickerEngine
      .rank(
        ref.watch(tasksProvider),
        _context(
          inputs,
          ref.read(clockProvider)(),
          ref.watch(calibrationProvider),
        ),
        exclude: inputs.rejected,
      )
      .take(4)
      .toList();
});

/// "Pick one of these 3 and commit" after too many rerolls. Rejected tasks
/// are allowed back in: the point is to choose, not to keep skipping.
final commitChoicesProvider = Provider<List<Suggestion>>((ref) {
  ref.watch(pickerTickProvider);
  final tasks = ref.watch(tasksProvider);
  final inputs = ref.watch(pickerInputsProvider);
  final now = ref.read(clockProvider)();
  // Ignore the temporary skip penalty so the original picks can compete.
  final unpenalized = [
    for (final t in tasks)
      inputs.rejected.contains(t.id) ? t.copyWith(lastSkippedAt: null) : t,
  ];
  return pickerEngine
      .rank(unpenalized, _context(inputs, now, ref.watch(calibrationProvider)))
      .take(3)
      .toList();
});

/// Overwhelm mode suggestion. Ignores the time limit: any task is fair
/// game for five minutes.
final tinySuggestionProvider = Provider<Suggestion?>((ref) {
  ref.watch(pickerTickProvider);
  final inputs = ref.watch(pickerInputsProvider);
  return pickerEngine.pickTiny(
    ref.watch(tasksProvider),
    _context(inputs.copyWith(availableMin: 5), ref.read(clockProvider)()),
  );
});
