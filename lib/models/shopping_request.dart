enum ShoppingUrgency { neededSoon, neededToday, critical }
enum ShoppingStatus { requested, seen, approved, purchased, deferred }

/// Who originated this entry and through what flow.
/// - managerRequest  : manager noticed low stock → awaits owner approval
/// - ownerPurchase   : owner adding to their own personal buy list (no approval needed)
/// - managerDirectBuy: manager bought something immediately (emergency / small item)
enum PurchaseType { managerRequest, ownerPurchase, managerDirectBuy }

class ShoppingRequest {
  final String id;
  final String householdId;
  final String? supplyItemId;
  final String itemName;
  final String quantity;
  final String category;
  final ShoppingUrgency urgency;
  final String? notes;
  final ShoppingStatus status;
  final PurchaseType purchaseType;
  final bool autoApproved;
  final String? autoApproveReason; // e.g. "Owner did not respond within 4 hours"
  final String? buyAnywayReason;   // set when manager uses "Buy Anyway" override
  final String requestedByUserId;
  final String requestedByName;
  final String? approvedByUserId;
  final DateTime requestedAt;
  final DateTime updatedAt;
  /// Exact catalog product matched via suggestion chip at add time.
  final String? catalogProductName;
  final String? catalogBrand;
  final String? catalogSizeLabel;

  /// Price paid when marking the item as purchased (optional).
  final double? pricePaid;

  ShoppingRequest({
    required this.id,
    required this.householdId,
    this.supplyItemId,
    required this.itemName,
    required this.quantity,
    required this.category,
    required this.urgency,
    this.notes,
    this.status = ShoppingStatus.requested,
    this.purchaseType = PurchaseType.managerRequest,
    this.autoApproved = false,
    this.autoApproveReason,
    this.buyAnywayReason,
    required this.requestedByUserId,
    required this.requestedByName,
    this.approvedByUserId,
    required this.requestedAt,
    required this.updatedAt,
    this.catalogProductName,
    this.catalogBrand,
    this.catalogSizeLabel,
    this.pricePaid,
  });

  /// True if this was a manager request that needed (or still needs) approval.
  bool get needsApproval =>
      purchaseType == PurchaseType.managerRequest &&
      (status == ShoppingStatus.requested || status == ShoppingStatus.seen);

  /// True if this is in the owner's personal buy list.
  bool get isOwnerPurchase => purchaseType == PurchaseType.ownerPurchase;

  /// True if the manager bypassed the normal approval flow.
  bool get wasBuyAnyway =>
      purchaseType == PurchaseType.managerDirectBuy && buyAnywayReason != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'supplyItemId': supplyItemId,
        'itemName': itemName,
        'quantity': quantity,
        'category': category,
        'urgency': urgency.name,
        'notes': notes,
        'status': status.name,
        'purchaseType': purchaseType.name,
        'autoApproved': autoApproved,
        'autoApproveReason': autoApproveReason,
        'buyAnywayReason': buyAnywayReason,
        'requestedByUserId': requestedByUserId,
        'requestedByName': requestedByName,
        'approvedByUserId': approvedByUserId,
        'requestedAt': requestedAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (catalogProductName != null) 'catalogProductName': catalogProductName,
        if (catalogBrand != null) 'catalogBrand': catalogBrand,
        if (catalogSizeLabel != null) 'catalogSizeLabel': catalogSizeLabel,
        if (pricePaid != null) 'pricePaid': pricePaid,
      };

  factory ShoppingRequest.fromJson(Map<String, dynamic> json) =>
      ShoppingRequest(
        id: json['id'],
        householdId: json['householdId'],
        supplyItemId: json['supplyItemId'],
        itemName: json['itemName'],
        quantity: json['quantity'],
        category: json['category'],
        urgency: ShoppingUrgency.values
            .firstWhere((u) => u.name == json['urgency'],
                orElse: () => ShoppingUrgency.neededSoon),
        notes: json['notes'],
        status: ShoppingStatus.values
            .firstWhere((s) => s.name == json['status'],
                orElse: () => ShoppingStatus.requested),
        purchaseType: PurchaseType.values
            .firstWhere((p) => p.name == (json['purchaseType'] ?? ''),
                orElse: () => PurchaseType.managerRequest),
        autoApproved: json['autoApproved'] as bool? ?? false,
        autoApproveReason: json['autoApproveReason'],
        buyAnywayReason: json['buyAnywayReason'],
        requestedByUserId: json['requestedByUserId'],
        requestedByName: json['requestedByName'],
        approvedByUserId: json['approvedByUserId'],
        requestedAt: DateTime.parse(json['requestedAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        catalogProductName: json['catalogProductName'],
        catalogBrand: json['catalogBrand'],
        catalogSizeLabel: json['catalogSizeLabel'],
        pricePaid: (json['pricePaid'] as num?)?.toDouble(),
      );

  ShoppingRequest copyWith({
    String? itemName,
    String? quantity,
    String? notes,
    ShoppingStatus? status,
    String? approvedByUserId,
    bool? autoApproved,
    String? autoApproveReason,
    double? pricePaid,
  }) =>
      ShoppingRequest(
        id: id,
        householdId: householdId,
        supplyItemId: supplyItemId,
        itemName: itemName ?? this.itemName,
        quantity: quantity ?? this.quantity,
        category: category,
        urgency: urgency,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        purchaseType: purchaseType,
        autoApproved: autoApproved ?? this.autoApproved,
        autoApproveReason: autoApproveReason ?? this.autoApproveReason,
        buyAnywayReason: buyAnywayReason,
        requestedByUserId: requestedByUserId,
        requestedByName: requestedByName,
        approvedByUserId: approvedByUserId ?? this.approvedByUserId,
        requestedAt: requestedAt,
        updatedAt: DateTime.now(),
        catalogProductName: catalogProductName,
        catalogBrand: catalogBrand,
        catalogSizeLabel: catalogSizeLabel,
        pricePaid: pricePaid ?? this.pricePaid,
      );
}
