import 'package:farm_fintech/config/constants.dart';

enum QuestType { harvest, cash }
enum QuestStatus { active, completed, failed }

class Quest {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final double goalAmount; // Quantity for harvest, cash amount for cash
  final CropType? targetCrop;
  final int startDay;
  final int durationDays;
  final double cost; // Payment to accept the quest
  final double reward; // Cash reward on completion
  QuestStatus status;
  double currentProgress;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.goalAmount,
    this.targetCrop,
    required this.startDay,
    required this.durationDays,
    required this.cost,
    required this.reward,
    this.status = QuestStatus.active,
    this.currentProgress = 0,
  });

  int get endDay => startDay + durationDays;
  bool get isExpired => false; // Logic handled by GameState

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'goalAmount': goalAmount,
    'targetCrop': targetCrop?.name,
    'startDay': startDay,
    'durationDays': durationDays,
    'cost': cost,
    'reward': reward,
    'status': status.name,
    'currentProgress': currentProgress,
  };

  factory Quest.fromMap(Map<String, dynamic> map) => Quest(
    id: map['id'] as String,
    title: map['title'] as String? ?? 'Lyra\'s Challenge',
    description: map['description'] as String? ?? '',
    type: QuestType.values.byName(map['type'] as String? ?? 'harvest'),
    goalAmount: (map['goalAmount'] as num?)?.toDouble() ?? 0.0,
    targetCrop: map['targetCrop'] != null ? CropType.values.byName(map['targetCrop'] as String) : null,
    startDay: map['startDay'] as int? ?? 1,
    durationDays: map['durationDays'] as int? ?? 3,
    cost: (map['cost'] as num?)?.toDouble() ?? 100.0,
    reward: (map['reward'] as num?)?.toDouble() ?? 500.0,
    status: QuestStatus.values.byName(map['status'] as String? ?? 'active'),
    currentProgress: (map['currentProgress'] as num?)?.toDouble() ?? 0.0,
  );
}
