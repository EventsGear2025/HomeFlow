/// Tracks gas cylinders and utilities (electricity, water tokens, etc.)
enum UtilityType { cookingGas, electricity, water, waterBill, serviceCharge, internet, rent, payTv, other }

/// A single "amount used" entry for a utility tracker.
class UtilityUsageEntry {
  final DateTime date;
  final double quantity;
  final String? notes;

  const UtilityUsageEntry({
    required this.date,
    required this.quantity,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'quantity': quantity,
        'notes': notes,
      };

  factory UtilityUsageEntry.fromJson(Map<String, dynamic> j) =>
      UtilityUsageEntry(
        date: DateTime.parse(j['date']),
        quantity: (j['quantity'] as num).toDouble(),
        notes: j['notes'] as String?,
      );
}

enum GasCylinderSize { kg6, kg13, kg35, kg50 }

/// Alert level for cooking gas status
enum GasAlertLevel { ok, warning, critical, overdue }

/// Known gas cylinder brands in Kenya
enum GasBrand { total, rubis, afrigas, kgas, shell, pro, other }

extension GasBrandExt on GasBrand {
  String get displayName {
    switch (this) {
      case GasBrand.total:   return 'TotalEnergies';
      case GasBrand.rubis:   return 'Rubis';
      case GasBrand.afrigas: return 'Afrigas';
      case GasBrand.kgas:    return 'K-Gas';
      case GasBrand.shell:   return 'Shell';
      case GasBrand.pro:     return 'Pro Gas';
      case GasBrand.other:   return 'Other';
    }
  }
  String get emoji {
    switch (this) {
      case GasBrand.total:   return '🔵';
      case GasBrand.rubis:   return '🔴';
      case GasBrand.afrigas: return '🟠';
      case GasBrand.kgas:    return '🟢';
      case GasBrand.shell:   return '🟡';
      case GasBrand.pro:     return '🟣';
      case GasBrand.other:   return '⚪';
    }
  }
}

class GasSupplier {
  final String name;
  final String phone;
  /// M-Pesa payment name shown to payer (e.g. "Mwangi Gas Supplies")
  final String? mpesaName;
  /// Buy Goods till number OR Paybill number
  final String? mpesaTill;
  /// If true, mpesaTill is a Paybill number; if false, it's Buy Goods
  final bool isPaybill;
  /// Account reference required when isPaybill is true
  final String? mpesaAccountRef;

  const GasSupplier({
    required this.name,
    required this.phone,
    this.mpesaName,
    this.mpesaTill,
    this.isPaybill = false,
    this.mpesaAccountRef,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'mpesaName': mpesaName,
    'mpesaTill': mpesaTill,
    'isPaybill': isPaybill,
    'mpesaAccountRef': mpesaAccountRef,
  };

  factory GasSupplier.fromJson(Map<String, dynamic> j) => GasSupplier(
    name: j['name'] ?? '',
    phone: j['phone'] ?? '',
    mpesaName: j['mpesaName'],
    mpesaTill: j['mpesaTill'],
    isPaybill: j['isPaybill'] ?? false,
    mpesaAccountRef: j['mpesaAccountRef'],
  );

  GasSupplier copyWith({
    String? name,
    String? phone,
    String? mpesaName,
    String? mpesaTill,
    bool? isPaybill,
    String? mpesaAccountRef,
  }) => GasSupplier(
    name: name ?? this.name,
    phone: phone ?? this.phone,
    mpesaName: mpesaName ?? this.mpesaName,
    mpesaTill: mpesaTill ?? this.mpesaTill,
    isPaybill: isPaybill ?? this.isPaybill,
    mpesaAccountRef: mpesaAccountRef ?? this.mpesaAccountRef,
  );
}

enum UtilityPaymentStatus { unpaid, pending, paid }

class UtilityTracker {
  final String id;
  final String householdId;
  final UtilityType type;

  // ── Gas-specific fields ────────────────────────────────────────
  final GasCylinderSize? cylinderSize;
  /// Free-form kg size entered by user (e.g. 6, 13, 35, 50)
  final int? cylinderKg;
  /// Gas brand / make (Total, Rubis, etc.)
  final GasBrand? gasBrand;
  /// Custom brand name when gasBrand == GasBrand.other
  final String? gasBrandCustom;
  final DateTime? lastRefilledAt;
  final int? estimatedDurationDays; // how long this refill should last
  /// Whether gas setup wizard has been completed
  final bool gasSetupDone;
  /// Manager has flagged gas as running low
  final bool gasLowAlertSent;

  // ── Supplier fields ────────────────────────────────────────────
  final GasSupplier? supplier1;
  final GasSupplier? supplier2;
  /// Delivery address pre-filled in supplier SMS/WhatsApp
  final String? deliveryAddress;

  // ── Token/prepaid-specific fields ─────────────────────────────
  final double? tokenUnitsAdded; // kWh added / litres topped-up
  final double? unitsRemaining;  // current balance
  final DateTime? lastToppedUpAt;

  // ── Electricity-specific fields ───────────────────────────────
  /// Whether electricity setup wizard has been completed
  final bool electricitySetupDone;
  /// true = postpaid monthly bill; false = prepaid token top-up
  final bool isPostpaid;
  /// Prepaid: manager has flagged that tokens are running low
  final bool electricityLowAlertSent;
  /// Prepaid: typical KSh loaded per top-up (for quick reference)
  final double? typicalTokenAmount;
  /// Postpaid: day-of-month when bill is due (e.g. 20)
  final int? electricityBillDueDayOfMonth;
  /// Postpaid: most recent bill amount in KSh
  final double? lastBillAmount;
  /// Postpaid: when the last bill was paid
  final DateTime? electricityLastPaidAt;
  /// Postpaid: payment status for current bill cycle
  final UtilityPaymentStatus? electricityPaymentStatus;
  /// M-Pesa paybill details for electricity payment (e.g. KPLC 888880)
  final String? electricityPaybill;
  final String? electricityAccountRef;

  // ── Internet-specific fields ───────────────────────────────────
  /// Whether internet setup wizard has been completed
  final bool internetSetupDone;
  /// ISP name e.g. "Safaricom", "Zuku", "JTL Faiba"
  final String? ispName;
  /// Day of month when the monthly bill is due (e.g. 5)
  final int? internetDueDayOfMonth;
  /// Usual monthly amount in KSh
  final double? internetMonthlyAmount;
  /// When the internet was last paid
  final DateTime? internetLastPaidAt;
  /// Payment status for the current internet billing cycle
  final UtilityPaymentStatus? internetPaymentStatus;
  /// M-Pesa paybill or till for internet payment
  final String? internetMpesaTill;
  final bool internetIsPaybill;
  final String? internetMpesaAccountRef;

  // ── Bottled drinking-water-specific fields ─────────────────────
  final bool isDrinkingWater;
  /// Whether the drinking-water setup wizard has been completed
  final bool waterSetupDone;
  final double? containerSizeLitres;
  final int? totalContainers;
  final int? fullContainers;
  final int? emptyContainers;
  final int? reorderThreshold;
  final int? typicalOrderQuantity;
  final int? reorderFrequencyDays;
  final double? pricePerContainer;
  final DateTime? lastDeliveredAt;
  final UtilityPaymentStatus? paymentStatus;
  final DateTime? lastPaidAt;

