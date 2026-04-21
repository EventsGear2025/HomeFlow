import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/supply_item.dart';
import '../models/shopping_request.dart';
import '../services/sync_service.dart';
import '../utils/app_constants.dart';

class SupplyProvider extends ChangeNotifier {
  List<SupplyItem> _supplies = [];
  List<ShoppingRequest> _shoppingRequests = [];
  bool _isLoading = false;

  List<SupplyItem> get supplies => _supplies;

  /// Returns supplies visible to the current user.
  /// Owners see everything; house managers see only non-owner-only items.
  List<SupplyItem> visibleSupplies({required bool isOwner}) =>
      isOwner ? _supplies : _supplies.where((s) => !s.isOwnerOnly).toList();
  List<ShoppingRequest> get shoppingRequests => _shoppingRequests;
  bool get isLoading => _isLoading;

  List<SupplyItem> get lowStockItems => _supplies
      .where((s) => s.needsAttention)
      .toList();

  /// Supplies currently marked as finished — the auto shopping list.
  List<SupplyItem> get finishedSupplies =>
      _supplies.where((s) => s.status == SupplyStatus.finished).toList();

  List<SupplyItem> get gasItems =>
      _supplies.where((s) => s.isGas).toList();

  List<ShoppingRequest> get pendingRequests => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.managerRequest &&
          (r.status == ShoppingStatus.requested ||
              r.status == ShoppingStatus.seen))
      .toList();

  List<ShoppingRequest> get approvedRequests => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.managerRequest &&
          r.status == ShoppingStatus.approved)
      .toList();

  /// Owner's personal buy list (no approval needed).
  List<ShoppingRequest> get ownerBuyList => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.ownerPurchase &&
          r.status != ShoppingStatus.purchased &&
          r.status != ShoppingStatus.deferred)
      .toList();

  /// Deferred items — postponed, revisit when money/time allows.
  List<ShoppingRequest> get deferredRequests => _shoppingRequests
      .where((r) => r.status == ShoppingStatus.deferred)
      .toList();

  /// All completed / historical entries (purchased + direct-buys only).
  List<ShoppingRequest> get historyRequests => _shoppingRequests
      .where((r) =>
          r.status == ShoppingStatus.purchased ||
          r.purchaseType == PurchaseType.managerDirectBuy)
      .toList();

  /// Manager direct-buy entries that the owner hasn't acknowledged yet.
  List<ShoppingRequest> get unacknowledgedDirectBuys => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.managerDirectBuy &&
          r.status != ShoppingStatus.purchased)
      .toList();

  Future<void> loadData(String householdId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    // Try Supabase first; fall back to local cache on any error
    final remoteSupplies = await SyncService.fetchAll(
      'app_supplies', householdId, SupplyItem.fromJson);
    final remoteRequests = await SyncService.fetchAll(
      'app_shopping_requests', householdId, ShoppingRequest.fromJson);

    if (remoteSupplies != null) {
      _supplies = remoteSupplies;
      await prefs.setString('supplies_$householdId',
          jsonEncode(_supplies.map((s) => s.toJson()).toList()));
    } else {
      final suppliesJson = prefs.getString('supplies_$householdId');
      if (suppliesJson != null) {
        final List decoded = jsonDecode(suppliesJson);
        _supplies = decoded.map((e) => SupplyItem.fromJson(e)).toList();
      } else {
        _supplies = [];
      }
    }

    if (remoteRequests != null) {
      _shoppingRequests = remoteRequests;
      await prefs.setString('shopping_requests_$householdId',
          jsonEncode(_shoppingRequests.map((r) => r.toJson()).toList()));
    } else {
      final requestsJson = prefs.getString('shopping_requests_$householdId');
      if (requestsJson != null) {
        final List decoded = jsonDecode(requestsJson);
        _shoppingRequests =
            decoded.map((e) => ShoppingRequest.fromJson(e)).toList();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _seedStarterSupplies(
      String householdId, SharedPreferences prefs) async {
    const uuid = Uuid();
    _supplies = AppConstants.starterSupplies.map((item) {
      final isGas = item['name'].toString().contains('Gas');
      return SupplyItem(
        id: uuid.v4(),
        householdId: householdId,
        name: item['name'],
        category: item['category'],
        unitType: item['unit'],
        status: SupplyStatus.enough,
        isGas: isGas,
        expectedDurationDays: isGas ? 42 : null,
      );
    }).toList();

    await _saveSupplies(householdId, prefs);
  }

  Future<void> updateSupplyStatus(
      String supplyId, SupplyStatus status, String householdId,
      {String? updatedByName}) async {
    final index = _supplies.indexWhere((s) => s.id == supplyId);
    if (index != -1) {
      _supplies[index] = _supplies[index].copyWith(
        status: status,
        lastRestockedAt:
            status == SupplyStatus.enough ? DateTime.now() : null,
        statusUpdatedAt: DateTime.now(),
        statusUpdatedByName: updatedByName,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _saveSupplies(householdId, prefs);
    }
  }

  Future<void> addSupplyItem(SupplyItem item, String householdId) async {
    _supplies.add(item);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveSupplies(householdId, prefs);
  }

  Future<void> addShoppingRequest(
      ShoppingRequest request, String householdId) async {
    _shoppingRequests.insert(0, request);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveRequests(householdId, prefs);
  }

  Future<void> updateRequestStatus(
      String requestId, ShoppingStatus status, String householdId,
      {String? approvedByUserId}) async {
    final index = _shoppingRequests.indexWhere((r) => r.id == requestId);
    if (index != -1) {
      _shoppingRequests[index] = _shoppingRequests[index]
          .copyWith(status: status, approvedByUserId: approvedByUserId);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _saveRequests(householdId, prefs);
    }
  }

  /// Replaces an existing request in-place (used for Buy Anyway conversion).
  Future<void> replaceRequest(
      ShoppingRequest updated, String householdId) async {
    final index =
        _shoppingRequests.indexWhere((r) => r.id == updated.id);
    if (index != -1) {
      _shoppingRequests[index] = updated;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _saveRequests(householdId, prefs);
    }
  }

  /// Marks a supply as restocked (enough) — called when item is bought.
  Future<void> markSupplyRestocked(
      String supplyId, String householdId) async {
    await updateSupplyStatus(supplyId, SupplyStatus.enough, householdId);
  }

  /// Appends a usage entry to an item. Optional — does not affect status.
  Future<void> logUsage(
      String supplyId, double quantity, String householdId,
      {String? notes, double? price, String? loggedByName}) async {
    final index = _supplies.indexWhere((s) => s.id == supplyId);
    if (index == -1) return;
    final entry = SupplyUsageEntry(
      date: DateTime.now(),
      quantity: quantity,
      notes: notes,
      price: price,
      loggedByName: loggedByName,
    );
    _supplies[index] = _supplies[index].copyWith(
      usageLogs: [..._supplies[index].usageLogs, entry],
    );
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveSupplies(householdId, prefs);
  }

  /// Moves a deferred request back to active (requested) for revisiting.
  Future<void> revisitRequest(
      String requestId, String householdId) async {
    await updateRequestStatus(
        requestId, ShoppingStatus.requested, householdId);
  }

  /// Toggles the owner-only flag on a supply item.
  Future<void> toggleOwnerOnly(String supplyId, String householdId) async {
    final index = _supplies.indexWhere((s) => s.id == supplyId);
    if (index == -1) return;
    _supplies[index] =
        _supplies[index].copyWith(isOwnerOnly: !_supplies[index].isOwnerOnly);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _saveSupplies(householdId, prefs);
  }

  Future<void> _saveSupplies(
      String householdId, SharedPreferences prefs) async {
    await prefs.setString('supplies_$householdId',
        jsonEncode(_supplies.map((s) => s.toJson()).toList()));
    SyncService.upsertAll('app_supplies', householdId,
        _supplies.map((s) => s.toJson()).toList());
  }

  Future<void> _saveRequests(
      String householdId, SharedPreferences prefs) async {
    await prefs.setString('shopping_requests_$householdId',
        jsonEncode(_shoppingRequests.map((r) => r.toJson()).toList()));
    SyncService.upsertAll('app_shopping_requests', householdId,
        _shoppingRequests.map((r) => r.toJson()).toList());
  }
}
