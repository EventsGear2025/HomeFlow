class TaskItem {
  final String id;
  final String householdId;
  final String title;
  final bool isDone;

  /// 'owner' or 'manager'
  final String addedBy;

  /// 'yyyy-MM-dd' — the calendar day this task belongs to
  final String dateKey;

  final DateTime createdAt;

  TaskItem({
    required this.id,
    required this.householdId,
    required this.title,
    this.isDone = false,
    required this.addedBy,
    required this.dateKey,
    required this.createdAt,
  });

  TaskItem copyWith({String? title, bool? isDone}) => TaskItem(
        id: id,
        householdId: householdId,
        title: title ?? this.title,
        isDone: isDone ?? this.isDone,
        addedBy: addedBy,
        dateKey: dateKey,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'title': title,
        'isDone': isDone,
        'addedBy': addedBy,
        'dateKey': dateKey,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        householdId: j['householdId'] as String,
        title: j['title'] as String,
        isDone: j['isDone'] as bool? ?? false,
        addedBy: j['addedBy'] as String? ?? 'owner',
        dateKey: j['dateKey'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// Default recurring tasks seeded on the first time a new day starts
const List<String> kDefaultDailyTasks = [
  'Morning cleaning',
  'Prepare breakfast',
  'Check supply levels',
  'Do laundry',
  'Prepare lunch',
  'Prepare dinner',
  'End of day tidy-up',
];