  // ── Water bill (mains/piped) fields ────────────────────────────
  /// Whether water bill setup has been completed
  final bool waterBillSetupDone;
  /// Day of month the water bill is due (e.g. 20)
  final int? waterBillDueDayOfMonth;
  /// Most recent bill amount (KSh)
  final double? waterBillAmount;
  /// Payment status for the current billing cycle
  final UtilityPaymentStatus? waterBillPaymentStatus;
  /// When the last water bill was paid
  final DateTime? waterBillLastPaidAt;
  /// M-Pesa paybill/till for water bill payments
  final String? waterBillMpesaTill;
  final bool waterBillIsPaybill;
  final String? waterBillMpesaAccountRef;
  /// Manager has sent "bill arrived" notification to owner
  final bool waterBillNoteSent;

  // ── Service/garbage charge fields ──────────────────────────────
  /// Whether service charge has been set up
  final bool serviceChargeSetupDone;
  /// Day of month the service/garbage charge is due
  final int? serviceChargeDueDayOfMonth;
  /// Usual monthly amount (KSh)
  final double? serviceChargeAmount;
  /// Payment status for the current billing cycle
  final UtilityPaymentStatus? serviceChargePaymentStatus;
  /// When the last service charge was paid
  final DateTime? serviceChargeLastPaidAt;
  /// M-Pesa paybill/till for service charge
  final String? serviceChargeMpesaTill;
  final bool serviceChargeIsPaybill;
  final String? serviceChargeMpesaAccountRef;
  /// Manager has sent "bill arrived" notification to owner
  final bool serviceChargeNoteSent;

  // ── Rent fields ────────────────────────────────────────────────
  /// Whether rent has been set up
  final bool rentSetupDone;
  /// Day of month rent is due (e.g. 1, 5)
  final int? rentDueDayOfMonth;
  /// Monthly rent amount (KSh)
  final double? rentAmount;
  /// Landlord / agent name
  final String? rentLandlordName;
  /// Payment status for the current rent cycle
  final UtilityPaymentStatus? rentPaymentStatus;
  /// When rent was last paid
  final DateTime? rentLastPaidAt;
  /// M-Pesa paybill/till for rent payments
  final String? rentMpesaTill;
  final bool rentIsPaybill;
  final String? rentMpesaAccountRef;
  /// Manager has notified owner that rent is due
  final bool rentNoteSent;

  // ── Pay TV fields ──────────────────────────────────────────────
  /// Whether Pay TV has been set up
  final bool payTvSetupDone;
  /// Provider name (e.g. DSTV, Zuku TV, StarTimes)
  final String? payTvProvider;
  /// Day of month the subscription renews / is due
  final int? payTvDueDayOfMonth;
  /// Monthly subscription amount (KSh)
  final double? payTvMonthlyAmount;
  /// Payment status for the current Pay TV cycle
  final UtilityPaymentStatus? payTvPaymentStatus;
  /// When Pay TV was last paid
  final DateTime? payTvLastPaidAt;
  /// M-Pesa paybill/till for Pay TV payment
  final String? payTvMpesaTill;
  final bool payTvIsPaybill;
  final String? payTvMpesaAccountRef;

  // ── Shared fields ──────────────────────────────────────────────
  final String label;            // e.g. "Kitchen Gas", "Main Electricity"
  final String? notes;
  final DateTime updatedAt;
  /// When true, this utility is hidden from house managers — owner eyes only.
  final bool isOwnerOnly;
  /// History of "amount used" entries logged by household members.
  final List<UtilityUsageEntry> usageLogs;

  UtilityTracker({
    required this.id,
    required this.householdId,
    required this.type,
    required this.label,
    this.cylinderSize,
    this.cylinderKg,
    this.gasBrand,
    this.gasBrandCustom,
    this.lastRefilledAt,
    this.estimatedDurationDays,
    this.gasSetupDone = false,
    this.gasLowAlertSent = false,
    this.supplier1,
    this.supplier2,
    this.deliveryAddress,
    this.tokenUnitsAdded,
    this.unitsRemaining,
    this.lastToppedUpAt,
    this.electricitySetupDone = false,
    this.isPostpaid = false,
    this.electricityLowAlertSent = false,
    this.typicalTokenAmount,
    this.electricityBillDueDayOfMonth,
    this.lastBillAmount,
    this.electricityLastPaidAt,
    this.electricityPaymentStatus,
    this.electricityPaybill,
    this.electricityAccountRef,
    this.internetSetupDone = false,
    this.ispName,
    this.internetDueDayOfMonth,
    this.internetMonthlyAmount,
    this.internetLastPaidAt,
    this.internetPaymentStatus,
    this.internetMpesaTill,
    this.internetIsPaybill = false,
    this.internetMpesaAccountRef,
    this.isDrinkingWater = false,
    this.waterSetupDone = false,
    this.containerSizeLitres,
    this.totalContainers,
    this.fullContainers,
    this.emptyContainers,
    this.reorderThreshold,
    this.typicalOrderQuantity,
    this.reorderFrequencyDays,
    this.pricePerContainer,
    this.lastDeliveredAt,
    this.paymentStatus,
    this.lastPaidAt,
    this.waterBillSetupDone = false,
    this.waterBillDueDayOfMonth,
    this.waterBillAmount,
    this.waterBillPaymentStatus,
    this.waterBillLastPaidAt,
    this.waterBillMpesaTill,
    this.waterBillIsPaybill = false,
    this.waterBillMpesaAccountRef,
    this.waterBillNoteSent = false,
    this.serviceChargeSetupDone = false,
    this.serviceChargeDueDayOfMonth,
    this.serviceChargeAmount,
    this.serviceChargePaymentStatus,
    this.serviceChargeLastPaidAt,
    this.serviceChargeMpesaTill,
    this.serviceChargeIsPaybill = false,
    this.serviceChargeMpesaAccountRef,
    this.serviceChargeNoteSent = false,
    this.rentSetupDone = false,
    this.rentDueDayOfMonth,
    this.rentAmount,
    this.rentLandlordName,
    this.rentPaymentStatus,
    this.rentLastPaidAt,
    this.rentMpesaTill,
    this.rentIsPaybill = false,
    this.rentMpesaAccountRef,
    this.rentNoteSent = false,
    this.payTvSetupDone = false,
    this.payTvProvider,
    this.payTvDueDayOfMonth,
    this.payTvMonthlyAmount,
    this.payTvPaymentStatus,
    this.payTvLastPaidAt,
    this.payTvMpesaTill,
    this.payTvIsPaybill = false,
    this.payTvMpesaAccountRef,
    this.notes,
    required this.updatedAt,
    this.isOwnerOnly = false,
    this.usageLogs = const [],
  });

