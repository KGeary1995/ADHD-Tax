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
  });

  final int availableMin;
  final bool willingToLeave;
  final Energy? energy;
  final Set<Workspace> workspaces;

  /// Tasks passed on with "Not this one" during this session.
  final Set<String> rejected;

  /// After two rerolls we stop rerolling and ask the user to commit.
  bool get shouldCommit => rejected.length >= 2;

  PickerInputs copyWith({
    int? availableMin,
    bool? willingToLeave,
    Energy? Function()? energy,
    Set<Workspace>? workspaces,
    Set<String>? rejected,
  }) => PickerInputs(
    availableMin: availableMin ?? this.availableMin,
    willingToLeave: willingToLeave ?? this.willingToLeave,
    energy: energy != null ? energy() : this.energy,
    workspaces: workspaces ?? this.workspaces,
    rejected: rejected ?? this.rejected,
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
    state = state.copyWith(rejected: {...state.rejected, taskId});
  }

  void resetRejections() => state = state.copyWith(rejected: const {});
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

/// The one task the dashboard shows.
final pickResultProvider = Provider<PickResult>((ref) {
  final tasks = ref.watch(tasksProvider);
  final inputs = ref.watch(pickerInputsProvider);
  final now = ref.read(clockProvider)();
  final ctx = _context(inputs, now, ref.watch(calibrationProvider));
  // Chosen in last night's wrap-up: first, until done or passed on.
  final pinnedId = ref.watch(settingsProvider.select((s) => s.pinnedFor(now)));
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
        reasons: const ['You chose this last night'],
      ),
    );
  }
  return pickerEngine.pick(tasks, ctx, exclude: inputs.rejected);
});

/// What else would fit right now, best first, for the large home-screen
/// widget's "Next up" list.
final nextUpProvider = Provider<List<Suggestion>>((ref) {
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
  final inputs = ref.watch(pickerInputsProvider);
  return pickerEngine.pickTiny(
    ref.watch(tasksProvider),
    _context(inputs.copyWith(availableMin: 5), ref.read(clockProvider)()),
  );
});
