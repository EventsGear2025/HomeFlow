import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/utility_tracker.dart';
import '../services/sync_service.dart';

class UtilityProvider extends ChangeNotifier {
  List<UtilityTracker> _items = [];
  bool _isLoading = false;

  List<UtilityTracker> get items => _items;
  bool get isLoading => _isLoading;

  /// Returns items visible to the current user.
  /// Owners see all; house managers see only non-owner-only items.
  List<UtilityTracker> visibleItems({required bool isOwner}) =>
      isOwner ? _items : _items.where((i) => !i.isOwnerOnly).toList();

  List<UtilityTracker> get gasItems =>
      _items.where((i) => i.type == UtilityType.cookingGas).toList();

  List<UtilityTracker> get electricityItems =>
      _items.where((i) => i.type == UtilityType.electricity).toList();

  List<UtilityTracker> get internetItems =>
      _items.where((i) => i.type == UtilityType.internet).toList();

  List<UtilityTracker> get waterItems =>
      _items.where((i) => i.type == UtilityType.water).toList();

  List<UtilityTracker> get waterBillItems =>
      _items.where((i) => i.type == UtilityType.waterBill).toList();

  List<UtilityTracker> get serviceChargeItems =>
      _items.where((i) => i.type == UtilityType.serviceCharge).toList();

  List<UtilityTracker> get rentItems =>
      _items.where((i) => i.type == UtilityType.rent).toList();

  List<UtilityTracker> get payTvItems =>
      _items.where((i) => i.type == UtilityType.payTv).toList();

  List<UtilityTracker> get lowAlertItems =>
      _items.where((i) => i.isLowAlert).toList();

