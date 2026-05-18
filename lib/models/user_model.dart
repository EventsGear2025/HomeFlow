enum UserRole { owner, houseManager }

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String householdId;
  final DateTime createdAt;

  // Manager-profile fields (owner-editable, stored in app_household_members)
  final String? idNumber;
  final DateTime? startDate;
  final int leaveDaysTotal;
  final int leaveDaysTaken;
  final String? managerNotes;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.householdId,
    DateTime? createdAt,
    this.idNumber,
    this.startDate,
    this.leaveDaysTotal = 21,
    this.leaveDaysTaken = 0,
    this.managerNotes,
  }) : createdAt = createdAt ?? DateTime.now();

  int get leaveDaysRemaining => leaveDaysTotal - leaveDaysTaken;

  bool get isOwner => role == UserRole.owner;
  bool get isHouseManager => role == UserRole.houseManager;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role.name,
        'householdId': householdId,
        'createdAt': createdAt.toIso8601String(),
        if (idNumber != null) 'idNumber': idNumber,
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        'leaveDaysTotal': leaveDaysTotal,
        'leaveDaysTaken': leaveDaysTaken,
        if (managerNotes != null) 'managerNotes': managerNotes,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        fullName: json['fullName'],
        email: json['email'],
        role: UserRole.values.firstWhere((r) => r.name == json['role']),
        householdId: json['householdId'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        idNumber: json['idNumber'] as String?,
        startDate: json['startDate'] != null
            ? DateTime.parse(json['startDate'])
            : null,
        leaveDaysTotal: json['leaveDaysTotal'] as int? ?? 21,
        leaveDaysTaken: json['leaveDaysTaken'] as int? ?? 0,
        managerNotes: json['managerNotes'] as String?,
      );

  UserModel copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    String? householdId,
    String? idNumber,
    DateTime? startDate,
    int? leaveDaysTotal,
    int? leaveDaysTaken,
    String? managerNotes,
  }) =>
      UserModel(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        role: role ?? this.role,
        householdId: householdId ?? this.householdId,
        createdAt: createdAt,
        idNumber: idNumber ?? this.idNumber,
        startDate: startDate ?? this.startDate,
        leaveDaysTotal: leaveDaysTotal ?? this.leaveDaysTotal,
        leaveDaysTaken: leaveDaysTaken ?? this.leaveDaysTaken,
        managerNotes: managerNotes ?? this.managerNotes,
      );
}
