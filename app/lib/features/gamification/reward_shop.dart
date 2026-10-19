import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/reward.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import 'progress_controller.dart';
import 'rewards_controller.dart';

/// Progress → Reward shop: treats the user picks, bought with coins.
class RewardShop extends ConsumerWidget {
  const RewardShop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final coins = ref.watch(progressProvider.select((p) => p.coins));
    final rewards = ref.watch(rewardsProvider);
    final history = ref.watch(redemptionsProvider);
    final shop = ref.read(rewardsProvider.notifier);

    return Panel(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text('Reward shop', style: s.display(24)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.toll_rounded, size: 18, color: s.primary),
                    const SizedBox(width: 6),
                    Text(
                      '$coins ${coins == 1 ? 'coin' : 'coins'}',
                      style: s.mono(15, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              'Starting and finishing tasks earns coins. Spend them on '
              'treats you choose, guilt-free.',
              style: TextStyle(color: s.muted, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          for (final r in rewards)
            _RewardRow(reward: r, coins: coins, key: ValueKey(r.id)),
          if (rewards.isEmpty) ...[
            const SizedBox(height: 8),
            const FieldLabel('Ideas to start with'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (name, cost) in rewardIdeas)
                  Pill(
                    label: '$name · $cost',
                    icon: Icons.add_rounded,
                    selected: false,
                    onTap: () => shop.create(name, cost),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showRewardDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a reward'),
            ),
          ),
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
              child: Text(
                'Last treat: ${history.first.label}, '
                '${formatDate(history.first.at)}',
                style: TextStyle(color: s.muted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardRow extends ConsumerWidget {
  const _RewardRow({super.key, required this.reward, required this.coins});
  final Reward reward;
  final int coins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final short = reward.cost - coins;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.name,
                  style: TextStyle(fontSize: 16, color: s.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  short > 0
                      ? '${reward.cost} coins · $short to go'
                      : '${reward.cost} coins',
                  style: s.mono(12, color: s.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: short > 0 ? null : () => _redeem(context, ref),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Redeem'),
          ),
          PopupMenuButton<String>(
            useRootNavigator: true,
            tooltip: 'Reward options',
            icon: Icon(Icons.more_vert_rounded, color: s.muted),
            onSelected: (v) => v == 'edit'
                ? showRewardDialog(context, ref, editing: reward)
                : ref.read(rewardsProvider.notifier).delete(reward),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  void _redeem(BuildContext context, WidgetRef ref) {
    final shop = ref.read(rewardsProvider.notifier);
    final e = shop.redeem(reward);
    if (e == null) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Enjoy it: ${reward.name}. You earned it.'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => shop.unredeem(e),
          ),
        ),
      );
  }
}

/// Adds a reward, or edits [editing].
Future<void> showRewardDialog(
  BuildContext context,
  WidgetRef ref, {
  Reward? editing,
}) async {
  final name = TextEditingController(text: editing?.name ?? '');
  final cost = TextEditingController(text: '${editing?.cost ?? 25}');
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(editing == null ? 'New reward' : 'Edit reward'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reward',
              hintText: 'e.g. 30 minutes of games',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cost,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Price',
              suffixText: 'coins',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  final n = name.text.trim();
  final c = int.tryParse(cost.text) ?? 0;
  if (saved != true || n.isEmpty || c < 1) return;
  final shop = ref.read(rewardsProvider.notifier);
  if (editing == null) {
    shop.create(n, c);
  } else {
    shop.save(editing.copyWith(name: n, cost: c));
  }
}
