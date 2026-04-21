enum LaundryStage { washing, drying, folded, stored }

const List<String> bedroomOptions = [
  'Whole House',
  'Bedroom 1',
  'Bedroom 2',
  'Bedroom 3',
  'Bedroom 4',
  'Master Bedroom',
  'Staff Bedroom',
];

class LaundryItem {
  final String id;
  final String householdId;
  final String bedroom;
  final int numberOfLoads;
  final LaundryStage stage;
  final String? notes;
  final String createdByUserId;
  /// When this laundry batch was started (washing begun).
  final DateTime createdAt;
  /// When the batch was fully stored (null until stored).
  final DateTime? storedAt;
  final DateTime updatedAt;

  LaundryItem({
    required this.id,
    required this.householdId,
    required this.bedroom,
    required this.numberOfLoads,
    required this.stage,
    this.notes,
    required this.createdByUserId,
    DateTime? createdAt,
    this.storedAt,
    required this.updatedAt,
  }) : createdAt = createdAt ?? updatedAt;

  bool get isStored => stage == LaundryStage.stored;

  /// Returns the next stage in the workflow, or null if already stored.
  LaundryStage? get nextStage {
    final idx = LaundryStage.values.indexOf(stage);
    if (idx >= LaundryStage.values.length - 1) return null;
    return LaundryStage.values[idx + 1];
  }

  /// How long this batch has been in progress (since createdAt).
  Duration get age => DateTime.now().difference(createdAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'bedroom': bedroom,
        'numberOfLoads': numberOfLoads,
        'stage': stage.name,
        'notes': notes,
        'createdByUserId': createdByUserId,
        'createdAt': createdAt.toIso8601String(),
        'storedAt': storedAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory LaundryItem.fromJson(Map<String, dynamic> json) => LaundryItem(
        id: json['id'],
        householdId: json['householdId'],
        bedroom: json['bedroom'] ?? json['category'] ?? 'Bedroom 1',
        numberOfLoads: json['numberOfLoads'] ?? 1,
        stage: LaundryStage.values.firstWhere(
            (s) => s.name == json['stage'],
            orElse: () => LaundryStage.washing),
        notes: json['notes'],
        createdByUserId: json['createdByUserId'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.parse(json['updatedAt']),
        storedAt: json['storedAt'] != null
            ? DateTime.parse(json['storedAt'])
            : null,
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  LaundryItem copyWith({
    LaundryStage? stage,
    int? numberOfLoads,
    DateTime? storedAt,
  }) =>
      LaundryItem(
        id: id,
        householdId: householdId,
        bedroom: bedroom,
        numberOfLoads: numberOfLoads ?? this.numberOfLoads,
        stage: stage ?? this.stage,
        notes: notes,
        createdByUserId: createdByUserId,
        createdAt: createdAt,
        storedAt: storedAt ?? this.storedAt,
        updatedAt: DateTime.now(),
      );
}