  /// Full brand display name (falls back to custom or "Gas Cylinder")
  String get brandName {
    if (gasBrand == null) return 'Gas Cylinder';
    if (gasBrand == GasBrand.other) return gasBrandCustom ?? 'Gas Cylinder';
    return gasBrand!.displayName;
  }

  // ── Gas helpers ────────────────────────────────────────────────

  /// Days since this gas cylinder was last refilled.
  int get daysSinceRefill =>
      lastRefilledAt == null
          ? 0
          : DateTime.now().difference(lastRefilledAt!).inDays;

  /// Estimated days remaining based on refill date + duration.
  int? get estimatedDaysRemaining {
    if (lastRefilledAt == null || estimatedDurationDays == null) return null;
    final elapsed = DateTime.now().difference(lastRefilledAt!).inDays;
    final remaining = estimatedDurationDays! - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// Expected run-out date (refill date + duration).
  DateTime? get estimatedRunOutDate {
    if (lastRefilledAt == null || estimatedDurationDays == null) return null;
    return lastRefilledAt!.add(Duration(days: estimatedDurationDays!));
  }

  /// Rough percentage of gas remaining (0–100).
  int? get gasPercentRemaining {
    final rem = estimatedDaysRemaining;
    if (rem == null || estimatedDurationDays == null) return null;
    return ((rem / estimatedDurationDays!) * 100).clamp(0, 100).round();
  }

  /// Rich alert level for gas:
  /// - overdue: past run-out date
  /// - critical: ≤ 3 days left
  /// - warning: ≤ 7 days left (about a week)
  /// - ok: plenty remaining
  GasAlertLevel get gasAlertLevel {
    if (type != UtilityType.cookingGas) return GasAlertLevel.ok;
    if (lastRefilledAt == null || estimatedDurationDays == null) return GasAlertLevel.ok;
    final rem = estimatedDaysRemaining ?? 0;
    if (rem == 0) return GasAlertLevel.overdue;
    if (rem <= 3) return GasAlertLevel.critical;
    if (rem <= 7) return GasAlertLevel.warning;
    return GasAlertLevel.ok;
  }

  /// Human-readable gas status message
  String get gasStatusMessage {
    if (lastRefilledAt == null || estimatedDurationDays == null) {
      return 'Set up your gas to start tracking';
    }
    final rem = estimatedDaysRemaining ?? 0;
    final runOut = estimatedRunOutDate;
    if (rem == 0) {
      final overdueDays = runOut == null
          ? 0
          : DateTime.now().difference(runOut).inDays;
      return overdueDays > 0
          ? 'Gas is $overdueDays day${overdueDays == 1 ? '' : 's'} past estimated run-out — refill now!'
          : 'Gas has reached estimated run-out date — refill now!';
    }
    if (rem <= 3) {
      return 'Gas finishing in $rem day${rem == 1 ? '' : 's'} — refill urgently!';
    }
    if (rem <= 7) {
      return 'Gas finishing in about a week ($rem days) — plan a refill soon';
    }
    return '$rem days remaining (est. run-out ${_fmtDate(runOut!)})';
  }

  static String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]}';
  }

  /// True when <= 7 days remaining or % <= 20.
  bool get isLowAlert {
    final level = gasAlertLevel;
    if (type == UtilityType.cookingGas) {
      if (gasLowAlertSent) return true;
      return level == GasAlertLevel.warning ||
          level == GasAlertLevel.critical ||
          level == GasAlertLevel.overdue;
    }
    if (type == UtilityType.water && isDrinkingWater) {
      final full = fullContainers ?? 0;
      final threshold = reorderThreshold ?? 1;
      return full <= threshold;
    }
    if (type == UtilityType.electricity && !isPostpaid) {
      // Prepaid: alert if manager has sent a low-token alert
      if (electricityLowAlertSent) return true;
      return unitsRemaining != null && unitsRemaining! <= 20;
    }
    if (type == UtilityType.electricity && isPostpaid) {
      // Postpaid: alert if bill is due within 3 days and unpaid
      return electricityDaysUntilDue != null &&
          electricityDaysUntilDue! <= 3 &&
          electricityPaymentStatus != UtilityPaymentStatus.paid;
    }
    if (type == UtilityType.internet) {
      return internetDaysUntilDue != null &&
          internetDaysUntilDue! <= 3 &&
          internetPaymentStatus != UtilityPaymentStatus.paid;
    }
    if (type == UtilityType.water) {
      return unitsRemaining != null && unitsRemaining! <= 20;
    }
    if (type == UtilityType.waterBill) {
      return waterBillDaysUntilDue != null &&
          waterBillDaysUntilDue! <= 3 &&
          waterBillPaymentStatus != UtilityPaymentStatus.paid;
    }
    if (type == UtilityType.serviceCharge) {
      return serviceChargeDaysUntilDue != null &&
          serviceChargeDaysUntilDue! <= 3 &&
          serviceChargePaymentStatus != UtilityPaymentStatus.paid;
    }
    if (type == UtilityType.rent) {
      return rentDaysUntilDue != null &&
          rentDaysUntilDue! <= 3 &&
          rentPaymentStatus != UtilityPaymentStatus.paid;
    }
    if (type == UtilityType.payTv) {
      return payTvDaysUntilDue != null &&
          payTvDaysUntilDue! <= 3 &&
          payTvPaymentStatus != UtilityPaymentStatus.paid;
    }
    return false;
  }

  // ── Electricity helpers ────────────────────────────────────────

