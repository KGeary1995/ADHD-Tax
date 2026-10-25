import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_themes.dart';
import '../../data/models/reward.dart';
import '../../widgets/task_chips.dart';
import '../../widgets/ui.dart';
import 'progress_controller.dart';
import 'rewards_controller.dart';
import '../../core/theme/ph.dart';

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

    // The cheapest treat you can have now gets the gold button.
    final firstAffordable = rewards
        .where((r) => r.cost <= coins)
        .fold<Reward?>(null, (a, r) => a == null || r.cost < a.cost ? r : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text('Reward shop', style: s.display(19))),
            Text(
              '$coins ${coins == 1 ? 'coin' : 'coins'}',
              style: s.caption(color: s.ink2),
            ),
          ],
        ),
        const SizedBox(height: Gap.s1),
        Text('Treats you chose. Spend coins guilt-free.', style: s.caption()),
        const SizedBox(height: Gap.s4),
        for (final r in rewards)
          _RewardRow(
            reward: r,
            coins: coins,
            primary: identical(r, firstAffordable),
            key: ValueKey(r.id),
          ),
        if (rewards.isEmpty) ...[
          const SizedBox(height: Gap.s4),
          const OptionLabel('Ideas to start with'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (name, cost) in rewardIdeas)
                Pill(
                  label: '$name · $cost',
                  icon: Ph.plus,
                  selected: false,
                  onTap: () => shop.create(name, cost),
                ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => showRewardDialog(context, ref),
            icon: const Icon(Ph.plus, size: 16),
            label: const Text('Add a reward'),
          ),
        ),
        if (history.isNotEmpty)
          Text(
            'Last treat: ${history.first.label}, '
            '${formatDate(history.first.at)}',
            style: s.caption(),
          ),
      ],
    );
  }
}

class _RewardRow extends ConsumerWidget {
  const _RewardRow({
    super.key,
    required this.reward,
    required this.coins,
    this.primary = false,
  });
  final Reward reward;
  final int coins;
  final bool primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spec;
    final short = reward.cost - coins;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: s.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onLongPress: () =>
                  showRewardDialog(context, ref, editing: reward),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reward.name, style: s.body(weight: FontWeight.w700)),
                  Text('${reward.cost} coins', style: s.caption()),
                ],
              ),
            ),
          ),
          const SizedBox(width: Gap.s4),
          if (short > 0)
            Text(
              '$short to go',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: s.ink3,
              ),
            )
          else if (primary)
            PrimaryButton(
              label: 'Redeem',
              height: 40,
              fontSize: 14,
              expand: false,
              onPressed: () => _redeem(context, ref),
            )
          else
            OutlineButton(
              label: 'Redeem',
              height: 40,
              fontSize: 14,
              onPressed: () => _redeem(context, ref),
            ),
          PopupMenuButton<String>(
            useRootNavigator: true,
            tooltip: 'Reward options',
            icon: Icon(Ph.dotsThreeVertical, size: 18, color: s.ink3),
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

  Future<void> _redeem(BuildContext context, WidgetRef ref) async {
    final shop = ref.read(rewardsProvider.notifier);
    final e = shop.redeem(reward);
    if (e == null) return;
    HapticFeedback.mediumImpact();
    final left = ref.read(progressProvider).coins;
    final undo = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final s = ctx.spec;
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: s.star,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: s.glow, blurRadius: 22)],
                      ),
                      child: Icon(Ph.giftFill, size: 30, color: s.onStar),
                    ),
                  ),
                  const SizedBox(height: Gap.s7),
                  Text(
                    'Enjoy it.',
                    textAlign: TextAlign.center,
                    style: s.display(26),
                  ),
                  const SizedBox(height: Gap.s3),
                  Text(
                    '${reward.name}. You earned it, no strings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.4, color: s.ink2),
                  ),
                  const SizedBox(height: Gap.s2),
                  Text(
                    '−${reward.cost} coins · $left left',
                    textAlign: TextAlign.center,
                    style: s.caption(),
                  ),
                  const SizedBox(height: Gap.s7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: OutlineButton(
                          label: 'Undo',
                          fontSize: 16,
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ),
                      const SizedBox(width: Gap.s4),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Thanks',
                          fontSize: 16,
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (undo == true) shop.unredeem(e);
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
