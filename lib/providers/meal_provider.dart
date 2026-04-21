import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_log.dart';
import '../models/child_model.dart';
import '../services/sync_service.dart';

class MealProvider extends ChangeNotifier {
  List<MealLog> _mealLogs = [];
  bool _isLoading = false;

  List<MealLog> get mealLogs => _isLoading ? [] : _mealLogs;
  bool get isLoading => _isLoading;

  List<MealLog> getTodaysMeals() {
    final today = DateTime.now();
    return _mealLogs.where((m) {
      return m.date.year == today.year &&
          m.date.month == today.month &&
          m.date.day == today.day;
    }).toList();
  }

  List<MealLog> getMealsForDate(DateTime date) {
    return _mealLogs.where((m) {
      return m.date.year == date.year &&
          m.date.month == date.month &&
          m.date.day == date.day;
    }).toList();
  }

  bool hasMealLoggedForPeriod(String period) {
    final today = getTodaysMeals();
    return today.any((m) => m.mealPeriod == period);
  }

  // ── ANALYTICS ─────────────────────────────────────────────────────────────

  /// Returns logs within the last [days] days (inclusive of today).
  List<MealLog> logsInLastDays(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days - 1));
    final cutoffDay = DateTime(cutoff.year, cutoff.month, cutoff.day);
    return _mealLogs.where((m) {
      final d = DateTime(m.date.year, m.date.month, m.date.day);
      return !d.isBefore(cutoffDay);
    }).toList();
  }

  /// Returns logs within the calendar month of [month].
  List<MealLog> logsInMonth(DateTime month) {
    return _mealLogs.where((m) =>
        m.date.year == month.year && m.date.month == month.month).toList();
  }

  /// Counts how many times each nutrition tag appears across [logs].
  Map<String, int> nutritionFrequency(List<MealLog> logs) {
    final counts = <String, int>{};
    for (final log in logs) {
      for (final tag in log.nutritionTags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Counts individual food occurrences across [logs], sorted descending.
  List<MapEntry<String, int>> topFoods(List<MealLog> logs, {int limit = 8}) {
    final counts = <String, int>{};
    for (final log in logs) {
      for (final food in log.selectedFoods) {
        counts[food] = (counts[food] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Per-day nutrition tag counts for the last [days] days.
  /// Returns a list of {date, tagCounts} maps, one per day, ordered oldest→newest.
  List<Map<String, dynamic>> dailyNutritionBreakdown(int days) {
    final result = <Map<String, dynamic>>[];
    final today = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final logs = getMealsForDate(day);
      final freq = nutritionFrequency(logs);
      result.add({'date': day, 'counts': freq});
    }
    return result;
  }

  /// Weekly summary convenience getter.
  Map<String, int> get weeklyNutritionFrequency =>
      nutritionFrequency(logsInLastDays(7));

  /// Monthly summary convenience getter (current month).
  Map<String, int> get monthlyNutritionFrequency =>
      nutritionFrequency(logsInMonth(DateTime.now()));

  /// Top foods this week.
  List<MapEntry<String, int>> get weeklyTopFoods =>
      topFoods(logsInLastDays(7));

  /// Top foods this month.
  List<MapEntry<String, int>> get monthlyTopFoods =>
      topFoods(logsInMonth(DateTime.now()));

  // ── DATA OPS ──────────────────────────────────────────────────────────────

  Future<void> loadData(String householdId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final remote = await SyncService.fetchAll(
        'app_meal_logs', householdId, MealLog.fromJson);
    if (remote != null) {
      _mealLogs = remote;
      await prefs.setString('meals_$householdId',
          jsonEncode(_mealLogs.map((m) => m.toJson()).toList()));
    } else {
      final json = prefs.getString('meals_$householdId');
      if (json != null) {
        final List decoded = jsonDecode(json);
        _mealLogs = decoded.map((e) => MealLog.fromJson(e)).toList();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addMealLog(MealLog log, String householdId) async {
    _mealLogs.insert(0, log);
    notifyListeners();
    await _save(householdId);
    SyncService.upsertOne('app_meal_logs', householdId, log.toJson());
  }

  Future<void> deleteMealLog(String id, String householdId) async {
    _mealLogs.removeWhere((m) => m.id == id);
    notifyListeners();
    await _save(householdId);
    SyncService.deleteOne('app_meal_logs', id);
  }

  Future<void> _save(String householdId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meals_$householdId',
        jsonEncode(_mealLogs.map((m) => m.toJson()).toList()));
  }
}

class ChildProvider extends ChangeNotifier {
  List<ChildModel> _children = [];
  List<ChildRoutineLog> _routineLogs = [];
  bool _isLoading = false;

  List<ChildModel> get children => _children;
  bool get isLoading => _isLoading;

  ChildRoutineLog? getTodaysLog(String childId) {
    final today = DateTime.now();
    try {
      return _routineLogs.firstWhere((l) =>
          l.childId == childId &&
          l.date.year == today.year &&
          l.date.month == today.month &&
          l.date.day == today.day);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadData(String householdId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final remoteChildren = await SyncService.fetchAll(
        'app_children', householdId, ChildModel.fromJson);
    final remoteLogs = await SyncService.fetchAll(
        'app_child_logs', householdId, ChildRoutineLog.fromJson);

    if (remoteChildren != null) {
      _children = remoteChildren;
      await prefs.setString('children_$householdId',
          jsonEncode(_children.map((c) => c.toJson()).toList()));
    } else {
      final childrenJson = prefs.getString('children_$householdId');
      if (childrenJson != null) {
        final List decoded = jsonDecode(childrenJson);
        _children = decoded.map((e) => ChildModel.fromJson(e)).toList();
      }
    }

    if (remoteLogs != null) {
      _routineLogs = remoteLogs;
      await prefs.setString('child_logs_$householdId',
          jsonEncode(_routineLogs.map((l) => l.toJson()).toList()));
    } else {
      final logsJson = prefs.getString('child_logs_$householdId');
      if (logsJson != null) {
        final List decoded = jsonDecode(logsJson);
        _routineLogs = decoded.map((e) => ChildRoutineLog.fromJson(e)).toList();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addChild(ChildModel child, String householdId) async {
    _children.add(child);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('children_$householdId',
        jsonEncode(_children.map((c) => c.toJson()).toList()));
    SyncService.upsertOne('app_children', householdId, child.toJson());
  }

  Future<void> updateChild(ChildModel child, String householdId) async {
    final index = _children.indexWhere((c) => c.id == child.id);
    if (index == -1) return;
    _children[index] = child;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('children_$householdId',
        jsonEncode(_children.map((c) => c.toJson()).toList()));
    SyncService.upsertOne('app_children', householdId, child.toJson());
  }

  Future<void> deleteChild(String childId, String householdId) async {
    _children.removeWhere((c) => c.id == childId);
    _routineLogs.removeWhere((l) => l.childId == childId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('children_$householdId',
        jsonEncode(_children.map((c) => c.toJson()).toList()));
    await prefs.setString('child_logs_$householdId',
        jsonEncode(_routineLogs.map((l) => l.toJson()).toList()));
    SyncService.deleteOne('app_children', childId);
  }

  Future<void> updateRoutineLog(
      ChildRoutineLog log, String householdId) async {
    final index =
        _routineLogs.indexWhere((l) => l.id == log.id);
    if (index != -1) {
      _routineLogs[index] = log;
    } else {
      _routineLogs.insert(0, log);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('child_logs_$householdId',
        jsonEncode(_routineLogs.map((l) => l.toJson()).toList()));
    SyncService.upsertOne('app_child_logs', householdId, log.toJson());
  }
}
