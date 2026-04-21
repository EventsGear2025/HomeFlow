import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/laundry_item.dart';
import '../services/sync_service.dart';

class LaundryProvider extends ChangeNotifier {
  List<LaundryItem> _items = [];
  bool _isLoading = false;

  List<LaundryItem> get items => _items;
  bool get isLoading => _isLoading;

  // ─── Basic filters ───────────────────────────────────────────────

  /// Items still in progress (not yet stored).
  List<LaundryItem> get activeItems =>
      _items.where((i) => !i.isStored).toList();

  /// Items that have been fully stored.
  List<LaundryItem> get storedItems =>
      _items.where((i) => i.isStored).toList();

  /// Group active items by bedroom.
  Map<String, List<LaundryItem>> get itemsByBedroom {
    final map = <String, List<LaundryItem>>{};
    for (final item in activeItems) {
      map.putIfAbsent(item.bedroom, () => []).add(item);
    }
    return map;
  }

  /// Total active loads across all bedrooms.
  int get totalActiveLoads =>
      activeItems.fold(0, (sum, i) => sum + i.numberOfLoads);

  // ─── Date helpers ────────────────────────────────────────────────

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  static DateTime _startOfWeek(DateTime d) {
    // Monday as start of week
    final day = d.weekday; // 1=Mon … 7=Sun
    return _startOfDay(d.subtract(Duration(days: day - 1)));
  }

  static DateTime _startOfMonth(DateTime d) =>
      DateTime(d.year, d.month, 1);

  // ─── Period stats ────────────────────────────────────────────────

  /// Loads started today.
  int get todayLoads {
    final start = _startOfDay(DateTime.now());
    return _items
        .where((i) => !i.createdAt.isBefore(start))
        .fold(0, (s, i) => s + i.numberOfLoads);
  }

  /// Loads started this week (Mon–today).
  int get weekLoads {
    final start = _startOfWeek(DateTime.now());
    return _items
        .where((i) => !i.createdAt.isBefore(start))
        .fold(0, (s, i) => s + i.numberOfLoads);
  }

  /// Loads started this month.
  int get monthLoads {
    final start = _startOfMonth(DateTime.now());
    return _items
        .where((i) => !i.createdAt.isBefore(start))
        .fold(0, (s, i) => s + i.numberOfLoads);
  }

  /// All-time total loads tracked.
  int get allTimeLoads =>
      _items.fold(0, (s, i) => s + i.numberOfLoads);

  // ─── Bedroom breakdown ───────────────────────────────────────────

  /// Loads per bedroom (all time, sorted highest first).
  List<MapEntry<String, int>> get loadsByBedroom {
    final map = <String, int>{};
    for (final item in _items) {
      map[item.bedroom] = (map[item.bedroom] ?? 0) + item.numberOfLoads;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Loads per bedroom this week.
  List<MapEntry<String, int>> get weekLoadsByBedroom {
    final start = _startOfWeek(DateTime.now());
    final map = <String, int>{};
    for (final item in _items.where((i) => !i.createdAt.isBefore(start))) {
      map[item.bedroom] = (map[item.bedroom] ?? 0) + item.numberOfLoads;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Loads per bedroom this month.
  List<MapEntry<String, int>> get monthLoadsByBedroom {
    final start = _startOfMonth(DateTime.now());
    final map = <String, int>{};
    for (final item in _items.where((i) => !i.createdAt.isBefore(start))) {
      map[item.bedroom] = (map[item.bedroom] ?? 0) + item.numberOfLoads;
    }
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  // ─── Daily trend (last 7 days) ────────────────────────────────

  /// Returns a list of (date label, load count) for each of the last 7 days.
  List<MapEntry<String, int>> get last7DaysTrend {
    final today = _startOfDay(DateTime.now());
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final next = day.add(const Duration(days: 1));
      final count = _items
          .where((item) =>
              !item.createdAt.isBefore(day) && item.createdAt.isBefore(next))
          .fold(0, (s, item) => s + item.numberOfLoads);
      final label = _dayLabel(day);
      return MapEntry(label, count);
    });
  }

  String _dayLabel(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  // ─── History (date-grouped) ──────────────────────────────────────

  /// All items grouped by their createdAt date, newest first.
  Map<DateTime, List<LaundryItem>> get historyByDate {
    final map = <DateTime, List<LaundryItem>>{};
    final sorted = [..._items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final item in sorted) {
      final day = _startOfDay(item.createdAt);
      map.putIfAbsent(day, () => []).add(item);
    }
    return map;
  }

  // ─── CRUD ────────────────────────────────────────────────────────

  Future<void> loadData(String householdId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final remote = await SyncService.fetchAll(
        'app_laundry_items', householdId, LaundryItem.fromJson);
    if (remote != null) {
      _items = remote;
      await prefs.setString('laundry_$householdId',
          jsonEncode(_items.map((i) => i.toJson()).toList()));
    } else {
      final json = prefs.getString('laundry_$householdId');
      if (json != null) {
        final List decoded = jsonDecode(json);
        _items = decoded.map((e) => LaundryItem.fromJson(e)).toList();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem(LaundryItem item, String householdId) async {
    _items.insert(0, item);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _save(householdId, prefs);
    SyncService.upsertOne('app_laundry_items', householdId, item.toJson());
  }

  Future<void> updateStage(
      String itemId, LaundryStage stage, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(
        stage: stage,
        storedAt: stage == LaundryStage.stored ? DateTime.now() : null,
      );
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await _save(householdId, prefs);
    }
  }

  /// Advance an item to its next stage in the workflow.
  Future<void> advanceStage(String itemId, String householdId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final next = _items[index].nextStage;
      if (next != null) {
        _items[index] = _items[index].copyWith(
          stage: next,
          storedAt: next == LaundryStage.stored ? DateTime.now() : null,
        );
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await _save(householdId, prefs);
      }
    }
  }

  /// Remove an item (clear it from list).
  Future<void> removeItem(String itemId, String householdId) async {
    _items.removeWhere((i) => i.id == itemId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await _save(householdId, prefs);
    SyncService.deleteOne('app_laundry_items', itemId);
  }

  Future<void> _save(String householdId, SharedPreferences prefs) async {
    await prefs.setString('laundry_$householdId',
        jsonEncode(_items.map((i) => i.toJson()).toList()));
    SyncService.upsertAll('app_laundry_items', householdId,
        _items.map((i) => i.toJson()).toList());
  }
}