  Future<void> loadData(String householdId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final remote = await SyncService.fetchAll(
        'app_utilities', householdId, UtilityTracker.fromJson);
    if (remote != null && remote.isNotEmpty) {
      _items = remote;
      await prefs.setString('utilities_$householdId',
          jsonEncode(_items.map((i) => i.toJson()).toList()));
    } else {
      final json = prefs.getString('utilities_$householdId');
      if (json != null) {
        final List decoded = jsonDecode(json);
        _items = decoded.map((e) => UtilityTracker.fromJson(e)).toList();
      } else {
        // Seed default utilities for new households
        await _seedDefaults(householdId, prefs);
        // Push seeded data to Supabase
        SyncService.upsertAll('app_utilities', householdId,
            _items.map((i) => i.toJson()).toList());
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _seedDefaults(
      String householdId, SharedPreferences prefs) async {
    const uuid = Uuid();
    _items = [
      UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.cookingGas,
        label: 'Kitchen Gas',
        cylinderSize: GasCylinderSize.kg13,
        lastRefilledAt: DateTime.now().subtract(const Duration(days: 14)),
        estimatedDurationDays: 42,
        updatedAt: DateTime.now(),
      ),
      UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.electricity,
        label: 'Main Electricity',
        electricitySetupDone: false,
        isPostpaid: false,
        unitsRemaining: 85,
        lastToppedUpAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now(),
      ),
      UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.water,
        label: 'Drinking Water',
        isDrinkingWater: true,
        waterSetupDone: true,
        containerSizeLitres: 18.5,
        totalContainers: 2,
        fullContainers: 1,
        emptyContainers: 1,
        reorderThreshold: 1,
        typicalOrderQuantity: 2,
        reorderFrequencyDays: 14,
        pricePerContainer: 450,
        lastDeliveredAt: DateTime.now().subtract(const Duration(days: 11)),
        paymentStatus: UtilityPaymentStatus.paid,
        lastPaidAt: DateTime.now().subtract(const Duration(days: 11)),
        supplier1: const GasSupplier(
          name: 'Jibu',
          phone: '+254700000000',
          mpesaName: 'Jibu Water',
          mpesaTill: '530530',
          isPaybill: false,
        ),
        notes: '2 x 18.5L bottles. Good default for a medium household.',
        updatedAt: DateTime.now(),
      ),
      UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.internet,
        label: 'Home Internet',
        internetSetupDone: false,
        updatedAt: DateTime.now(),
      ),
      UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.waterBill,
        label: 'Water Bill',
        waterBillSetupDone: false,
        updatedAt: DateTime.now(),
      ),
      UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.serviceCharge,
        label: 'Service Charge',
        serviceChargeSetupDone: false,
        updatedAt: DateTime.now(),
      ),
      UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.rent,
        label: 'Monthly Rent',
        rentSetupDone: false,
        updatedAt: DateTime.now(),
      ),
      UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.payTv,
        label: 'Pay TV',
        payTvSetupDone: false,
        updatedAt: DateTime.now(),
      ),
    ];
    await _save(householdId, prefs);
  }

  Future<void> addItem(UtilityTracker item, String householdId) async {
    _items.add(item);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _save(householdId, prefs);
  }

  Future<void> updateItem(UtilityTracker item, String householdId) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Manager flags that gas is running low.
  Future<void> flagGasLow(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(gasLowAlertSent: true);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Owner clears gas low alert after refilling.
  Future<void> clearGasLowAlert(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(gasLowAlertSent: false);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Mark a gas cylinder as just refilled right now.
  Future<void> markRefilled(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        lastRefilledAt: DateTime.now(),
        gasLowAlertSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Set up gas cylinder: kg size, brand, weeks it lasts, and when it was last refilled.
  Future<void> setupGas({
    required String itemId,
    required String householdId,
    required int cylinderKg,
    required int weeksItLasts,
    required DateTime lastRefilledAt,
    GasBrand? gasBrand,
    String? gasBrandCustom,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final brandName = (gasBrand == GasBrand.other && gasBrandCustom != null)
          ? gasBrandCustom
          : gasBrand?.displayName ?? '';
      final lbl = brandName.isNotEmpty
          ? '$brandName ${cylinderKg}kg'
          : '${cylinderKg}kg Gas Cylinder';
      _items[index] = _items[index].copyWith(
        cylinderKg: cylinderKg,
        gasBrand: gasBrand,
        gasBrandCustom: gasBrandCustom,
        estimatedDurationDays: weeksItLasts * 7,
        lastRefilledAt: lastRefilledAt,
        gasSetupDone: true,
        label: lbl,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Save supplier details for a gas tracker.
  Future<void> saveSuppliers({
    required String itemId,
    required String householdId,
    GasSupplier? supplier1,
    GasSupplier? supplier2,
    String? deliveryAddress,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        supplier1: supplier1,
        supplier2: supplier2,
        deliveryAddress: deliveryAddress,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Record a fresh refill (keeps existing kg/weeks settings, just resets refill date).
  Future<void> recordRefill(String itemId, String householdId,
      {DateTime? refilledAt}) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        lastRefilledAt: refilledAt ?? DateTime.now(),
        gasLowAlertSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Top up units (electricity / water).
  Future<void> topUp(
      String itemId, double unitsAdded, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final current = _items[index].unitsRemaining ?? 0;
      _items[index] = _items[index].copyWith(
        unitsRemaining: current + unitsAdded,
        tokenUnitsAdded: unitsAdded,
        lastToppedUpAt: DateTime.now(),
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Update units remaining manually (e.g. after reading the meter).
  Future<void> updateUnits(
      String itemId, double units, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(unitsRemaining: units);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> recordDrinkingWaterDelivery({
    required String itemId,
    required String householdId,
    int? quantityDelivered,
    DateTime? deliveredAt,
    UtilityPaymentStatus paymentStatus = UtilityPaymentStatus.unpaid,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _items[index];
      if (!item.isDrinkingWater) return;

      final total = item.totalContainers ?? 0;
      final delivered = quantityDelivered ?? item.typicalOrderQuantity ?? total;
      final normalizedDelivered = delivered > total ? total : delivered;

      _items[index] = item.copyWith(
        fullContainers: normalizedDelivered,
        emptyContainers: total - normalizedDelivered,
        lastDeliveredAt: deliveredAt ?? DateTime.now(),
        paymentStatus: paymentStatus,
        lastPaidAt: paymentStatus == UtilityPaymentStatus.paid ? DateTime.now() : item.lastPaidAt,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> markDrinkingWaterBottleEmpty(
      String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _items[index];
      if (!item.isDrinkingWater) return;
      final full = item.fullContainers ?? 0;
      final empty = item.emptyContainers ?? 0;
      if (full <= 0) return;

      _items[index] = item.copyWith(
        fullContainers: full - 1,
        emptyContainers: empty + 1,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> markDrinkingWaterPaid(
      String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _items[index];
      if (!item.isDrinkingWater) return;

      _items[index] = item.copyWith(
        paymentStatus: UtilityPaymentStatus.paid,
        lastPaidAt: DateTime.now(),
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Set up (or re-configure) a drinking-water tracker.
  Future<void> setupDrinkingWater({
    required String itemId,
    required String householdId,
    required double containerSizeLitres,
    required int totalContainers,
    required int fullContainers,
    required int reorderThreshold,
    required int typicalOrderQuantity,
    required int reorderFrequencyDays,
    required double pricePerContainer,
    GasSupplier? supplier1,
    String? deliveryAddress,
    String? notes,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _items[index];
      final empty = totalContainers - fullContainers;
      _items[index] = item.copyWith(
        label: 'Drinking Water',
        containerSizeLitres: containerSizeLitres,
        totalContainers: totalContainers,
        fullContainers: fullContainers,
        emptyContainers: empty < 0 ? 0 : empty,
        reorderThreshold: reorderThreshold,
        typicalOrderQuantity: typicalOrderQuantity,
        reorderFrequencyDays: reorderFrequencyDays,
        pricePerContainer: pricePerContainer,
        supplier1: supplier1,
        deliveryAddress: deliveryAddress,
        notes: notes,
        waterSetupDone: true,
        paymentStatus: item.paymentStatus ?? UtilityPaymentStatus.unpaid,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> removeItem(String itemId, String householdId) async {
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _save(householdId, prefs);
  }

  // ── Electricity methods ────────────────────────────────────────

  /// Set up (or reconfigure) the electricity tracker.
  Future<void> setupElectricity({
    required String itemId,
    required String householdId,
    required bool isPostpaid,
    // Prepaid fields
    double? currentUnits,
    double? typicalTokenAmount,
    // Postpaid fields
    int? billDueDayOfMonth,
    String? electricityPaybill,
    String? electricityAccountRef,
    String? notes,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        isPostpaid: isPostpaid,
        electricitySetupDone: true,
        electricityLowAlertSent: false,
        unitsRemaining: isPostpaid ? null : (currentUnits ?? _items[index].unitsRemaining),
        lastToppedUpAt: (!isPostpaid && currentUnits != null) ? DateTime.now() : _items[index].lastToppedUpAt,
        typicalTokenAmount: typicalTokenAmount,
        electricityBillDueDayOfMonth: isPostpaid ? billDueDayOfMonth : null,
        electricityPaybill: electricityPaybill,
        electricityAccountRef: electricityAccountRef,
        electricityPaymentStatus: isPostpaid ? UtilityPaymentStatus.unpaid : null,
        notes: notes,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Manager flags that prepaid tokens are running low.
  Future<void> alertElectricityLow(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(electricityLowAlertSent: true);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Mark electricity tokens as refilled (prepaid). Clears low alert.
  Future<void> markTokensRefilled(
      String itemId, String householdId, double unitsAdded) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        unitsRemaining: unitsAdded,
        tokenUnitsAdded: unitsAdded,
        lastToppedUpAt: DateTime.now(),
        electricityLowAlertSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Record postpaid electricity bill amount.
  Future<void> recordElectricityBill(
      String itemId, String householdId, double amount) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        lastBillAmount: amount,
        electricityPaymentStatus: UtilityPaymentStatus.unpaid,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Mark postpaid electricity bill as paid.
  Future<void> markElectricityBillPaid(
      String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        electricityPaymentStatus: UtilityPaymentStatus.paid,
        electricityLastPaidAt: DateTime.now(),
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  // ── Internet methods ───────────────────────────────────────────

  /// Set up (or reconfigure) the internet tracker.
  Future<void> setupInternet({
    required String itemId,
    required String householdId,
    required String ispName,
    required int dueDayOfMonth,
    required double monthlyAmount,
    String? mpesaTill,
    bool isPaybill = false,
    String? mpesaAccountRef,
    String? notes,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        label: '$ispName Internet',
        ispName: ispName,
        internetDueDayOfMonth: dueDayOfMonth,
        internetMonthlyAmount: monthlyAmount,
        internetMpesaTill: mpesaTill,
        internetIsPaybill: isPaybill,
        internetMpesaAccountRef: mpesaAccountRef,
        internetSetupDone: true,
        internetPaymentStatus: UtilityPaymentStatus.unpaid,
        notes: notes,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Mark the current internet billing cycle as paid.
  Future<void> markInternetPaid(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        internetPaymentStatus: UtilityPaymentStatus.paid,
        internetLastPaidAt: DateTime.now(),
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Reset internet payment to unpaid (e.g. new billing cycle starts).
  Future<void> resetInternetPayment(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        internetPaymentStatus: UtilityPaymentStatus.unpaid,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  // ── Water bill (mains/piped) methods ──────────────────────────

  Future<void> setupWaterBill({
    required String itemId,
    required String householdId,
    int? billDueDayOfMonth,
    double? monthlyAmount,
    String? mpesaTill,
    bool isPaybill = false,
    String? mpesaAccountRef,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        waterBillSetupDone: true,
        waterBillDueDayOfMonth: billDueDayOfMonth,
        waterBillAmount: monthlyAmount,
        waterBillMpesaTill: mpesaTill,
        waterBillIsPaybill: isPaybill,
        waterBillMpesaAccountRef: mpesaAccountRef,
        waterBillPaymentStatus: UtilityPaymentStatus.unpaid,
        waterBillNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> recordWaterBill(
      String itemId, String householdId, double amount) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        waterBillAmount: amount,
        waterBillPaymentStatus: UtilityPaymentStatus.unpaid,
        waterBillNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Manager flags that the water bill has arrived (notifies owner).
  Future<void> notifyWaterBillArrived(
      String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(waterBillNoteSent: true);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> markWaterBillPaid(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        waterBillPaymentStatus: UtilityPaymentStatus.paid,
        waterBillLastPaidAt: DateTime.now(),
        waterBillNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> resetWaterBillCycle(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        waterBillPaymentStatus: UtilityPaymentStatus.unpaid,
        waterBillNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  // ── Service / garbage charge methods ──────────────────────────

  Future<void> setupServiceCharge({
    required String itemId,
    required String householdId,
    int? billDueDayOfMonth,
    double? monthlyAmount,
    String? mpesaTill,
    bool isPaybill = false,
    String? mpesaAccountRef,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        serviceChargeSetupDone: true,
        serviceChargeDueDayOfMonth: billDueDayOfMonth,
        serviceChargeAmount: monthlyAmount,
        serviceChargeMpesaTill: mpesaTill,
        serviceChargeIsPaybill: isPaybill,
        serviceChargeMpesaAccountRef: mpesaAccountRef,
        serviceChargePaymentStatus: UtilityPaymentStatus.unpaid,
        serviceChargeNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> recordServiceChargeBill(
      String itemId, String householdId, double amount) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        serviceChargeAmount: amount,
        serviceChargePaymentStatus: UtilityPaymentStatus.unpaid,
        serviceChargeNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Manager flags that the service charge bill has arrived.
  Future<void> notifyServiceChargeArrived(
      String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(serviceChargeNoteSent: true);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> markServiceChargePaid(
      String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        serviceChargePaymentStatus: UtilityPaymentStatus.paid,
        serviceChargeLastPaidAt: DateTime.now(),
        serviceChargeNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> resetServiceChargeCycle(
      String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        serviceChargePaymentStatus: UtilityPaymentStatus.unpaid,
        serviceChargeNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  // ── Rent methods ───────────────────────────────────────────────

  Future<void> setupRent({
    required String itemId,
    required String householdId,
    int? billDueDayOfMonth,
    double? monthlyAmount,
    String? landlordName,
    String? mpesaTill,
    bool isPaybill = false,
    String? mpesaAccountRef,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        rentSetupDone: true,
        rentDueDayOfMonth: billDueDayOfMonth,
        rentAmount: monthlyAmount,
        rentLandlordName: landlordName,
        rentMpesaTill: mpesaTill,
        rentIsPaybill: isPaybill,
        rentMpesaAccountRef: mpesaAccountRef,
        rentPaymentStatus: UtilityPaymentStatus.unpaid,
        rentNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> markRentPaid(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        rentPaymentStatus: UtilityPaymentStatus.paid,
        rentLastPaidAt: DateTime.now(),
        rentNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> notifyRentDue(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(rentNoteSent: true);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> resetRentCycle(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        rentPaymentStatus: UtilityPaymentStatus.unpaid,
        rentNoteSent: false,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  // ── Pay TV methods ─────────────────────────────────────────────

  Future<void> setupPayTv({
    required String itemId,
    required String householdId,
    String? providerName,
    int? dueDayOfMonth,
    double? monthlyAmount,
    String? mpesaTill,
    bool isPaybill = false,
    String? mpesaAccountRef,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        payTvSetupDone: true,
        payTvProvider: providerName,
        payTvDueDayOfMonth: dueDayOfMonth,
        payTvMonthlyAmount: monthlyAmount,
        payTvMpesaTill: mpesaTill,
        payTvIsPaybill: isPaybill,
        payTvMpesaAccountRef: mpesaAccountRef,
        payTvPaymentStatus: UtilityPaymentStatus.unpaid,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> markPayTvPaid(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        payTvPaymentStatus: UtilityPaymentStatus.paid,
        payTvLastPaidAt: DateTime.now(),
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  Future<void> resetPayTvCycle(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        payTvPaymentStatus: UtilityPaymentStatus.unpaid,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Toggles the owner-only flag on a utility tracker item.
  Future<void> toggleOwnerOnly(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    _items[index] =
        _items[index].copyWith(isOwnerOnly: !_items[index].isOwnerOnly);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _save(householdId, prefs);
  }

  /// Append a usage entry (amount consumed) to a utility tracker.
  Future<void> logUtilityUsage(
    String itemId,
    double quantity,
    String householdId, {
    String? notes,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;
    final entry = UtilityUsageEntry(
      date: DateTime.now(),
      quantity: quantity,
      notes: notes,
    );
    _items[index] = _items[index].copyWith(
      usageLogs: [..._items[index].usageLogs, entry],
    );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _save(householdId, prefs);
  }

  Future<void> _save(String householdId, SharedPreferences prefs) async {
    await prefs.setString(
      'utilities_$householdId',
      jsonEncode(_items.map((i) => i.toJson()).toList()),
    );
    SyncService.upsertAll(
        'app_utilities', householdId, _items.map((i) => i.toJson()).toList());
  }
}
