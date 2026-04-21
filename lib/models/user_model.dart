enum UserRole { owner, houseManager }

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String householdId;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.householdId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOwner => role == UserRole.owner;
  bool get isHouseManager => role == UserRole.houseManager;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role.name,
        'householdId': householdId,
        'createdAt': createdAt.toIso8601String(),
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
      );

  UserModel copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    String? householdId,
  }) =>
      UserModel(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        role: role ?? this.role,
        householdId: householdId ?? this.householdId,
        createdAt: createdAt,
      );
}
