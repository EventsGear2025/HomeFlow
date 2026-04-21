import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final auth = context.read<AuthProvider>();
    final notifications = notifProvider.notifications;
    final householdId = auth.household?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (val) {
                if (val == 'read_all') {
                  notifProvider.markAllRead(householdId);
                } else if (val == 'clear_all') {
                  notifProvider.clearAll(householdId);
                }
              },
              itemBuilder: (_) => [
                if (notifProvider.unreadCount > 0)
                  const PopupMenuItem(
                    value: 'read_all',
                    child: Row(children: [
                      Icon(Icons.done_all, size: 18, color: AppColors.primaryTeal),
                      SizedBox(width: 10),
                      Text('Mark all as read'),
                    ]),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.accentOrange),
                    SizedBox(width: 10),
                    Text('Clear all'),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications yet',
              subtitle: 'Alerts about your household will appear here',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationCard(
                  notification: notifications[i],
                  householdId: householdId,
                ),
              ),
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String householdId;
  const _NotificationCard({
    required this.notification,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return GestureDetector(
      onTap: () {
        if (isUnread) {
          context
              .read<NotificationProvider>()
              .markSingleRead(notification.id, householdId);
        }
      },
      child: HomeFlowCard(
        borderColor: isUnread
            ? AppColors.primaryTeal.withValues(alpha: 0.3)
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _iconBgColor(notification.priority),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _icon(notification.type),
                color: _iconColor(notification.priority),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight:
                          isUnread ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(notification.body,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryTeal,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _iconBgColor(NotificationPriority p) {
    switch (p) {
      case NotificationPriority.critical:
        return AppColors.statusFinished;
      case NotificationPriority.high:
        return AppColors.statusVeryLow;
      case NotificationPriority.normal:
        return AppColors.surfaceLight;
    }
  }

  Color _iconColor(NotificationPriority p) {
    switch (p) {
      case NotificationPriority.critical:
        return AppColors.statusFinishedText;
      case NotificationPriority.high:
        return AppColors.accentOrange;
      case NotificationPriority.normal:
        return AppColors.textSecondary;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'supply_low':
        return Icons.inventory_2_outlined;
      case 'laundry':
        return Icons.local_laundry_service_outlined;
      case 'shopping':
        return Icons.shopping_cart_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'gas':
        return Icons.local_fire_department_outlined;
      case 'utility':
        return Icons.bolt_outlined;
      case 'water':
        return Icons.water_drop_outlined;
      case 'internet':
        return Icons.wifi_outlined;
      case 'service_charge':
        return Icons.cleaning_services_outlined;
      case 'shopping_request':
        return Icons.add_shopping_cart_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}
