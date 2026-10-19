import 'task.dart' show Workspace;

/// Something the user buys with coins: "Fancy coffee", 30.
///
/// Stored like notes: one replica record each, every field a JSON scalar.
/// Spending is a separate XP event with negative coins (see
/// `ProgressKind.redeemed`), never an edit to the balance. Pure Dart.
class Reward {
  const Reward({
    required this.id,
    required this.name,
    required this.cost,
    required this.createdAt,
    this.workspace = Workspace.personal,
  });

  final String id;
  final String name;

  /// Price in coins, at least 1.
  final int cost;
  final Workspace workspace;
  final DateTime createdAt;

  Reward copyWith({String? name, int? cost}) => Reward(
    id: id,
    name: name ?? this.name,
    cost: cost ?? this.cost,
    workspace: workspace,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'cost': cost,
    'workspace': workspace.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Reward.fromJson(Map<String, Object?> j) => Reward(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    cost: ((j['cost'] as num?)?.toInt() ?? 1).clamp(1, 1000000),
    workspace:
        Workspace.values.asNameMap()[j['workspace']] ?? Workspace.personal,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Ideas shown while the shop is empty. Starting and finishing a
/// 15-minute task earns about 2 coins.
const rewardIdeas = [
  ('An episode, guilt-free', 10),
  ('Fancy coffee out', 25),
  ('Order takeout', 50),
  ('Something from the wishlist', 120),
];
