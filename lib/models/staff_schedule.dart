enum WorkStatus { onDuty, offDay, onLeave, sick, away }

class StaffSchedule {
  final String id;
  final String householdId;
  final String userId;
  final String userName;
  final WorkStatus workStatus;
  final DateTime? leaveStartDate;
  final DateTime? leaveEndDate;
  final String? recurringOffDay;
  final bool replacementArranged;
  final String? notes;
  final DateTime updatedAt;

  StaffSchedule({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.userName,
    required this.workStatus,
    this.leaveStartDate,
    this.leaveEndDate,
    this.recurringOffDay,
    this.replacementArranged = false,
    this.notes,
    required this.updatedAt,
  });

  bool get isOnDuty => workStatus == WorkStatus.onDuty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'userId': userId,
        'userName': userName,
        'workStatus': workStatus.name,
        'leaveStartDate': leaveStartDate?.toIso8601String(),
        'leaveEndDate': leaveEndDate?.toIso8601String(),
        'recurringOffDay': recurringOffDay,
        'replacementArranged': replacementArranged,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StaffSchedule.fromJson(Map<String, dynamic> json) => StaffSchedule(
        id: json['id'],
        householdId: json['householdId'],
        userId: json['userId'],
        userName: json['userName'],
        workStatus: WorkStatus.values
            .firstWhere((w) => w.name == json['workStatus'],
                orElse: () => WorkStatus.onDuty),
        leaveStartDate: json['leaveStartDate'] != null
            ? DateTime.parse(json['leaveStartDate'])
            : null,
        leaveEndDate: json['leaveEndDate'] != null
            ? DateTime.parse(json['leaveEndDate'])
            : null,
        recurringOffDay: json['recurringOffDay'],
        replacementArranged: json['replacementArranged'] ?? false,
        notes: json['notes'],
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  StaffSchedule copyWith({
    WorkStatus? workStatus,
    DateTime? leaveStartDate,
    DateTime? leaveEndDate,
    bool? replacementArranged,
    String? notes,
  }) =>
      StaffSchedule(
        id: id,
        householdId: householdId,
        userId: userId,
        userName: userName,
        workStatus: workStatus ?? this.workStatus,
        leaveStartDate: leaveStartDate ?? this.leaveStartDate,
        leaveEndDate: leaveEndDate ?? this.leaveEndDate,
        recurringOffDay: recurringOffDay,
        replacementArranged: replacementArranged ?? this.replacementArranged,
        notes: notes ?? this.notes,
        updatedAt: DateTime.now(),
      );
}
