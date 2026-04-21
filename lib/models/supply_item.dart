enum SupplyStatus { enough, runningLow, veryLow, finished }

/// A single usage log entry for a supply item.
class SupplyUsageEntry {
  final DateTime date;
  final double quantity;
  final String? notes;
  /// Optional cost paid for this amount (e.g. KES spent on restock).
  final double? price;
  /// Name of the person who logged this entry.
  final String? loggedByName;

  SupplyUsageEntry({
    required this.date,
    required this.quantity,
    this.notes,
    this.price,
    this.loggedByName,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'quantity': quantity,
        'notes': notes,
        if (price != null) 'price': price,
        if (loggedByName != null) 'loggedByName': loggedByName,
      };

  factory SupplyUsageEntry.fromJson(Map<String, dynamic> json) =>
      SupplyUsageEntry(
        date: DateTime.parse(json['date']),
        quantity: (json['quantity'] as num).toDouble(),
        notes: json['notes'],
        price: json['price'] != null ? (json['price'] as num).toDouble() : null,
        loggedByName: json['loggedByName'],
      );
}

class SupplyItem {
  final String id;
  final String householdId;
  final String name;
  final String category;
  final String unitType;
  final SupplyStatus status;
  final String? preferredBrand;
  final String? notes;
  final DateTime? lastRestockedAt;
  final int? expectedDurationDays;
  final bool isGas;
  /// When true, this item is hidden from house managers — owner eyes only.
  final bool isOwnerOnly;
  /// Optional usage log entries (Home Pro analytics).
  final List<SupplyUsageEntry> usageLogs;
  /// When the status was last changed (shown on card).
  final DateTime? statusUpdatedAt;
  /// Name of the person who last changed the status.
  final String? statusUpdatedByName;

  SupplyItem({
    required this.id,
    required this.householdId,
    required this.name,
    required this.category,
    required this.unitType,
    this.status = SupplyStatus.enough,
    this.preferredBrand,
    this.notes,
    this.lastRestockedAt,
    this.expectedDurationDays,
    this.isGas = false,
    this.isOwnerOnly = false,
    this.usageLogs = const [],
    this.statusUpdatedAt,
    this.statusUpdatedByName,
  });

  bool get needsAttention =>
      status == SupplyStatus.runningLow ||
      status == SupplyStatus.veryLow ||
      status == SupplyStatus.finished;

  bool get isGasLowAlert {
    if (!isGas || lastRestockedAt == null || expectedDurationDays == null) {
      return false;
    }
    final daysSinceRefill =
        DateTime.now().difference(lastRestockedAt!).inDays;
    return daysSinceRefill >= (expectedDurationDays! - 7);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'name': name,
        'category': category,
        'unitType': unitType,
        'status': status.name,
        'preferredBrand': preferredBrand,
        'notes': notes,
        'lastRestockedAt': lastRestockedAt?.toIso8601String(),
        'expectedDurationDays': expectedDurationDays,
        'isGas': isGas,
        'isOwnerOnly': isOwnerOnly,
        'usageLogs': usageLogs.map((e) => e.toJson()).toList(),
        if (statusUpdatedAt != null)
          'statusUpdatedAt': statusUpdatedAt!.toIso8601String(),
        if (statusUpdatedByName != null)
          'statusUpdatedByName': statusUpdatedByName,
      };

  factory SupplyItem.fromJson(Map<String, dynamic> json) => SupplyItem(
        id: json['id'],
        householdId: json['householdId'],
        name: json['name'],
        category: json['category'],
        unitType: json['unitType'],
        status: SupplyStatus.values
            .firstWhere((s) => s.name == json['status'],
                orElse: () => SupplyStatus.enough),
        preferredBrand: json['preferredBrand'],
        notes: json['notes'],
        lastRestockedAt: json['lastRestockedAt'] != null
            ? DateTime.parse(json['lastRestockedAt'])
            : null,
        expectedDurationDays: json['expectedDurationDays'],
        isGas: json['isGas'] ?? false,
        isOwnerOnly: json['isOwnerOnly'] ?? false,
        usageLogs: (json['usageLogs'] as List<dynamic>? ?? [])
            .map((e) => SupplyUsageEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        statusUpdatedAt: json['statusUpdatedAt'] != null
            ? DateTime.tryParse(json['statusUpdatedAt'])
            : null,
        statusUpdatedByName: json['statusUpdatedByName'],
      );

  SupplyItem copyWith({
    SupplyStatus? status,
    String? notes,
    DateTime? lastRestockedAt,
    String? preferredBrand,
    bool? isOwnerOnly,
    List<SupplyUsageEntry>? usageLogs,
    DateTime? statusUpdatedAt,
    String? statusUpdatedByName,
  }) =>
      SupplyItem(
        id: id,
        householdId: householdId,
        name: name,
        category: category,
        unitType: unitType,
        status: status ?? this.status,
        preferredBrand: preferredBrand ?? this.preferredBrand,
        notes: notes ?? this.notes,
        lastRestockedAt: lastRestockedAt ?? this.lastRestockedAt,
        expectedDurationDays: expectedDurationDays,
        isGas: isGas,
        isOwnerOnly: isOwnerOnly ?? this.isOwnerOnly,
        usageLogs: usageLogs ?? this.usageLogs,
        statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
        statusUpdatedByName: statusUpdatedByName ?? this.statusUpdatedByName,
      );
}