  /// Days until next electricity bill is due (postpaid). Null if not configured.
  int? get electricityDaysUntilDue {
    if (!isPostpaid || electricityBillDueDayOfMonth == null) return null;
    final now = DateTime.now();
    var due = DateTime(now.year, now.month, electricityBillDueDayOfMonth!);
    if (due.isBefore(now)) {
      // Roll to next month
      due = DateTime(now.year, now.month + 1, electricityBillDueDayOfMonth!);
    }
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Human-readable electricity status message.
  String get electricityStatusMessage {
    if (!electricitySetupDone) return 'Set up electricity to start tracking';
    if (!isPostpaid) {
      // Prepaid
      if (electricityLowAlertSent) {
        return 'Low token alert — manager says tokens are running low. Top up now!';
      }
      if (unitsRemaining != null) {
        final u = unitsRemaining!.toStringAsFixed(0);
        if (unitsRemaining! <= 20) return '$u kWh remaining — top up soon!';
        return '$u kWh remaining';
      }
      return 'Update token balance to track usage';
    } else {
      // Postpaid
      final days = electricityDaysUntilDue;
      final status = electricityPaymentStatus ?? UtilityPaymentStatus.unpaid;
      if (status == UtilityPaymentStatus.paid) {
        return 'Bill paid ✓${electricityLastPaidAt != null ? ' · paid ${_fmtDate(electricityLastPaidAt!)}' : ''}';
      }
      if (lastBillAmount != null) {
        final amt = 'KSh ${lastBillAmount!.toStringAsFixed(0)}';
        if (days != null && days == 0) return '$amt bill due today — pay now!';
        if (days != null && days <= 3) return '$amt bill due in $days days';
        if (days != null) return '$amt due in $days days';
        return 'Bill $amt — mark as paid when settled';
      }
      if (days != null && days <= 3) return 'Bill due in $days days — record amount and pay';
      if (days != null) return 'Bill due in $days days';
      return 'Record bill amount when received';
    }
  }

  // ── Internet helpers ───────────────────────────────────────────

  /// Days until internet bill is due. Null if not configured.
  int? get internetDaysUntilDue {
    if (internetDueDayOfMonth == null) return null;
    final now = DateTime.now();
    var due = DateTime(now.year, now.month, internetDueDayOfMonth!);
    if (due.isBefore(now)) {
      due = DateTime(now.year, now.month + 1, internetDueDayOfMonth!);
    }
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Human-readable internet status message.
  String get internetStatusMessage {
    if (!internetSetupDone) return 'Set up internet to start tracking';
    final days = internetDaysUntilDue;
    final status = internetPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final isp = ispName ?? 'Internet';
    final amt = internetMonthlyAmount != null
        ? 'KSh ${internetMonthlyAmount!.toStringAsFixed(0)}'
        : '';
    if (status == UtilityPaymentStatus.paid) {
      return '$isp paid ✓${internetLastPaidAt != null ? ' · paid ${_fmtDate(internetLastPaidAt!)}' : ''}';
    }
    if (days != null && days == 0) return '$isp${amt.isNotEmpty ? ' ($amt)' : ''} due today — pay now!';
    if (days != null && days <= 3) return '$isp${amt.isNotEmpty ? ' ($amt)' : ''} due in $days days';
    if (days != null) return '$isp bill due in $days days${amt.isNotEmpty ? ' · $amt' : ''}';
    return '$isp monthly bill — mark as paid when settled';
  }

  // ── Water bill helpers ─────────────────────────────────────────

  /// Days until water bill is due. Null if not configured.
  int? get waterBillDaysUntilDue {
    if (waterBillDueDayOfMonth == null) return null;
    final now = DateTime.now();
    var due = DateTime(now.year, now.month, waterBillDueDayOfMonth!);
    if (due.isBefore(now)) {
      due = DateTime(now.year, now.month + 1, waterBillDueDayOfMonth!);
    }
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Human-readable water bill status message.
  String get waterBillStatusMessage {
    if (!waterBillSetupDone) return 'Set up water bill to track payments';
    final days = waterBillDaysUntilDue;
    final status = waterBillPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final amt = waterBillAmount != null
        ? 'KSh ${waterBillAmount!.toStringAsFixed(0)}'
        : '';
    if (status == UtilityPaymentStatus.paid) {
      return 'Bill paid ✓${waterBillLastPaidAt != null ? ' · paid ${_fmtDate(waterBillLastPaidAt!)}' : ''}';
    }
    if (waterBillNoteSent) return 'Manager: bill arrived — owner notified to pay${amt.isNotEmpty ? ' ($amt)' : ''}';
    if (days != null && days == 0) return '${amt.isNotEmpty ? '$amt ' : ''}bill due today — pay now!';
    if (days != null && days <= 3) return '${amt.isNotEmpty ? '$amt ' : ''}bill due in $days days';
    if (days != null) return 'Bill due in $days days${amt.isNotEmpty ? ' · $amt' : ''}';
    return 'Record bill amount when received';
  }

  // ── Service charge helpers ─────────────────────────────────────

  /// Days until service charge is due. Null if not configured.
  int? get serviceChargeDaysUntilDue {
    if (serviceChargeDueDayOfMonth == null) return null;
    final now = DateTime.now();
    var due = DateTime(now.year, now.month, serviceChargeDueDayOfMonth!);
    if (due.isBefore(now)) {
      due = DateTime(now.year, now.month + 1, serviceChargeDueDayOfMonth!);
    }
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Human-readable service charge status message.
  String get serviceChargeStatusMessage {
    if (!serviceChargeSetupDone) return 'Set up service charge to track payments';
    final days = serviceChargeDaysUntilDue;
    final status = serviceChargePaymentStatus ?? UtilityPaymentStatus.unpaid;
    final amt = serviceChargeAmount != null
        ? 'KSh ${serviceChargeAmount!.toStringAsFixed(0)}'
        : '';
    if (status == UtilityPaymentStatus.paid) {
      return 'Paid ✓${serviceChargeLastPaidAt != null ? ' · paid ${_fmtDate(serviceChargeLastPaidAt!)}' : ''}';
    }
    if (serviceChargeNoteSent) return 'Manager: bill arrived — owner notified to pay${amt.isNotEmpty ? ' ($amt)' : ''}';
    if (days != null && days == 0) return '${amt.isNotEmpty ? '$amt ' : ''}due today — pay now!';
    if (days != null && days <= 3) return '${amt.isNotEmpty ? '$amt ' : ''}due in $days days';
    if (days != null) return 'Due in $days days${amt.isNotEmpty ? ' · $amt' : ''}';
    return 'Record amount when bill arrives';
  }

  // ── Rent helpers ───────────────────────────────────────────────

  /// Days until rent is due. Null if not configured.
  int? get rentDaysUntilDue {
    if (rentDueDayOfMonth == null) return null;
    final now = DateTime.now();
    var due = DateTime(now.year, now.month, rentDueDayOfMonth!);
    if (due.isBefore(now)) {
      due = DateTime(now.year, now.month + 1, rentDueDayOfMonth!);
    }
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Human-readable rent status message.
  String get rentStatusMessage {
    if (!rentSetupDone) return 'Set up rent to track monthly payments';
    final days = rentDaysUntilDue;
    final status = rentPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final amt = rentAmount != null ? 'KSh ${rentAmount!.toStringAsFixed(0)}' : '';
    final who = rentLandlordName != null ? 'to ${rentLandlordName!}' : '';
    if (status == UtilityPaymentStatus.paid) {
      return 'Rent paid ✓${rentLastPaidAt != null ? ' · paid ${_fmtDate(rentLastPaidAt!)}' : ''}';
    }
    if (rentNoteSent) return 'Manager: rent due — owner notified to pay${amt.isNotEmpty ? ' ($amt)' : ''}';
    if (days != null && days == 0) return 'Rent${amt.isNotEmpty ? ' ($amt)' : ''} due today${who.isNotEmpty ? ' $who' : ''} — pay now!';
    if (days != null && days <= 3) return 'Rent${amt.isNotEmpty ? ' ($amt)' : ''} due in $days days${who.isNotEmpty ? ' $who' : ''}';
    if (days != null) return 'Rent due in $days days${amt.isNotEmpty ? ' · $amt' : ''}';
    return 'Record rent amount when due';
  }

  // ── Pay TV helpers ─────────────────────────────────────────────

  /// Days until Pay TV subscription is due. Null if not configured.
  int? get payTvDaysUntilDue {
    if (payTvDueDayOfMonth == null) return null;
    final now = DateTime.now();
    var due = DateTime(now.year, now.month, payTvDueDayOfMonth!);
    if (due.isBefore(now)) {
      due = DateTime(now.year, now.month + 1, payTvDueDayOfMonth!);
    }
    return due.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// Human-readable Pay TV status message.
  String get payTvStatusMessage {
    if (!payTvSetupDone) return 'Set up Pay TV to track subscription payments';
    final days = payTvDaysUntilDue;
    final status = payTvPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final provider = payTvProvider ?? 'Pay TV';
    final amt = payTvMonthlyAmount != null ? 'KSh ${payTvMonthlyAmount!.toStringAsFixed(0)}' : '';
    if (status == UtilityPaymentStatus.paid) {
      return '$provider paid ✓${payTvLastPaidAt != null ? ' · paid ${_fmtDate(payTvLastPaidAt!)}' : ''}';
    }
    if (days != null && days == 0) return '$provider${amt.isNotEmpty ? ' ($amt)' : ''} subscription due today — pay now!';
    if (days != null && days <= 3) return '$provider${amt.isNotEmpty ? ' ($amt)' : ''} due in $days days';
    if (days != null) return '$provider subscription due in $days days${amt.isNotEmpty ? ' · $amt' : ''}';
    return '$provider subscription — mark as paid when settled';
  }

  int get drinkingWaterDaysRemaining {    if (!isDrinkingWater) return 0;
    final frequency = reorderFrequencyDays ?? 14;
    final total = totalContainers ?? 0;
    final full = fullContainers ?? 0;
    if (total <= 0 || full <= 0) return 0;
    final dailyConsumption = total / frequency;
    if (dailyConsumption <= 0) return 0;
    return (full / dailyConsumption).floor();
  }

  String get drinkingWaterStatusMessage {
    if (!isDrinkingWater) return '';

    final full = fullContainers ?? 0;
    final empty = emptyContainers ?? 0;
    final total = totalContainers ?? 0;
    final size = containerSizeLitres?.toStringAsFixed(
      (containerSizeLitres ?? 0) % 1 == 0 ? 0 : 1,
    );

    if (full == 0) {
      return 'All $total bottle${total == 1 ? '' : 's'} are empty — order a refill now.';
    }
    if (isLowAlert) {
      return '$full full ${size != null ? '${size}L ' : ''}bottle${full == 1 ? '' : 's'} left, $empty empty — reorder soon.';
    }
    return '$full full and $empty empty bottle${(full + empty) == 1 ? '' : 's'} on hand.';
  }

  /// Human-readable cylinder size label.
  static String cylinderSizeLabel(GasCylinderSize size) {
    switch (size) {
      case GasCylinderSize.kg6:
        return '6 kg';
      case GasCylinderSize.kg13:
        return '13 kg';
      case GasCylinderSize.kg35:
        return '35 kg';
      case GasCylinderSize.kg50:
        return '50 kg';
    }
  }

  /// Default estimated duration per cylinder size (days).
  static int defaultDuration(GasCylinderSize size) {
    switch (size) {
      case GasCylinderSize.kg6:
        return 21;
      case GasCylinderSize.kg13:
        return 42;
      case GasCylinderSize.kg35:
        return 90;
      case GasCylinderSize.kg50:
        return 120;
    }
  }

  // ── Serialisation ──────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'type': type.name,
        'label': label,
        'cylinderSize': cylinderSize?.name,
        'cylinderKg': cylinderKg,
        'gasBrand': gasBrand?.name,
        'gasBrandCustom': gasBrandCustom,
        'lastRefilledAt': lastRefilledAt?.toIso8601String(),
        'estimatedDurationDays': estimatedDurationDays,
        'gasSetupDone': gasSetupDone,
        'gasLowAlertSent': gasLowAlertSent,
        'supplier1': supplier1?.toJson(),
        'supplier2': supplier2?.toJson(),
        'deliveryAddress': deliveryAddress,
        'tokenUnitsAdded': tokenUnitsAdded,
        'unitsRemaining': unitsRemaining,
        'lastToppedUpAt': lastToppedUpAt?.toIso8601String(),
        'electricitySetupDone': electricitySetupDone,
        'isPostpaid': isPostpaid,
        'electricityLowAlertSent': electricityLowAlertSent,
        'typicalTokenAmount': typicalTokenAmount,
        'electricityBillDueDayOfMonth': electricityBillDueDayOfMonth,
        'lastBillAmount': lastBillAmount,
        'electricityLastPaidAt': electricityLastPaidAt?.toIso8601String(),
        'electricityPaymentStatus': electricityPaymentStatus?.name,
        'electricityPaybill': electricityPaybill,
        'electricityAccountRef': electricityAccountRef,
        'internetSetupDone': internetSetupDone,
        'ispName': ispName,
        'internetDueDayOfMonth': internetDueDayOfMonth,
        'internetMonthlyAmount': internetMonthlyAmount,
        'internetLastPaidAt': internetLastPaidAt?.toIso8601String(),
        'internetPaymentStatus': internetPaymentStatus?.name,
        'internetMpesaTill': internetMpesaTill,
        'internetIsPaybill': internetIsPaybill,
        'internetMpesaAccountRef': internetMpesaAccountRef,
        'isDrinkingWater': isDrinkingWater,
        'waterSetupDone': waterSetupDone,
        'containerSizeLitres': containerSizeLitres,
        'totalContainers': totalContainers,
        'fullContainers': fullContainers,
        'emptyContainers': emptyContainers,
        'reorderThreshold': reorderThreshold,
        'typicalOrderQuantity': typicalOrderQuantity,
        'reorderFrequencyDays': reorderFrequencyDays,
        'pricePerContainer': pricePerContainer,
        'lastDeliveredAt': lastDeliveredAt?.toIso8601String(),
        'paymentStatus': paymentStatus?.name,
        'lastPaidAt': lastPaidAt?.toIso8601String(),
        'waterBillSetupDone': waterBillSetupDone,
        'waterBillDueDayOfMonth': waterBillDueDayOfMonth,
        'waterBillAmount': waterBillAmount,
        'waterBillPaymentStatus': waterBillPaymentStatus?.name,
        'waterBillLastPaidAt': waterBillLastPaidAt?.toIso8601String(),
        'waterBillMpesaTill': waterBillMpesaTill,
        'waterBillIsPaybill': waterBillIsPaybill,
        'waterBillMpesaAccountRef': waterBillMpesaAccountRef,
        'waterBillNoteSent': waterBillNoteSent,
        'serviceChargeSetupDone': serviceChargeSetupDone,
        'serviceChargeDueDayOfMonth': serviceChargeDueDayOfMonth,
        'serviceChargeAmount': serviceChargeAmount,
        'serviceChargePaymentStatus': serviceChargePaymentStatus?.name,
        'serviceChargeLastPaidAt': serviceChargeLastPaidAt?.toIso8601String(),
        'serviceChargeMpesaTill': serviceChargeMpesaTill,
        'serviceChargeIsPaybill': serviceChargeIsPaybill,
        'serviceChargeMpesaAccountRef': serviceChargeMpesaAccountRef,
        'serviceChargeNoteSent': serviceChargeNoteSent,
        'rentSetupDone': rentSetupDone,
        'rentDueDayOfMonth': rentDueDayOfMonth,
        'rentAmount': rentAmount,
        'rentLandlordName': rentLandlordName,
        'rentPaymentStatus': rentPaymentStatus?.name,
        'rentLastPaidAt': rentLastPaidAt?.toIso8601String(),
        'rentMpesaTill': rentMpesaTill,
        'rentIsPaybill': rentIsPaybill,
        'rentMpesaAccountRef': rentMpesaAccountRef,
        'rentNoteSent': rentNoteSent,
        'payTvSetupDone': payTvSetupDone,
        'payTvProvider': payTvProvider,
        'payTvDueDayOfMonth': payTvDueDayOfMonth,
        'payTvMonthlyAmount': payTvMonthlyAmount,
        'payTvPaymentStatus': payTvPaymentStatus?.name,
        'payTvLastPaidAt': payTvLastPaidAt?.toIso8601String(),
        'payTvMpesaTill': payTvMpesaTill,
        'payTvIsPaybill': payTvIsPaybill,
        'payTvMpesaAccountRef': payTvMpesaAccountRef,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
        'isOwnerOnly': isOwnerOnly,
        'usageLogs': usageLogs.map((e) => e.toJson()).toList(),
      };

  factory UtilityTracker.fromJson(Map<String, dynamic> json) => UtilityTracker(
        id: json['id'],
        householdId: json['householdId'],
        type: UtilityType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => UtilityType.other,
        ),
        label: json['label'],
        cylinderSize: json['cylinderSize'] != null
            ? GasCylinderSize.values.firstWhere(
                (s) => s.name == json['cylinderSize'],
                orElse: () => GasCylinderSize.kg13,
              )
            : null,
        cylinderKg: json['cylinderKg'],
        gasBrand: json['gasBrand'] != null
            ? GasBrand.values.firstWhere(
                (b) => b.name == json['gasBrand'],
                orElse: () => GasBrand.other,
              )
            : null,
        gasBrandCustom: json['gasBrandCustom'],
        lastRefilledAt: json['lastRefilledAt'] != null
            ? DateTime.parse(json['lastRefilledAt'])
            : null,
        estimatedDurationDays: json['estimatedDurationDays'],
        gasSetupDone: json['gasSetupDone'] ?? false,
        gasLowAlertSent: json['gasLowAlertSent'] ?? false,
        supplier1: json['supplier1'] != null
            ? GasSupplier.fromJson(json['supplier1'])
            : null,
        supplier2: json['supplier2'] != null
            ? GasSupplier.fromJson(json['supplier2'])
            : null,
        deliveryAddress: json['deliveryAddress'],
        tokenUnitsAdded: (json['tokenUnitsAdded'] as num?)?.toDouble(),
        unitsRemaining: (json['unitsRemaining'] as num?)?.toDouble(),
        lastToppedUpAt: json['lastToppedUpAt'] != null
            ? DateTime.parse(json['lastToppedUpAt'])
            : null,
        electricitySetupDone: json['electricitySetupDone'] ?? false,
        isPostpaid: json['isPostpaid'] ?? false,
        electricityLowAlertSent: json['electricityLowAlertSent'] ?? false,
        typicalTokenAmount: (json['typicalTokenAmount'] as num?)?.toDouble(),
        electricityBillDueDayOfMonth: json['electricityBillDueDayOfMonth'],
        lastBillAmount: (json['lastBillAmount'] as num?)?.toDouble(),
        electricityLastPaidAt: json['electricityLastPaidAt'] != null
            ? DateTime.parse(json['electricityLastPaidAt'])
            : null,
        electricityPaymentStatus: json['electricityPaymentStatus'] != null
            ? UtilityPaymentStatus.values.firstWhere(
                (s) => s.name == json['electricityPaymentStatus'],
                orElse: () => UtilityPaymentStatus.unpaid,
              )
            : null,
        electricityPaybill: json['electricityPaybill'],
        electricityAccountRef: json['electricityAccountRef'],
        internetSetupDone: json['internetSetupDone'] ?? false,
        ispName: json['ispName'],
        internetDueDayOfMonth: json['internetDueDayOfMonth'],
        internetMonthlyAmount: (json['internetMonthlyAmount'] as num?)?.toDouble(),
        internetLastPaidAt: json['internetLastPaidAt'] != null
            ? DateTime.parse(json['internetLastPaidAt'])
            : null,
        internetPaymentStatus: json['internetPaymentStatus'] != null
            ? UtilityPaymentStatus.values.firstWhere(
                (s) => s.name == json['internetPaymentStatus'],
                orElse: () => UtilityPaymentStatus.unpaid,
              )
            : null,
        internetMpesaTill: json['internetMpesaTill'],
        internetIsPaybill: json['internetIsPaybill'] ?? false,
        internetMpesaAccountRef: json['internetMpesaAccountRef'],
    isDrinkingWater: json['isDrinkingWater'] ?? false,
    waterSetupDone: json['waterSetupDone'] ?? false,
    containerSizeLitres: (json['containerSizeLitres'] as num?)?.toDouble(),
    totalContainers: json['totalContainers'],
    fullContainers: json['fullContainers'],
    emptyContainers: json['emptyContainers'],
    reorderThreshold: json['reorderThreshold'],
    typicalOrderQuantity: json['typicalOrderQuantity'],
    reorderFrequencyDays: json['reorderFrequencyDays'],
    pricePerContainer: (json['pricePerContainer'] as num?)?.toDouble(),
    lastDeliveredAt: json['lastDeliveredAt'] != null
      ? DateTime.parse(json['lastDeliveredAt'])
      : null,
    paymentStatus: json['paymentStatus'] != null
      ? UtilityPaymentStatus.values.firstWhere(
        (s) => s.name == json['paymentStatus'],
        orElse: () => UtilityPaymentStatus.unpaid,
        )
      : null,
    lastPaidAt: json['lastPaidAt'] != null
      ? DateTime.parse(json['lastPaidAt'])
      : null,
        waterBillSetupDone: json['waterBillSetupDone'] ?? false,
        waterBillDueDayOfMonth: json['waterBillDueDayOfMonth'],
        waterBillAmount: (json['waterBillAmount'] as num?)?.toDouble(),
        waterBillPaymentStatus: json['waterBillPaymentStatus'] != null
            ? UtilityPaymentStatus.values.firstWhere(
                (s) => s.name == json['waterBillPaymentStatus'],
                orElse: () => UtilityPaymentStatus.unpaid,
              )
            : null,
        waterBillLastPaidAt: json['waterBillLastPaidAt'] != null
            ? DateTime.parse(json['waterBillLastPaidAt'])
            : null,
        waterBillMpesaTill: json['waterBillMpesaTill'],
        waterBillIsPaybill: json['waterBillIsPaybill'] ?? false,
        waterBillMpesaAccountRef: json['waterBillMpesaAccountRef'],
        waterBillNoteSent: json['waterBillNoteSent'] ?? false,
        serviceChargeSetupDone: json['serviceChargeSetupDone'] ?? false,
        serviceChargeDueDayOfMonth: json['serviceChargeDueDayOfMonth'],
        serviceChargeAmount: (json['serviceChargeAmount'] as num?)?.toDouble(),
        serviceChargePaymentStatus: json['serviceChargePaymentStatus'] != null
            ? UtilityPaymentStatus.values.firstWhere(
                (s) => s.name == json['serviceChargePaymentStatus'],
                orElse: () => UtilityPaymentStatus.unpaid,
              )
            : null,
        serviceChargeLastPaidAt: json['serviceChargeLastPaidAt'] != null
            ? DateTime.parse(json['serviceChargeLastPaidAt'])
            : null,
        serviceChargeMpesaTill: json['serviceChargeMpesaTill'],
        serviceChargeIsPaybill: json['serviceChargeIsPaybill'] ?? false,
        serviceChargeMpesaAccountRef: json['serviceChargeMpesaAccountRef'],
        serviceChargeNoteSent: json['serviceChargeNoteSent'] ?? false,
        rentSetupDone: json['rentSetupDone'] ?? false,
        rentDueDayOfMonth: json['rentDueDayOfMonth'],
        rentAmount: (json['rentAmount'] as num?)?.toDouble(),
        rentLandlordName: json['rentLandlordName'],
        rentPaymentStatus: json['rentPaymentStatus'] != null
            ? UtilityPaymentStatus.values.firstWhere(
                (s) => s.name == json['rentPaymentStatus'],
                orElse: () => UtilityPaymentStatus.unpaid,
              )
            : null,
        rentLastPaidAt: json['rentLastPaidAt'] != null
            ? DateTime.parse(json['rentLastPaidAt'])
            : null,
        rentMpesaTill: json['rentMpesaTill'],
        rentIsPaybill: json['rentIsPaybill'] ?? false,
        rentMpesaAccountRef: json['rentMpesaAccountRef'],
        rentNoteSent: json['rentNoteSent'] ?? false,
        payTvSetupDone: json['payTvSetupDone'] ?? false,
        payTvProvider: json['payTvProvider'],
        payTvDueDayOfMonth: json['payTvDueDayOfMonth'],
        payTvMonthlyAmount: (json['payTvMonthlyAmount'] as num?)?.toDouble(),
        payTvPaymentStatus: json['payTvPaymentStatus'] != null
            ? UtilityPaymentStatus.values.firstWhere(
                (s) => s.name == json['payTvPaymentStatus'],
                orElse: () => UtilityPaymentStatus.unpaid,
              )
            : null,
        payTvLastPaidAt: json['payTvLastPaidAt'] != null
            ? DateTime.parse(json['payTvLastPaidAt'])
            : null,
        payTvMpesaTill: json['payTvMpesaTill'],
        payTvIsPaybill: json['payTvIsPaybill'] ?? false,
        payTvMpesaAccountRef: json['payTvMpesaAccountRef'],
        isOwnerOnly: json['isOwnerOnly'] ?? false,
        notes: json['notes'],
        updatedAt: DateTime.parse(json['updatedAt']),
        usageLogs: (json['usageLogs'] as List<dynamic>? ?? [])
            .map((e) => UtilityUsageEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  UtilityTracker copyWith({
    UtilityType? type,
    String? label,
    GasCylinderSize? cylinderSize,
    int? cylinderKg,
    GasBrand? gasBrand,
    String? gasBrandCustom,
    DateTime? lastRefilledAt,
    int? estimatedDurationDays,
    bool? gasSetupDone,
    bool? gasLowAlertSent,
    GasSupplier? supplier1,
    GasSupplier? supplier2,
    String? deliveryAddress,
    double? tokenUnitsAdded,
    double? unitsRemaining,
    DateTime? lastToppedUpAt,
    bool? electricitySetupDone,
    bool? isPostpaid,
    bool? electricityLowAlertSent,
    double? typicalTokenAmount,
    int? electricityBillDueDayOfMonth,
    double? lastBillAmount,
    DateTime? electricityLastPaidAt,
    UtilityPaymentStatus? electricityPaymentStatus,
    String? electricityPaybill,
    String? electricityAccountRef,
    bool? internetSetupDone,
    String? ispName,
    int? internetDueDayOfMonth,
    double? internetMonthlyAmount,
    DateTime? internetLastPaidAt,
    UtilityPaymentStatus? internetPaymentStatus,
    String? internetMpesaTill,
    bool? internetIsPaybill,
    String? internetMpesaAccountRef,
    bool? isDrinkingWater,
    bool? waterSetupDone,
    double? containerSizeLitres,
    int? totalContainers,
    int? fullContainers,
    int? emptyContainers,
    int? reorderThreshold,
    int? typicalOrderQuantity,
    int? reorderFrequencyDays,
    double? pricePerContainer,
    DateTime? lastDeliveredAt,
    UtilityPaymentStatus? paymentStatus,
    DateTime? lastPaidAt,
    bool? waterBillSetupDone,
    int? waterBillDueDayOfMonth,
    double? waterBillAmount,
    UtilityPaymentStatus? waterBillPaymentStatus,
    DateTime? waterBillLastPaidAt,
    String? waterBillMpesaTill,
    bool? waterBillIsPaybill,
    String? waterBillMpesaAccountRef,
    bool? waterBillNoteSent,
    bool? serviceChargeSetupDone,
    int? serviceChargeDueDayOfMonth,
    double? serviceChargeAmount,
    UtilityPaymentStatus? serviceChargePaymentStatus,
    DateTime? serviceChargeLastPaidAt,
    String? serviceChargeMpesaTill,
    bool? serviceChargeIsPaybill,
    String? serviceChargeMpesaAccountRef,
    bool? serviceChargeNoteSent,
    bool? rentSetupDone,
    int? rentDueDayOfMonth,
    double? rentAmount,
    String? rentLandlordName,
    UtilityPaymentStatus? rentPaymentStatus,
    DateTime? rentLastPaidAt,
    String? rentMpesaTill,
    bool? rentIsPaybill,
    String? rentMpesaAccountRef,
    bool? rentNoteSent,
    bool? payTvSetupDone,
    String? payTvProvider,
    int? payTvDueDayOfMonth,
    double? payTvMonthlyAmount,
    UtilityPaymentStatus? payTvPaymentStatus,
    DateTime? payTvLastPaidAt,
    String? payTvMpesaTill,
    bool? payTvIsPaybill,
    String? payTvMpesaAccountRef,
    bool? isOwnerOnly,
    String? notes,
    List<UtilityUsageEntry>? usageLogs,
  }) =>
      UtilityTracker(
        id: id,
        householdId: householdId,
        type: type ?? this.type,
        label: label ?? this.label,
        cylinderSize: cylinderSize ?? this.cylinderSize,
        cylinderKg: cylinderKg ?? this.cylinderKg,
        gasBrand: gasBrand ?? this.gasBrand,
        gasBrandCustom: gasBrandCustom ?? this.gasBrandCustom,
        lastRefilledAt: lastRefilledAt ?? this.lastRefilledAt,
        estimatedDurationDays:
            estimatedDurationDays ?? this.estimatedDurationDays,
        gasSetupDone: gasSetupDone ?? this.gasSetupDone,
        gasLowAlertSent: gasLowAlertSent ?? this.gasLowAlertSent,
        supplier1: supplier1 ?? this.supplier1,
        supplier2: supplier2 ?? this.supplier2,
        deliveryAddress: deliveryAddress ?? this.deliveryAddress,
        tokenUnitsAdded: tokenUnitsAdded ?? this.tokenUnitsAdded,
        unitsRemaining: unitsRemaining ?? this.unitsRemaining,
        lastToppedUpAt: lastToppedUpAt ?? this.lastToppedUpAt,
        electricitySetupDone: electricitySetupDone ?? this.electricitySetupDone,
        isPostpaid: isPostpaid ?? this.isPostpaid,
        electricityLowAlertSent:
            electricityLowAlertSent ?? this.electricityLowAlertSent,
        typicalTokenAmount: typicalTokenAmount ?? this.typicalTokenAmount,
        electricityBillDueDayOfMonth:
            electricityBillDueDayOfMonth ?? this.electricityBillDueDayOfMonth,
        lastBillAmount: lastBillAmount ?? this.lastBillAmount,
        electricityLastPaidAt:
            electricityLastPaidAt ?? this.electricityLastPaidAt,
        electricityPaymentStatus:
            electricityPaymentStatus ?? this.electricityPaymentStatus,
        electricityPaybill: electricityPaybill ?? this.electricityPaybill,
        electricityAccountRef:
            electricityAccountRef ?? this.electricityAccountRef,
        internetSetupDone: internetSetupDone ?? this.internetSetupDone,
        ispName: ispName ?? this.ispName,
        internetDueDayOfMonth:
            internetDueDayOfMonth ?? this.internetDueDayOfMonth,
        internetMonthlyAmount:
            internetMonthlyAmount ?? this.internetMonthlyAmount,
        internetLastPaidAt: internetLastPaidAt ?? this.internetLastPaidAt,
        internetPaymentStatus:
            internetPaymentStatus ?? this.internetPaymentStatus,
        internetMpesaTill: internetMpesaTill ?? this.internetMpesaTill,
        internetIsPaybill: internetIsPaybill ?? this.internetIsPaybill,
        internetMpesaAccountRef:
            internetMpesaAccountRef ?? this.internetMpesaAccountRef,
        isDrinkingWater: isDrinkingWater ?? this.isDrinkingWater,
        waterSetupDone: waterSetupDone ?? this.waterSetupDone,
        containerSizeLitres: containerSizeLitres ?? this.containerSizeLitres,
        totalContainers: totalContainers ?? this.totalContainers,
        fullContainers: fullContainers ?? this.fullContainers,
        emptyContainers: emptyContainers ?? this.emptyContainers,
        reorderThreshold: reorderThreshold ?? this.reorderThreshold,
        typicalOrderQuantity:
            typicalOrderQuantity ?? this.typicalOrderQuantity,
        reorderFrequencyDays:
            reorderFrequencyDays ?? this.reorderFrequencyDays,
        pricePerContainer: pricePerContainer ?? this.pricePerContainer,
        lastDeliveredAt: lastDeliveredAt ?? this.lastDeliveredAt,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        lastPaidAt: lastPaidAt ?? this.lastPaidAt,
        waterBillSetupDone: waterBillSetupDone ?? this.waterBillSetupDone,
        waterBillDueDayOfMonth: waterBillDueDayOfMonth ?? this.waterBillDueDayOfMonth,
        waterBillAmount: waterBillAmount ?? this.waterBillAmount,
        waterBillPaymentStatus: waterBillPaymentStatus ?? this.waterBillPaymentStatus,
        waterBillLastPaidAt: waterBillLastPaidAt ?? this.waterBillLastPaidAt,
        waterBillMpesaTill: waterBillMpesaTill ?? this.waterBillMpesaTill,
        waterBillIsPaybill: waterBillIsPaybill ?? this.waterBillIsPaybill,
        waterBillMpesaAccountRef: waterBillMpesaAccountRef ?? this.waterBillMpesaAccountRef,
        waterBillNoteSent: waterBillNoteSent ?? this.waterBillNoteSent,
        serviceChargeSetupDone: serviceChargeSetupDone ?? this.serviceChargeSetupDone,
        serviceChargeDueDayOfMonth: serviceChargeDueDayOfMonth ?? this.serviceChargeDueDayOfMonth,
        serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
        serviceChargePaymentStatus: serviceChargePaymentStatus ?? this.serviceChargePaymentStatus,
        serviceChargeLastPaidAt: serviceChargeLastPaidAt ?? this.serviceChargeLastPaidAt,
        serviceChargeMpesaTill: serviceChargeMpesaTill ?? this.serviceChargeMpesaTill,
        serviceChargeIsPaybill: serviceChargeIsPaybill ?? this.serviceChargeIsPaybill,
        serviceChargeMpesaAccountRef: serviceChargeMpesaAccountRef ?? this.serviceChargeMpesaAccountRef,
        serviceChargeNoteSent: serviceChargeNoteSent ?? this.serviceChargeNoteSent,
        rentSetupDone: rentSetupDone ?? this.rentSetupDone,
        rentDueDayOfMonth: rentDueDayOfMonth ?? this.rentDueDayOfMonth,
        rentAmount: rentAmount ?? this.rentAmount,
        rentLandlordName: rentLandlordName ?? this.rentLandlordName,
        rentPaymentStatus: rentPaymentStatus ?? this.rentPaymentStatus,
        rentLastPaidAt: rentLastPaidAt ?? this.rentLastPaidAt,
        rentMpesaTill: rentMpesaTill ?? this.rentMpesaTill,
        rentIsPaybill: rentIsPaybill ?? this.rentIsPaybill,
        rentMpesaAccountRef: rentMpesaAccountRef ?? this.rentMpesaAccountRef,
        rentNoteSent: rentNoteSent ?? this.rentNoteSent,
        payTvSetupDone: payTvSetupDone ?? this.payTvSetupDone,
        payTvProvider: payTvProvider ?? this.payTvProvider,
        payTvDueDayOfMonth: payTvDueDayOfMonth ?? this.payTvDueDayOfMonth,
        payTvMonthlyAmount: payTvMonthlyAmount ?? this.payTvMonthlyAmount,
        payTvPaymentStatus: payTvPaymentStatus ?? this.payTvPaymentStatus,
        payTvLastPaidAt: payTvLastPaidAt ?? this.payTvLastPaidAt,
        payTvMpesaTill: payTvMpesaTill ?? this.payTvMpesaTill,
        payTvIsPaybill: payTvIsPaybill ?? this.payTvIsPaybill,
        payTvMpesaAccountRef: payTvMpesaAccountRef ?? this.payTvMpesaAccountRef,
        isOwnerOnly: isOwnerOnly ?? this.isOwnerOnly,
        notes: notes ?? this.notes,
        usageLogs: usageLogs ?? this.usageLogs,
        updatedAt: DateTime.now(),
      );
}
