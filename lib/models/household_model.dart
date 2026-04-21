enum PlanType { free, homePro }

enum PlanStatus { active, gracePeriod, expired, cancelled }

String householdPlanStatusLabel(PlanStatus status) {
  switch (status) {
    case PlanStatus.gracePeriod:
      return 'Grace period';
    case PlanStatus.expired:
      return 'Expired';
    case PlanStatus.cancelled:
      return 'Cancelled';
    case PlanStatus.active:
      return 'Active';
  }
}

class HouseholdModel {
  final String id;
  final String householdName;
  final String createdBy;
  final PlanType planType;
  final PlanStatus planStatus;
  final String ownerInviteCode;
  final DateTime createdAt;
  final DateTime? planExpiresAt;

  HouseholdModel({
    required this.id,
    required this.householdName,
    required this.createdBy,
    this.planType = PlanType.free,
    this.planStatus = PlanStatus.active,
    required this.ownerInviteCode,
    required this.createdAt,
    this.planExpiresAt,
  });

  bool get isHomePro =>
      planType == PlanType.homePro &&
      planStatus != PlanStatus.expired &&
      planStatus != PlanStatus.cancelled;

  String get planLabel => isHomePro ? 'Home Pro' : 'Free';
  String get planStatusLabel => householdPlanStatusLabel(planStatus);

  Map<String, dynamic> toJson() => {
    'id': id,
    'householdName': householdName,
    'createdBy': createdBy,
    'planType': planType.name,
    'planStatus': planStatus.name,
    'ownerInviteCode': ownerInviteCode,
    'createdAt': createdAt.toIso8601String(),
    if (planExpiresAt != null)
      'planExpiresAt': planExpiresAt!.toIso8601String(),
  };

  factory HouseholdModel.fromJson(Map<String, dynamic> json) => HouseholdModel(
    id: json['id'],
    householdName: json['householdName'],
    createdBy: json['createdBy'],
    planType: _parsePlanType(json['planType']),
    planStatus: _parsePlanStatus(json['planStatus']),
    ownerInviteCode: json['ownerInviteCode'] ?? '',
    createdAt: DateTime.parse(json['createdAt']),
    planExpiresAt: json['planExpiresAt'] != null
        ? DateTime.tryParse(json['planExpiresAt'])
        : null,
  );

  /// Build a HouseholdModel from a Supabase `app_households` row.
  /// Column names in that table are snake_case.
  factory HouseholdModel.fromSupabaseRow(Map<String, dynamic> row) =>
      HouseholdModel(
        id: row['id']?.toString() ?? '',
        householdName: row['household_name']?.toString() ?? '',
        createdBy: row['owner_user_id']?.toString() ?? '',
        planType: _parsePlanType(row['plan_code']),
        planStatus: _parsePlanStatus(row['plan_status']),
        ownerInviteCode: row['invite_code']?.toString() ?? '',
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        planExpiresAt: row['plan_expires_at'] != null
            ? DateTime.tryParse(row['plan_expires_at'].toString())
            : null,
      );

  static PlanType _parsePlanType(dynamic raw) {
    switch (raw?.toString()) {
      case 'homePro':
      case 'home_pro':
      case 'plus':
      case 'gold':
        return PlanType.homePro;
      case 'basic':
      default:
        return PlanType.free;
    }
  }

  static PlanStatus _parsePlanStatus(dynamic raw) {
    switch (raw?.toString()) {
      case 'gracePeriod':
      case 'grace_period':
        return PlanStatus.gracePeriod;
      case 'expired':
        return PlanStatus.expired;
      case 'cancelled':
      case 'canceled':
        return PlanStatus.cancelled;
      default:
        return PlanStatus.active;
    }
  }

  HouseholdModel copyWith({
    String? householdName,
    PlanType? planType,
    PlanStatus? planStatus,
    String? ownerInviteCode,
    DateTime? planExpiresAt,
    bool clearExpiry = false,
  }) => HouseholdModel(
    id: id,
    householdName: householdName ?? this.householdName,
    createdBy: createdBy,
    planType: planType ?? this.planType,
    planStatus: planStatus ?? this.planStatus,
    ownerInviteCode: ownerInviteCode ?? this.ownerInviteCode,
    createdAt: createdAt,
    planExpiresAt: clearExpiry ? null : (planExpiresAt ?? this.planExpiresAt),
  );
}
