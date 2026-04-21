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

    // Seed default tasks if today has none yet
    final key = todayKey();
    final hasToday = _items.any((t) => t.dateKey == key);
    if (!hasToday) {
      const uuid = Uuid();
      final now = DateTime.now();
      for (var i = 0; i < kDefaultDailyTasks.length; i++) {
        _items.add(TaskItem(
          id: uuid.v4(),
          householdId: householdId,
          title: kDefaultDailyTasks[i],
          addedBy: 'owner',
          dateKey: key,
          // stagger creation times so sort order is stable
          createdAt: now.add(Duration(milliseconds: i)),
        ));
      }
    }

    _isLoading = false;
    notifyListeners();
    await _persist();
  }

  /// Add a task for today. [addedBy] should be 'owner' or 'manager'.
  Future<void> addTask(String title, String addedBy) async {
    if (_householdId == null || title.trim().isEmpty) return;
    const uuid = Uuid();
    _items.add(TaskItem(
      id: uuid.v4(),
      householdId: _householdId!,
      title: title.trim(),
      addedBy: addedBy,
      dateKey: todayKey(),
      createdAt: DateTime.now(),
    ));
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
