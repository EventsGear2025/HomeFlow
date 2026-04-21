enum NotificationPriority { normal, high, critical }

class AppNotification {
  final String id;
  final String householdId;
  final String type;
  final String title;
  final String body;
  final NotificationPriority priority;
  final String? targetUserId;
  bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.householdId,
    required this.type,
    required this.title,
    required this.body,
    required this.priority,
    this.targetUserId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'type': type,
        'title': title,
        'body': body,
        'priority': priority.name,
        'targetUserId': targetUserId,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        householdId: json['householdId'],
        type: json['type'],
        title: json['title'],
        body: json['body'],
        priority: NotificationPriority.values
            .firstWhere((p) => p.name == json['priority'],
                orElse: () => NotificationPriority.normal),
        targetUserId: json['targetUserId'],
        isRead: json['isRead'] ?? false,
        createdAt: DateTime.parse(json['createdAt']),
      );
}
