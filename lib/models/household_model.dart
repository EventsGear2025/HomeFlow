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
  final String managerInviteCode;
  final String homeownerInviteCode;
  final String? deliveryAddress;
  final String? deliveryContactName;
  final String? deliveryPhone;
  final String? deliverySmsNotes;
  final String? supermarketDeliveryNotes;
  final DateTime createdAt;
  final DateTime? planExpiresAt;

  HouseholdModel({
    required this.id,
    required this.householdName,
    required this.createdBy,
    this.planType = PlanType.free,
    this.planStatus = PlanStatus.active,
    required this.managerInviteCode,
    this.homeownerInviteCode = '',
    this.deliveryAddress,
    this.deliveryContactName,
    this.deliveryPhone,
    this.deliverySmsNotes,
    this.supermarketDeliveryNotes,
    required this.createdAt,
    this.planExpiresAt,
  });

  bool get isHomePro =>
      planType == PlanType.homePro &&
      planStatus != PlanStatus.expired &&
      planStatus != PlanStatus.cancelled;

  // Backward-compatible alias used across the existing UI for the
  // manager/staff invite code.
  String get ownerInviteCode => managerInviteCode;

  String get planLabel => isHomePro ? 'Home Pro' : 'Free';
  String get planStatusLabel => householdPlanStatusLabel(planStatus);

  Map<String, dynamic> toJson() => {
    'id': id,
    'householdName': householdName,
    'createdBy': createdBy,
    'planType': planType.name,
    'planStatus': planStatus.name,
    'managerInviteCode': managerInviteCode,
    'ownerInviteCode': managerInviteCode,
    'homeownerInviteCode': homeownerInviteCode,
    if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
    if (deliveryContactName != null)
      'deliveryContactName': deliveryContactName,
    if (deliveryPhone != null) 'deliveryPhone': deliveryPhone,
    if (deliverySmsNotes != null) 'deliverySmsNotes': deliverySmsNotes,
    if (supermarketDeliveryNotes != null)
      'supermarketDeliveryNotes': supermarketDeliveryNotes,
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
    managerInviteCode:
      json['managerInviteCode'] ?? json['ownerInviteCode'] ?? '',
    homeownerInviteCode: json['homeownerInviteCode'] ?? '',
    deliveryAddress: json['deliveryAddress'] as String?,
    deliveryContactName: json['deliveryContactName'] as String?,
    deliveryPhone: json['deliveryPhone'] as String?,
    deliverySmsNotes: json['deliverySmsNotes'] as String?,
    supermarketDeliveryNotes:
      json['supermarketDeliveryNotes'] as String?,
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
        managerInviteCode: row['invite_code']?.toString() ?? '',
        homeownerInviteCode:
          row['homeowner_invite_code']?.toString() ?? '',
        deliveryAddress:
          row['delivery_address']?.toString() ?? row['address']?.toString(),
        deliveryContactName: row['delivery_contact_name']?.toString(),
        deliveryPhone: row['delivery_phone']?.toString(),
        deliverySmsNotes: row['delivery_sms_notes']?.toString(),
        supermarketDeliveryNotes:
          row['supermarket_delivery_notes']?.toString(),
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
    String? managerInviteCode,
    String? homeownerInviteCode,
    String? deliveryAddress,
    String? deliveryContactName,
    String? deliveryPhone,
    String? deliverySmsNotes,
    String? supermarketDeliveryNotes,
    DateTime? planExpiresAt,
    bool clearDeliveryAddress = false,
    bool clearDeliveryContactName = false,
    bool clearDeliveryPhone = false,
    bool clearDeliverySmsNotes = false,
    bool clearSupermarketDeliveryNotes = false,
    bool clearExpiry = false,
  }) => HouseholdModel(
    id: id,
    householdName: householdName ?? this.householdName,
    createdBy: createdBy,
    planType: planType ?? this.planType,
    planStatus: planStatus ?? this.planStatus,
    managerInviteCode: managerInviteCode ?? this.managerInviteCode,
    homeownerInviteCode:
      homeownerInviteCode ?? this.homeownerInviteCode,
    deliveryAddress:
      clearDeliveryAddress ? null : (deliveryAddress ?? this.deliveryAddress),
    deliveryContactName: clearDeliveryContactName
      ? null
      : (deliveryContactName ?? this.deliveryContactName),
    deliveryPhone:
      clearDeliveryPhone ? null : (deliveryPhone ?? this.deliveryPhone),
    deliverySmsNotes: clearDeliverySmsNotes
      ? null
      : (deliverySmsNotes ?? this.deliverySmsNotes),
    supermarketDeliveryNotes: clearSupermarketDeliveryNotes
      ? null
      : (supermarketDeliveryNotes ?? this.supermarketDeliveryNotes),
    createdAt: createdAt,
    planExpiresAt: clearExpiry ? null : (planExpiresAt ?? this.planExpiresAt),
  );
}
