import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task_item.dart';
import '../services/sync_service.dart';

class TaskProvider extends ChangeNotifier {
  List<TaskItem> _items = [];
  bool _isLoading = false;
  String? _householdId;

  bool get isLoading => _isLoading;

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// All tasks for today, sorted by creation time.
  List<TaskItem> get todayTasks {
    final key = todayKey();
    return _items.where((t) => t.dateKey == key).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  int get todayDoneCount => todayTasks.where((t) => t.isDone).length;
  int get todayTotalCount => todayTasks.length;

  /// Tasks for an arbitrary date key (yyyy-MM-dd), sorted by creation time.
  List<TaskItem> tasksForDate(String dateKey) {
    return _items.where((t) => t.dateKey == dateKey).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// All distinct date keys that have at least one task, newest first.
  List<String> get availableDateKeys {
    final keys = _items.map((t) => t.dateKey).toSet().toList();
    keys.sort((a, b) => b.compareTo(a));
    return keys;
  }

  Future<void> loadData(String householdId) async {
    _householdId = householdId;
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final remote =
        await SyncService.fetchAll('app_tasks', householdId, TaskItem.fromJson);
    if (remote != null) {
      _items = remote;
      await prefs.setString('tasks_v1_$householdId',
          jsonEncode(_items.map((t) => t.toJson()).toList()));
    } else {
      final raw = prefs.getString('tasks_v1_$householdId');
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _items = list.map(TaskItem.fromJson).toList();
      }
    }

    // Prune tasks older than 30 days to avoid unbounded growth
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _items.removeWhere((t) => t.createdAt.isBefore(cutoff));

    // Seed today's tasks if none exist yet
    final key = todayKey();
    final hasToday = _items.any((t) => t.dateKey == key);
    if (!hasToday) {
      const uuid = Uuid();
      final now = DateTime.now();

      // 1. Seed the hardcoded default daily tasks
      for (var i = 0; i < kDefaultDailyTasks.length; i++) {
        _items.add(TaskItem(
          id: uuid.v4(),
          householdId: householdId,
          title: kDefaultDailyTasks[i],
          addedBy: 'owner',
          dateKey: key,
          createdAt: now.add(Duration(milliseconds: i)),
          isRecurring: true,
        ));
      }

      // 2. Carry over custom recurring tasks from any recent day
      final existingDefaultTitles =
          kDefaultDailyTasks.map((t) => t.toLowerCase()).toSet();
      final seen = <String>{}; // deduplicate by title
      // Look back up to 7 days for recurring custom tasks
      for (var daysBack = 1; daysBack <= 7; daysBack++) {
        final past = DateTime.now().subtract(Duration(days: daysBack));
        final pastKey =
            '${past.year}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}';
        final pastRecurring = _items.where((t) =>
            t.dateKey == pastKey &&
            t.isRecurring &&
            !existingDefaultTitles.contains(t.title.toLowerCase()) &&
            !seen.contains(t.title.toLowerCase()));
        for (final src in pastRecurring) {
          seen.add(src.title.toLowerCase());
          _items.add(TaskItem(
            id: uuid.v4(),
            householdId: householdId,
            title: src.title,
            addedBy: src.addedBy,
            dateKey: key,
            createdAt: now.add(Duration(milliseconds: kDefaultDailyTasks.length + seen.length)),
            isRecurring: true,
          ));
        }
      }
    }

    _isLoading = false;
    notifyListeners();
    await _persist();
  }

  /// Add a task for today. [addedBy] should be 'owner' or 'manager'.
  /// Set [isRecurring] to true to have the task reappear fresh every new day.
  Future<void> addTask(String title, String addedBy,
      {bool isRecurring = false}) async {
    if (_householdId == null || title.trim().isEmpty) return;
    const uuid = Uuid();
    _items.add(TaskItem(
      id: uuid.v4(),
      householdId: _householdId!,
      title: title.trim(),
      addedBy: addedBy,
      dateKey: todayKey(),
      createdAt: DateTime.now(),
      isRecurring: isRecurring,
    ));
    notifyListeners();
    await _persist();
  }

  /// Toggle the `isRecurring` flag on an existing task.
  Future<void> toggleRecurring(String id) async {
    final idx = _items.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _items[idx] =
        _items[idx].copyWith(isRecurring: !_items[idx].isRecurring);
    notifyListeners();
    await _persist();
  }

  Future<void> toggleTask(String id) async {
    final idx = _items.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(isDone: !_items[idx].isDone);
    notifyListeners();
    await _persist();
  }

  Future<void> removeTask(String id) async {
    _items.removeWhere((t) => t.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    if (_householdId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'tasks_v1_$_householdId',
      jsonEncode(_items.map((t) => t.toJson()).toList()),
    );
    SyncService.upsertAll('app_tasks', _householdId!,
        _items.map((t) => t.toJson()).toList());
  }
}
