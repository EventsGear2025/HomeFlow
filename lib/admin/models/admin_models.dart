import 'package:flutter/material.dart';

class AdminStat {
  const AdminStat({
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final Color color;
}

class AdminNavItem {
  const AdminNavItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

class HouseholdRow {
  const HouseholdRow({
    required this.householdId,
    required this.inviteCode,
    required this.name,
    required this.location,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.plan,
    required this.members,
    required this.children,
    required this.supplies,
    required this.zones,
    required this.status,
    required this.createdDate,
    required this.usage,
  });

  final String householdId;
  final String inviteCode;
  final String name;
  final String location;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String plan;
  final int members;
  final int children;
  final int supplies;
  final int zones;
  final String status;
  final String createdDate;
  final double usage;

  HouseholdRow copyWith({
    String? householdId,
    String? inviteCode,
    String? name,
    String? location,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhone,
    String? plan,
    int? members,
    int? children,
    int? supplies,
    int? zones,
    String? status,
    String? createdDate,
    double? usage,
  }) {
    return HouseholdRow(
      householdId: householdId ?? this.householdId,
      inviteCode: inviteCode ?? this.inviteCode,
      name: name ?? this.name,
      location: location ?? this.location,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      plan: plan ?? this.plan,
      members: members ?? this.members,
      children: children ?? this.children,
      supplies: supplies ?? this.supplies,
      zones: zones ?? this.zones,
      status: status ?? this.status,
      createdDate: createdDate ?? this.createdDate,
      usage: usage ?? this.usage,
    );
  }
}

class UserRow {
  const UserRow({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.household,
    required this.status,
    required this.plan,
    required this.createdAt,
    required this.lastActive,
  });

  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String household;
  final String status;
  final String plan;
  final String createdAt;
  final String lastActive;
}

class SubscriptionRow {
  const SubscriptionRow({
    required this.householdId,
    required this.household,
    required this.owner,
    required this.plan,
    required this.billingStatus,
    required this.maxBedrooms,
    required this.maxSupplies,
    required this.maxChildren,
    required this.bedroomUsage,
    required this.supplyUsage,
    required this.childUsage,
    required this.startedDate,
    required this.expiryDate,
  });

  final String householdId;
  final String household;
  final String owner;
  final String plan;
  final String billingStatus;
  final int maxBedrooms;
  final int maxSupplies;
  final int maxChildren;
  final int bedroomUsage;
  final int supplyUsage;
  final int childUsage;
  final String startedDate;
  final String expiryDate;
}

class SupportIssueRow {
  const SupportIssueRow({
    required this.title,
    required this.household,
    required this.user,
    required this.category,
    required this.priority,
    required this.status,
    required this.assignedAdmin,
    required this.createdAt,
  });

  final String title;
  final String household;
  final String user;
  final String category;
  final String priority;
  final String status;
  final String assignedAdmin;
  final String createdAt;
}

class ActivityLogRow {
  const ActivityLogRow({
    required this.user,
    required this.household,
    required this.action,
    required this.entity,
    required this.datetime,
    required this.metadata,
  });

  final String user;
  final String household;
  final String action;
  final String entity;
  final String datetime;
  final String metadata;
}

class PresetCategory {
  const PresetCategory({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  PresetCategory copyWith({
    String? title,
    List<String>? items,
  }) {
    return PresetCategory(
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }
}

class NotificationRow {
  const NotificationRow({
    required this.template,
    required this.user,
    required this.household,
    required this.type,
    required this.severity,
    required this.readState,
    required this.result,
  });

  final String template;
  final String user;
  final String household;
  final String type;
  final String severity;
  final String readState;
  final String result;
}

class AdminRoleRow {
  const AdminRoleRow({
    required this.name,
    required this.role,
    required this.scope,
    required this.lastActive,
    required this.status,
  });

  final String name;
  final String role;
  final String scope;
  final String lastActive;
  final String status;
}

class SettingsItem {
  const SettingsItem({
    required this.label,
    required this.value,
    required this.description,
  });

  final String label;
  final String value;
  final String description;
}

class AnalyticsMetric {
  const AnalyticsMetric({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;
}

class ModuleUsageMetric {
  const ModuleUsageMetric({
    required this.label,
    required this.current,
    this.max = 100,
  });

  final String label;
  final int current;
  final int max;
}

class AdminDetailItem {
  const AdminDetailItem({
    required this.title,
    required this.subtitle,
    this.status,
    this.meta,
    this.note,
  });

  final String title;
  final String subtitle;
  final String? status;
  final String? meta;
  final String? note;
}

class AdminHouseholdDetailData {
  const AdminHouseholdDetailData({
    required this.household,
    required this.members,
    required this.children,
    required this.supplies,
    required this.shopping,
    required this.meals,
    required this.laundry,
    required this.notifications,
    required this.billing,
    required this.activityLog,
  });

  final HouseholdRow household;
  final List<AdminDetailItem> members;
  final List<AdminDetailItem> children;
  final List<AdminDetailItem> supplies;
  final List<AdminDetailItem> shopping;
  final List<AdminDetailItem> meals;
  final List<AdminDetailItem> laundry;
  final List<AdminDetailItem> notifications;
  final List<AdminDetailItem> billing;
  final List<AdminDetailItem> activityLog;

  AdminHouseholdDetailData copyWith({
    HouseholdRow? household,
    List<AdminDetailItem>? members,
    List<AdminDetailItem>? children,
    List<AdminDetailItem>? supplies,
    List<AdminDetailItem>? shopping,
    List<AdminDetailItem>? meals,
    List<AdminDetailItem>? laundry,
    List<AdminDetailItem>? notifications,
    List<AdminDetailItem>? billing,
    List<AdminDetailItem>? activityLog,
  }) {
    return AdminHouseholdDetailData(
      household: household ?? this.household,
      members: members ?? this.members,
      children: children ?? this.children,
      supplies: supplies ?? this.supplies,
      shopping: shopping ?? this.shopping,
      meals: meals ?? this.meals,
      laundry: laundry ?? this.laundry,
      notifications: notifications ?? this.notifications,
      billing: billing ?? this.billing,
      activityLog: activityLog ?? this.activityLog,
    );
  }

  List<AdminDetailItem> itemsForTab(String tab) {
    switch (tab) {
      case 'Members':
        return members;
      case 'Children':
        return children;
      case 'Supplies':
        return supplies;
      case 'Shopping':
        return shopping;
      case 'Meals':
        return meals;
      case 'Laundry':
        return laundry;
      case 'Notifications':
        return notifications;
      case 'Billing':
        return billing;
      case 'Activity log':
        return activityLog;
      default:
        return const [];
    }
  }
}
