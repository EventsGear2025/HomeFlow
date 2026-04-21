import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/staff_schedule.dart';
import '../models/app_notification.dart';
import '../models/supply_item.dart';
import '../services/sync_service.dart';

class StaffProvider extends ChangeNotifier {
  StaffSchedule? _schedule;
  bool _isLoading = false;

  StaffSchedule? get schedule => _schedule;
  bool get isLoading => _isLoading;
  bool get isOnDuty => _schedule?.isOnDuty ?? true;

  Future<void> loadData(String householdId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final remote = await SyncService.fetchAll(
        'app_staff_schedule', householdId, StaffSchedule.fromJson);
    if (remote != null && remote.isNotEmpty) {
      _schedule = remote.first;
      await prefs.setString(
          'staff_schedule_$householdId', jsonEncode(_schedule!.toJson()));
    } else {
      final json = prefs.getString('staff_schedule_$householdId');
      if (json != null) {
        _schedule = StaffSchedule.fromJson(jsonDecode(json));
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateSchedule(
      StaffSchedule schedule, String householdId) async {
    _schedule = schedule;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'staff_schedule_$householdId', jsonEncode(schedule.toJson()));
    SyncService.upsertOne('app_staff_schedule', householdId, schedule.toJson());
  }
}

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadData(String householdId) async {
    final prefs = await SharedPreferences.getInstance();
    final remote = await SyncService.fetchAll(
        'app_notifications', householdId, AppNotification.fromJson);
    if (remote != null) {
      _notifications = remote;
      await prefs.setString('notifications_$householdId',
          jsonEncode(_notifications.map((n) => n.toJson()).toList()));
    } else {
      final json = prefs.getString('notifications_$householdId');
      if (json != null) {
        final List decoded = jsonDecode(json);
        _notifications =
            decoded.map((e) => AppNotification.fromJson(e)).toList();
      }
    }
    notifyListeners();
  }

  Future<void> addNotification(
      AppNotification notification, String householdId) async {
    _notifications.insert(0, notification);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notifications_$householdId',
        jsonEncode(_notifications.map((n) => n.toJson()).toList()));
    SyncService.upsertOne('app_notifications', householdId, notification.toJson());
  }

  Future<void> markAllRead(String householdId) async {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notifications_$householdId',
        jsonEncode(_notifications.map((n) => n.toJson()).toList()));
    SyncService.upsertAll('app_notifications', householdId,
        _notifications.map((n) => n.toJson()).toList());
  }

  Future<void> markSingleRead(String notificationId, String householdId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1 || _notifications[index].isRead) return;
    _notifications[index].isRead = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notifications_$householdId',
        jsonEncode(_notifications.map((n) => n.toJson()).toList()));
    SyncService.upsertOne('app_notifications', householdId,
        _notifications[index].toJson());
  }

  Future<void> clearAll(String householdId) async {
    _notifications.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notifications_$householdId');
  }

  void generateSupplyAlerts(List<dynamic> lowStockItems, String householdId) {
    const uuid = Uuid();
    for (final item in lowStockItems) {
      final exists = _notifications.any(
          (n) => n.type == 'supply_low' && n.body.contains(item.name));
      if (!exists) {
        _notifications.insert(
          0,
          AppNotification(
            id: uuid.v4(),
            householdId: householdId,
            type: 'supply_low',
            title: 'Supply Alert',
            body: '${item.name} is ${item.status.name.replaceAll('_', ' ')}',
            priority: item.status == SupplyStatus.finished
                ? NotificationPriority.critical
                : NotificationPriority.high,
            createdAt: DateTime.now(),
          ),
        );
      }
    }
    notifyListeners();
  }
}
