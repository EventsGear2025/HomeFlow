class MealTimetableEntry {
  final String id;
  final String householdId;

  /// The Monday of the week this entry belongs to, formatted 'yyyy-MM-dd'.
  final String weekKey;

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  final int dayOfWeek;

  /// Matches one of AppConstants.mealPeriods.
  final String mealPeriod;

  /// One or more dishes / items planned for this meal slot.
  final List<String> mealItems;

  /// Joined label for display (e.g. "Ugali, Eggs, Tea").
  String get mealLabel => mealItems.join(', ');

  /// Optional extra notes (dietary requirements, reminders, etc.)
  final String? notes;

  final DateTime createdAt;

  const MealTimetableEntry({
    required this.id,
    required this.householdId,
    required this.weekKey,
    required this.dayOfWeek,
    required this.mealPeriod,
    required this.mealItems,
    this.notes,
    required this.createdAt,
  });

  MealTimetableEntry copyWith({
    List<String>? mealItems,
    String? notes,
  }) =>
      MealTimetableEntry(
        id: id,
        householdId: householdId,
        weekKey: weekKey,
        dayOfWeek: dayOfWeek,
        mealPeriod: mealPeriod,
        mealItems: mealItems ?? this.mealItems,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'weekKey': weekKey,
        'dayOfWeek': dayOfWeek,
        'mealPeriod': mealPeriod,
        'mealItems': mealItems,
        'mealLabel': mealLabel, // kept for display on older clients
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MealTimetableEntry.fromJson(Map<String, dynamic> j) {
    // Support both the new list format and the old single-string format.
    final List<String> items;
    if (j['mealItems'] != null) {
      items = (j['mealItems'] as List).cast<String>();
    } else {
      items = [(j['mealLabel'] as String)];
    }
    return MealTimetableEntry(
      id: j['id'] as String,
      householdId: j['householdId'] as String,
      weekKey: j['weekKey'] as String,
      dayOfWeek: j['dayOfWeek'] as int,
      mealPeriod: j['mealPeriod'] as String,
      mealItems: items,
      notes: j['notes'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}
