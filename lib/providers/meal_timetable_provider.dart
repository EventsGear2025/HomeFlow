import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/meal_timetable_entry.dart';
import '../services/sync_service.dart';

class MealTimetableProvider extends ChangeNotifier {
  List<MealTimetableEntry> _entries = [];
  bool _isLoading = false;
  String? _householdId;

  bool get isLoading => _isLoading;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadData(String householdId) async {
    if (_householdId == householdId && _entries.isNotEmpty) return;
    _householdId = householdId;
    _isLoading = true;
    notifyListeners();
    try {
      final remote = await SyncService.fetchAll(
          'app_meal_timetable', householdId, MealTimetableEntry.fromJson);
      if (remote != null) {
        _entries = remote;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'meal_timetable_v1_$householdId',
          jsonEncode(_entries.map((e) => e.toJson()).toList()),
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('meal_timetable_v1_$householdId');
        if (raw != null) {
          final list = jsonDecode(raw) as List;
          _entries = list
              .map((e) =>
                  MealTimetableEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  List<MealTimetableEntry> getEntriesForWeek(String weekKey) =>
      _entries.where((e) => e.weekKey == weekKey).toList();

  List<MealTimetableEntry> getEntriesForDay(
          String weekKey, int dayOfWeek) =>
      _entries
          .where(
              (e) => e.weekKey == weekKey && e.dayOfWeek == dayOfWeek)
          .toList();

  MealTimetableEntry? getEntry(
          String weekKey, int dayOfWeek, String mealPeriod) =>
      _entries
          .where((e) =>
              e.weekKey == weekKey &&
              e.dayOfWeek == dayOfWeek &&
              e.mealPeriod == mealPeriod)
          .firstOrNull;

  bool hasAnyForDay(String weekKey, int dayOfWeek) =>
      _entries.any(
          (e) => e.weekKey == weekKey && e.dayOfWeek == dayOfWeek);

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> setEntry({
    required String householdId,
    required String weekKey,
    required int dayOfWeek,
    required String mealPeriod,
    required List<String> mealItems,
    String? notes,
  }) async {
    final existing = getEntry(weekKey, dayOfWeek, mealPeriod);
    if (existing != null) {
      final idx = _entries.indexOf(existing);
      _entries[idx] =
          existing.copyWith(mealItems: mealItems, notes: notes);
    } else {
      _entries.add(MealTimetableEntry(
        id: const Uuid().v4(),
        householdId: householdId,
        weekKey: weekKey,
        dayOfWeek: dayOfWeek,
        mealPeriod: mealPeriod,
        mealItems: mealItems,
        notes: notes,
        createdAt: DateTime.now(),
      ));
    }
    notifyListeners();
    await _persist(householdId);
  }

  Future<void> removeEntry(String id, String householdId) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persist(householdId);
    SyncService.deleteOne('app_meal_timetable', id);
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _persist(String householdId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'meal_timetable_v1_$householdId',
        jsonEncode(_entries.map((e) => e.toJson()).toList()),
      );
      SyncService.upsertAll('app_meal_timetable', householdId,
          _entries.map((e) => e.toJson()).toList());
    } catch (_) {}
  }
}
