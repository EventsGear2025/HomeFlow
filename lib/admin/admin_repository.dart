import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import '../models/child_model.dart';
import '../models/laundry_item.dart';
import '../models/meal_log.dart';
import '../models/shopping_request.dart';
import '../models/supply_item.dart';
import '../models/task_item.dart';
import '../services/supabase_service.dart';
import '../utils/app_constants.dart';
import 'admin_mock_data.dart';
import 'models/admin_models.dart';

class AdminDashboardData {
  const AdminDashboardData({
    required this.stats,
    required this.trendData,
    required this.momentumInsights,
    required this.moduleUsage,
    required this.analyticsMetrics,
    required this.activityLogs,
    required this.notificationRows,
    required this.adminUsers,
    required this.alerts,
    required this.failedJobs,
    required this.notificationTemplates,
  });

  final List<AdminStat> stats;
  final List<double> trendData;
  final List<AnalyticsMetric> momentumInsights;
  final List<ModuleUsageMetric> moduleUsage;
  final List<AnalyticsMetric> analyticsMetrics;
  final List<ActivityLogRow> activityLogs;
  final List<NotificationRow> notificationRows;
  final List<AdminRoleRow> adminUsers;
  final List<SystemAlertRow> alerts;
  final List<FailedJobRow> failedJobs;
  final List<TemplateSummaryRow> notificationTemplates;
}

class SystemAlertRow {
  const SystemAlertRow({
    required this.title,
    required this.body,
    required this.severity,
    required this.status,
    required this.createdAt,
  });

  final String title;
  final String body;
  final String severity;
  final String status;
  final String createdAt;
}

class FailedJobRow {
  const FailedJobRow({
    required this.jobKey,
    required this.jobType,
    required this.status,
    required this.retryCount,
    required this.errorMessage,
    required this.createdAt,
  });

  final String jobKey;
  final String jobType;
  final String status;
  final int retryCount;
  final String errorMessage;
  final String createdAt;
}

class TemplateSummaryRow {
  const TemplateSummaryRow({
    required this.name,
    required this.channel,
    required this.severity,
    required this.isActive,
  });

  final String name;
  final String channel;
  final String severity;
  final bool isActive;
}

class _TimedActivityLogRow {
  const _TimedActivityLogRow({
    required this.eventAt,
    required this.row,
  });

  final DateTime eventAt;
  final ActivityLogRow row;
}

class AdminPlanActionResult {
  const AdminPlanActionResult({
    required this.success,
    required this.message,
    this.requiresBackendSetup = false,
  });

  final bool success;
  final String message;
  final bool requiresBackendSetup;
}

class AdminHouseholdMutationResult {
  const AdminHouseholdMutationResult({
    required this.success,
    required this.message,
    this.householdId,
    this.inviteCode,
    this.requiresBackendSetup = false,
  });

  final bool success;
  final String message;
  final String? householdId;
  final String? inviteCode;
  final bool requiresBackendSetup;
}

class _ActivitySource {
  const _ActivitySource({
    required this.label,
    required this.table,
    required this.timestampField,
  });

  final String label;
  final String table;
  final String timestampField;
}

const _dashboardActivitySources = <_ActivitySource>[
  _ActivitySource(label: 'Supplies', table: 'app_supplies', timestampField: 'updated_at'),
  _ActivitySource(label: 'Shopping', table: 'app_shopping_requests', timestampField: 'updated_at'),
  _ActivitySource(label: 'Meals', table: 'app_meal_logs', timestampField: 'updated_at'),
  _ActivitySource(label: 'Laundry', table: 'app_laundry_items', timestampField: 'updated_at'),
  _ActivitySource(label: 'Notifications', table: 'app_notifications', timestampField: 'updated_at'),
  _ActivitySource(label: 'Upgrade requests', table: 'app_upgrade_requests', timestampField: 'created_at'),
];

class _HouseholdMetrics {
  const _HouseholdMetrics({
    required this.householdId,
    required this.inviteCode,
    required this.householdName,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.planLabel,
    required this.planStatus,
    required this.billingStatus,
    required this.members,
    required this.children,
    required this.supplies,
    required this.zones,
    required this.maxBedrooms,
    required this.maxSupplies,
    required this.maxChildren,
    required this.createdDate,
    required this.expiryDate,
    required this.planExpiresAt,
    required this.usage,
  });

  final String householdId;
  final String inviteCode;
  final String householdName;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String planLabel;
  final String planStatus;
  final String billingStatus;
  final int members;
  final int children;
  final int supplies;
  final int zones;
  final int maxBedrooms;
  final int maxSupplies;
  final int maxChildren;
  final String createdDate;
  final String expiryDate;
  final DateTime? planExpiresAt;
  final double usage;
}

class AdminRepository {
  const AdminRepository();

  Future<AdminDashboardData> loadDashboardData() async {
    try {
      final householdMetrics = await _loadHouseholdMetrics();
      final activityRows = await _loadActivityRows(_dashboardActivitySources);
      final failedJobs = await _guard(fetchFailedJobs, const <FailedJobRow>[]);
      final stats = await _guard(
        () => _loadStats(householdMetrics, activityRows),
        AdminMockData.stats,
      );
      final activityLogs = await _guard(
        fetchActivityLogs,
        AdminMockData.activityLogs,
      );
      final notificationRows = await _guard(
        fetchNotificationRows,
        AdminMockData.notificationRows,
      );
      final adminUsers = await _guard(
        fetchAdminUsers,
        AdminMockData.adminUsers,
      );
      final alerts = await _guard(
        fetchSystemAlerts,
        const <SystemAlertRow>[],
      );
      final templates = await _guard(
        fetchNotificationTemplates,
        const <TemplateSummaryRow>[],
      );
      final trendData = _loadTrendData(activityRows);
      final momentumInsights = await _guard(
        () => _loadMomentumInsights(householdMetrics, activityRows, failedJobs),
        AdminMockData.dashboardMomentumInsights,
      );
      final moduleUsage = _loadModuleUsage(activityRows);
      final analyticsMetrics = await _guard(
        () => _loadAnalyticsMetrics(householdMetrics, activityRows),
        AdminMockData.analyticsMetrics,
      );

      return AdminDashboardData(
        stats: stats,
        trendData: trendData,
        momentumInsights: momentumInsights,
        moduleUsage: moduleUsage,
        analyticsMetrics: analyticsMetrics,
        activityLogs: activityLogs,
        notificationRows: notificationRows,
        adminUsers: adminUsers,
        alerts: alerts,
        failedJobs: failedJobs,
        notificationTemplates: templates,
      );
    } catch (_) {
      return AdminDashboardData(
        stats: AdminMockData.stats,
        trendData: AdminMockData.trendData,
        momentumInsights: AdminMockData.dashboardMomentumInsights,
        moduleUsage: AdminMockData.moduleUsage,
        analyticsMetrics: AdminMockData.analyticsMetrics,
        activityLogs: AdminMockData.activityLogs,
        notificationRows: AdminMockData.notificationRows,
        adminUsers: AdminMockData.adminUsers,
        alerts: const [
          SystemAlertRow(
            title: 'Akinyi Apartment hitting free-plan limits',
            body: '2/2 children · 25/25 supplies · upgrade candidate',
            severity: 'warning',
            status: 'open',
            createdAt: 'now',
          ),
          SystemAlertRow(
            title: 'Notification retry queue growing',
            body: '11 delayed push jobs since 06:00',
            severity: 'critical',
            status: 'open',
            createdAt: 'now',
          ),
        ],
        failedJobs: const [
          FailedJobRow(
            jobKey: 'push-retry-batch',
            jobType: 'notifications',
            status: 'retrying',
            retryCount: 2,
            errorMessage: 'Push queue timeout on worker-2',
            createdAt: 'now',
          ),
        ],
        notificationTemplates: const [
          TemplateSummaryRow(name: 'Low stock alert', channel: 'in_app', severity: 'warning', isActive: true),
          TemplateSummaryRow(name: 'Plan limit warning', channel: 'in_app', severity: 'critical', isActive: true),
        ],
      );
    }
  }

  Future<AdminPlanActionResult> grantHomePro({
    required String householdId,
    required String householdName,
  }) {
    return _applyHouseholdPlanAction(
      householdId: householdId,
      householdName: householdName,
      targetPlanCode: 'home_pro',
      targetPlanStatus: 'active',
      adjustmentType: 'upgrade',
      planExpiresAt: DateTime.now().add(const Duration(days: 30)),
      successMessage: 'Home Pro granted for $householdName.',
    );
  }

  Future<AdminPlanActionResult> applyHomeProTrial({
    required String householdId,
    required String householdName,
  }) {
    return _applyHouseholdPlanAction(
      householdId: householdId,
      householdName: householdName,
      targetPlanCode: 'home_pro',
      targetPlanStatus: 'active',
      adjustmentType: 'trial',
      planExpiresAt: DateTime.now().add(const Duration(days: 14)),
      successMessage: '14-day Home Pro trial applied to $householdName.',
    );
  }

  Future<AdminPlanActionResult> suspendPaidFeatures({
    required String householdId,
    required String householdName,
  }) {
    return _applyHouseholdPlanAction(
      householdId: householdId,
      householdName: householdName,
      targetPlanCode: 'free',
      targetPlanStatus: 'cancelled',
      adjustmentType: 'suspend_paid_features',
      planExpiresAt: DateTime.now(),
      successMessage: 'Paid features suspended for $householdName.',
    );
  }

  Future<AdminHouseholdMutationResult> createHousehold({
    required String householdName,
    required String planCode,
  }) async {
    final inviteCode = _generateInviteCode();
    final normalizedPlanCode = _normalizedPlanCode(planCode);

    try {
      final result = await SupabaseService.client.rpc(
        'admin_create_household',
        params: {
          'target_household_name': householdName,
          'target_invite_code': inviteCode,
          'target_plan_code': normalizedPlanCode,
        },
      );
      if (result is Map && result['ok'] == true) {
        return AdminHouseholdMutationResult(
          success: true,
          message: result['message']?.toString() ?? 'Household created.',
          householdId: result['household_id']?.toString(),
          inviteCode: result['invite_code']?.toString() ?? inviteCode,
        );
      }
    } catch (_) {
      // Fall through to direct owner-scoped create for local testing.
    }

    final currentUser = SupabaseService.client.auth.currentUser;
    if (currentUser != null) {
      try {
        final inserted = await SupabaseService.client
            .from('app_households')
            .insert({
              'household_name': householdName,
              'invite_code': inviteCode,
              'owner_user_id': currentUser.id,
              'plan_code': normalizedPlanCode,
              'plan_status': 'active',
            })
            .select('id')
            .single();

        final householdId = inserted['id']?.toString();
        if (householdId != null && householdId.isNotEmpty) {
          await SupabaseService.client.from('app_household_members').upsert({
            'household_id': householdId,
            'user_id': currentUser.id,
            'role': 'owner',
          }, onConflict: 'household_id,user_id');
        }

        return AdminHouseholdMutationResult(
          success: true,
          message: 'Household created under the signed-in account.',
          householdId: householdId,
          inviteCode: inviteCode,
        );
      } catch (error) {
        final raw = error.toString().toLowerCase();
        return AdminHouseholdMutationResult(
          success: false,
          requiresBackendSetup: _requiresAdminHouseholdSetup(raw),
          message: _requiresAdminHouseholdSetup(raw)
              ? 'Admin household creation is not available yet. Apply docs/supabase-admin-household-actions.sql or sign in as a household owner to test direct creation.'
              : 'Unable to create household: $error',
          inviteCode: inviteCode,
        );
      }
    }

    return AdminHouseholdMutationResult(
      success: false,
      requiresBackendSetup: true,
      message: 'No admin household write path is available yet. Apply docs/supabase-admin-household-actions.sql before using household creation from admin.',
      inviteCode: inviteCode,
    );
  }

  Future<AdminHouseholdMutationResult> resetHouseholdInviteCode({
    required String householdId,
    required String householdName,
  }) async {
    final inviteCode = _generateInviteCode();

    try {
      final result = await SupabaseService.client.rpc(
        'admin_reset_household_invite_code',
        params: {
          'target_household_id': householdId,
          'new_invite_code': inviteCode,
        },
      );
      if (result is Map && result['ok'] == true) {
        return AdminHouseholdMutationResult(
          success: true,
          message: result['message']?.toString() ?? 'Invite code reset.',
          householdId: householdId,
          inviteCode: result['invite_code']?.toString() ?? inviteCode,
        );
      }
    } catch (_) {
      // Fall through to direct update for local owner-authenticated testing.
    }

    try {
      final rows = await SupabaseService.client
          .from('app_households')
          .update({'invite_code': inviteCode})
          .eq('id', householdId)
          .select('id');
      if ((rows as List).isNotEmpty) {
        return AdminHouseholdMutationResult(
          success: true,
          message: 'Invite code reset for $householdName.',
          householdId: householdId,
          inviteCode: inviteCode,
        );
      }
    } catch (error) {
      final raw = error.toString().toLowerCase();
      return AdminHouseholdMutationResult(
        success: false,
        requiresBackendSetup: _requiresAdminHouseholdSetup(raw),
        message: _requiresAdminHouseholdSetup(raw)
            ? 'Admin invite reset is not available for $householdName yet. Apply docs/supabase-admin-household-actions.sql or sign in as the household owner to test direct updates.'
            : 'Unable to reset invite code for $householdName: $error',
        householdId: householdId,
        inviteCode: inviteCode,
      );
    }

    return AdminHouseholdMutationResult(
      success: false,
      requiresBackendSetup: true,
      message: 'No admin invite reset path is available for $householdName yet. Apply docs/supabase-admin-household-actions.sql before using invite actions from admin.',
      householdId: householdId,
      inviteCode: inviteCode,
    );
  }

  Future<List<AdminRoleRow>> fetchAdminUsers() async {
    final rows = await SupabaseService.client
        .from('admin_users')
        .select('full_name, email, status, last_active_at, admin_roles(name, description)')
        .order('created_at', ascending: false);

    return (rows as List)
        .map(
          (row) => AdminRoleRow(
            name: row['full_name']?.toString() ?? row['email']?.toString() ?? 'Admin user',
            role: _nested(row, 'admin_roles', 'name') ?? 'Admin',
            scope: _nested(row, 'admin_roles', 'description') ?? 'Internal operations',
            lastActive: _formatDateTime(row['last_active_at']),
            status: _titleCase(row['status']?.toString() ?? 'active'),
          ),
        )
        .toList();
  }

  Future<List<HouseholdRow>> fetchHouseholdRows() async {
    final rows = await _loadHouseholdMetrics();
    return rows
        .map(
          (row) => HouseholdRow(
            householdId: row.householdId,
            inviteCode: row.inviteCode,
            name: row.householdName,
            location: 'No address set',
            ownerName: row.ownerName,
            ownerEmail: row.ownerEmail,
            ownerPhone: row.ownerPhone,
            plan: row.planLabel,
            members: row.members,
            children: row.children,
            supplies: row.supplies,
            zones: row.zones,
            status: row.planStatus,
            createdDate: row.createdDate,
            usage: row.usage,
          ),
        )
        .toList();
  }

  Future<List<UserRow>> fetchUserRows() async {
    final membershipRows = await _safeSelect(
      'app_household_members',
      'user_id, household_id, role, created_at',
      orderBy: 'created_at',
      ascending: false,
    );

    final userIds = membershipRows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final householdIds = membershipRows
        .map((row) => row['household_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final profilesById = await _fetchProfilesById(userIds);
    final householdsById = await _fetchHouseholdsById(householdIds);
    final membershipsByUser = <String, List<Map<String, dynamic>>>{};

    for (final row in membershipRows) {
      final userId = row['user_id']?.toString();
      if (userId == null || userId.isEmpty) continue;
      membershipsByUser.putIfAbsent(userId, () => <Map<String, dynamic>>[]).add(row);
    }

    final users = membershipsByUser.entries.map((entry) {
      final profile = profilesById[entry.key] ?? const {};
      final memberships = entry.value;
      final primaryMembership = memberships.first;
      final householdNames = memberships
          .map((row) => householdsById[row['household_id']?.toString()]?['household_name']?.toString())
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      final primaryHousehold = householdsById[primaryMembership['household_id']?.toString()] ?? const {};
      final householdLabel = householdNames.isEmpty
          ? 'Unassigned'
          : householdNames.length == 1
              ? householdNames.first
              : '${householdNames.first} +${householdNames.length - 1}';

      return UserRow(
        fullName: profile['full_name']?.toString() ?? 'Unknown user',
        email: profile['email']?.toString() ?? '—',
        phone: '—',
        role: _roleLabel(primaryMembership['role']?.toString()),
        household: householdLabel,
        status: _userStatusLabel(primaryHousehold['plan_status']?.toString()),
        plan: _planLabel(primaryHousehold['plan_code']?.toString() ?? 'free'),
        createdAt: _formatDateOnly(profile['created_at'] ?? primaryMembership['created_at']),
        lastActive: _formatDateTime(profile['updated_at']),
      );
    }).toList();

    users.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return users;
  }

  Future<List<SubscriptionRow>> fetchSubscriptionRows() async {
    final rows = await _loadHouseholdMetrics();
    return rows
        .map(
          (row) => SubscriptionRow(
            householdId: row.householdId,
            household: row.householdName,
            owner: row.ownerName,
            plan: row.planLabel,
            billingStatus: row.billingStatus,
            maxBedrooms: row.maxBedrooms,
            maxSupplies: row.maxSupplies,
            maxChildren: row.maxChildren,
            bedroomUsage: row.zones,
            supplyUsage: row.supplies,
            childUsage: row.children,
            startedDate: row.createdDate,
            expiryDate: row.expiryDate,
          ),
        )
        .toList();
  }

  Future<List<ActivityLogRow>> fetchActivityLogs() async {
    final activityRows = <Map<String, dynamic>>[];

    try {
      final rows = await SupabaseService.client
          .from('admin_activity_logs')
          .select(
            'action, entity_type, metadata, created_at, '
            'admin_users(full_name), '
            'households(household_name), '
            'profiles(full_name, email)',
          )
          .order('created_at', ascending: false)
          .limit(20);

      activityRows.addAll(
        (rows as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(),
      );
    } catch (_) {
      // Fall back to app activity synthesis below.
    }

    final appHouseholdIds = activityRows
        .map((row) => _metadataField(row['metadata'], 'app_household_id'))
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final appHouseholdsById = await _fetchHouseholdsById(appHouseholdIds);

    final adminEvents = activityRows.map(
      (row) => _TimedActivityLogRow(
        eventAt: _parseDate(row['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        row: ActivityLogRow(
          user: _nested(row, 'admin_users', 'full_name') ??
              _nested(row, 'profiles', 'full_name') ??
              _nested(row, 'profiles', 'email') ??
              'Admin',
          household: _nested(row, 'households', 'household_name') ??
              appHouseholdsById[_metadataField(row['metadata'], 'app_household_id')]?['household_name']?.toString() ??
              'System',
          action: row['action']?.toString() ?? 'Unknown action',
          entity: row['entity_type']?.toString() ?? 'system',
          datetime: _formatDateTime(row['created_at']),
          metadata: _metadataPreview(row['metadata']),
        ),
      ),
    );

    final appEvents = await _fetchAppActivityRows(limit: 20);
    final combined = [...adminEvents, ...appEvents]
      ..sort((a, b) => b.eventAt.compareTo(a.eventAt));

    return combined.take(20).map((entry) => entry.row).toList();
  }

  Future<List<SupportIssueRow>> fetchSupportIssues() async {
    final rows = await SupabaseService.client
        .from('support_issues')
        .select(
          'title, priority, status, created_at, '
          'households(household_name), '
          'profiles(full_name, email), '
          'support_issue_categories(label), '
          'admin_users(full_name)',
        )
        .order('created_at', ascending: false)
        .limit(25);

    return (rows as List)
        .map(
          (row) => SupportIssueRow(
            title: row['title']?.toString() ?? 'Untitled issue',
            household: _nested(row, 'households', 'household_name') ?? 'Unknown household',
            user: _nested(row, 'profiles', 'full_name') ??
                _nested(row, 'profiles', 'email') ??
                'Unknown user',
            category: _nested(row, 'support_issue_categories', 'label') ?? 'General',
            priority: _titleCase(row['priority']?.toString() ?? 'medium'),
            status: _titleCase(row['status']?.toString() ?? 'open'),
            assignedAdmin: _nested(row, 'admin_users', 'full_name') ?? 'Unassigned',
            createdAt: _formatDateTime(row['created_at']),
          ),
        )
        .toList();
  }

  Future<List<NotificationRow>> fetchNotificationRows() async {
    try {
      final rows = await SupabaseService.client
          .from('notification_delivery_logs')
          .select(
            'status, error_message, metadata, delivered_at, created_at, '
            'notification_templates(name, severity, channel), '
            'profiles(full_name, email), '
            'households(household_name)',
          )
          .order('created_at', ascending: false)
          .limit(20);

      final mapped = (rows as List)
          .map(
            (row) => NotificationRow(
              template: _nested(row, 'notification_templates', 'name') ?? 'System notification',
              user: _nested(row, 'profiles', 'full_name') ??
                  _nested(row, 'profiles', 'email') ??
                  'System recipient',
              household: _nested(row, 'households', 'household_name') ?? 'System',
              type: _nested(row, 'notification_templates', 'channel') ?? 'ops',
              severity: _titleCase(_nested(row, 'notification_templates', 'severity') ?? 'info'),
              readState: row['status']?.toString() == 'read' ? 'Read' : 'Unread',
              result: row['error_message']?.toString().trim().isNotEmpty == true
                  ? 'Failed'
                  : _titleCase(row['status']?.toString() ?? 'delivered'),
            ),
          )
          .toList();
      if (mapped.isNotEmpty) return mapped;
    } catch (_) {
      // Fall back to app notifications below.
    }

    final appNotifications = await _fetchFeatureRows(
      'app_notifications',
      limit: 20,
    );
    if (appNotifications.isEmpty) return const [];

    final householdIds = appNotifications
        .map((row) => row['household_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final targetUserIds = appNotifications
        .map((row) => (row['data'] as Map<String, dynamic>)['targetUserId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final householdsById = await _fetchHouseholdsById(householdIds);
    final profilesById = await _fetchProfilesById(targetUserIds);

    return appNotifications
        .map((row) {
          final notification = AppNotification.fromJson(
            Map<String, dynamic>.from(row['data'] as Map),
          );
          final profile = notification.targetUserId == null
              ? null
              : profilesById[notification.targetUserId!];
          return NotificationRow(
            template: notification.title,
            user: profile?['full_name']?.toString() ??
                profile?['email']?.toString() ??
                'Household member',
            household: householdsById[notification.householdId]?['household_name']?.toString() ??
                'Household',
            type: _titleCase(notification.type),
            severity: _titleCase(notification.priority.name),
            readState: notification.isRead ? 'Read' : 'Unread',
            result: 'Delivered',
          );
        })
        .toList();
  }

  Future<List<SystemAlertRow>> fetchSystemAlerts() async {
    final rows = await SupabaseService.client
        .from('system_alerts')
        .select('title, body, severity, status, created_at')
        .order('created_at', ascending: false)
        .limit(10);

    return (rows as List)
        .map(
          (row) => SystemAlertRow(
            title: row['title']?.toString() ?? 'Alert',
            body: row['body']?.toString() ?? '',
            severity: row['severity']?.toString() ?? 'warning',
            status: row['status']?.toString() ?? 'open',
            createdAt: _formatDateTime(row['created_at']),
          ),
        )
        .toList();
  }

  Future<List<FailedJobRow>> fetchFailedJobs() async {
    final rows = await SupabaseService.client
        .from('failed_jobs')
        .select('job_key, job_type, status, retry_count, error_message, created_at')
        .order('created_at', ascending: false)
        .limit(10);

    return (rows as List)
        .map(
          (row) => FailedJobRow(
            jobKey: row['job_key']?.toString() ?? 'job',
            jobType: row['job_type']?.toString() ?? 'system',
            status: row['status']?.toString() ?? 'failed',
            retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
            errorMessage: row['error_message']?.toString() ?? 'Unknown error',
            createdAt: _formatDateTime(row['created_at']),
          ),
        )
        .toList();
  }

  Future<List<TemplateSummaryRow>> fetchNotificationTemplates() async {
    final rows = await SupabaseService.client
        .from('notification_templates')
        .select('name, channel, severity, is_active')
        .order('created_at', ascending: false)
        .limit(10);

    return (rows as List)
        .map(
          (row) => TemplateSummaryRow(
            name: row['name']?.toString() ?? 'Template',
            channel: row['channel']?.toString() ?? 'in_app',
            severity: row['severity']?.toString() ?? 'info',
            isActive: row['is_active'] as bool? ?? true,
          ),
        )
        .toList();
  }

  Future<List<PresetCategory>> fetchPresetCategories() async {
    final supplyRows = await _fetchFeatureRows('app_supplies', limit: 200);
    final mealRows = await _fetchFeatureRows('app_meal_logs', limit: 200);
    final laundryRows = await _fetchFeatureRows('app_laundry_items', limit: 200);
    final taskRows = await _fetchFeatureRows('app_tasks', limit: 200);
    final templates = await _guard(fetchNotificationTemplates, const <TemplateSummaryRow>[]);

    final supplyCategories = _topRankedStrings(
      supplyRows
          .map((row) => SupplyItem.fromJson(Map<String, dynamic>.from(row['data'] as Map)).category)
          .where((value) => value.trim().isNotEmpty),
    );
    final mealPatterns = _topRankedStrings(
      mealRows
          .map((row) => MealLog.fromJson(Map<String, dynamic>.from(row['data'] as Map)).selectedFoods.take(3).join(' + '))
          .where((value) => value.trim().isNotEmpty),
    );
    final laundryZones = _topRankedStrings(
      laundryRows
          .map((row) => LaundryItem.fromJson(Map<String, dynamic>.from(row['data'] as Map)).bedroom)
          .where((value) => value.trim().isNotEmpty),
    );
    final taskPresets = _topRankedStrings(
      taskRows
          .map((row) => TaskItem.fromJson(Map<String, dynamic>.from(row['data'] as Map)).title)
          .where((value) => value.trim().isNotEmpty),
    );
    final notificationTemplateNames = templates.map((row) => row.name).toList();

    final presets = <PresetCategory>[
      PresetCategory(title: 'Supply categories', items: supplyCategories),
      PresetCategory(title: 'Meal patterns', items: mealPatterns),
      PresetCategory(title: 'Laundry zones', items: laundryZones),
      PresetCategory(title: 'Daily task templates', items: taskPresets),
      PresetCategory(title: 'Notification templates', items: notificationTemplateNames.take(5).toList()),
    ].where((category) => category.items.isNotEmpty).toList();

    return presets.isEmpty ? AdminMockData.presetCategories : presets;
  }

  Future<List<SettingsItem>> fetchSettingsItems() async {
    final templates = await _guard(fetchNotificationTemplates, const <TemplateSummaryRow>[]);
    final alerts = await _guard(fetchSystemAlerts, const <SystemAlertRow>[]);
    final failedJobs = await _guard(fetchFailedJobs, const <FailedJobRow>[]);
    final featureOverrideRows = await _safeSelect('household_feature_limits', 'id');
    final supportRows = await _safeSelect('support_issues', 'priority, status');

    final criticalSupport = supportRows.where((row) {
      final priority = row['priority']?.toString();
      final status = row['status']?.toString();
      return priority == 'critical' && status != 'resolved' && status != 'closed';
    }).length;
    final activeTemplates = templates.where((row) => row.isActive).length;
    final openAlerts = alerts.where((row) => row.status != 'resolved').length;

    return [
      const SettingsItem(
        label: 'Admin access mode',
        value: 'JWT app_role=admin',
        description: 'Internal staff must carry the admin claim before admin RLS policies will grant access.',
      ),
      SettingsItem(
        label: 'Active notification templates',
        value: '$activeTemplates active',
        description: 'Templates currently available for admin-driven notification delivery and auditing.',
      ),
      SettingsItem(
        label: 'Feature limit overrides',
        value: '${featureOverrideRows.length} households',
        description: 'Households currently using manual bedroom, supplies, or children limits.',
      ),
      SettingsItem(
        label: 'Critical support load',
        value: '$criticalSupport open',
        description: 'Current number of unresolved critical support issues in the admin queue.',
      ),
      SettingsItem(
        label: 'System monitoring',
        value: '${failedJobs.length} failed • $openAlerts alerts',
        description: 'Operational snapshot of unresolved jobs and live admin alerts.',
      ),
      const SettingsItem(
        label: 'Free-plan warning point',
        value: '85%',
        description: 'Households are marked as near limits once tracked capacity reaches 85% of the current plan.',
      ),
    ];
  }

  Future<AdminHouseholdDetailData> fetchHouseholdDetail(String identifier) async {
    final household = await _resolveHouseholdRow(identifier);

    final memberRows = await _safeSelect(
      'app_household_members',
      'user_id, role, created_at',
      equals: {'household_id': household.householdId},
      orderBy: 'created_at',
      ascending: true,
    );
    final memberIds = memberRows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final memberProfiles = await _fetchProfilesById(memberIds);

    final childRows = await _fetchFeatureRows('app_children', householdId: household.householdId, limit: 20);
    final childLogRows = await _fetchFeatureRows('app_child_logs', householdId: household.householdId, limit: 50);
    final supplyRows = await _fetchFeatureRows('app_supplies', householdId: household.householdId, limit: 20);
    final shoppingRows = await _fetchFeatureRows('app_shopping_requests', householdId: household.householdId, limit: 20);
    final mealRows = await _fetchFeatureRows('app_meal_logs', householdId: household.householdId, limit: 20);
    final laundryRows = await _fetchFeatureRows('app_laundry_items', householdId: household.householdId, limit: 20);
    final notificationRows = await _fetchFeatureRows('app_notifications', householdId: household.householdId, limit: 20);
    final upgradeRows = await _safeSelect(
      'app_upgrade_requests',
      'requested_plan_code, status, source, notes, created_at',
      equals: {'household_id': household.householdId},
      orderBy: 'created_at',
      ascending: false,
      limit: 10,
    );
    final planAdjustmentRows = await _safeSelect(
      'household_plan_adjustments',
      'adjustment_type, previous_plan, new_plan, starts_at, ends_at, notes, created_at',
      equals: {'household_id': household.householdId},
      orderBy: 'created_at',
      ascending: false,
      limit: 10,
    );
    final featureLimitRows = await _safeSelect(
      'household_feature_limits',
      'max_bedrooms, max_supplies, max_children, source, updated_at',
      equals: {'household_id': household.householdId},
      orderBy: 'updated_at',
      ascending: false,
      limit: 1,
    );

    final latestChildLogById = <String, ChildRoutineLog>{};
    for (final row in childLogRows) {
      try {
        final log = ChildRoutineLog.fromJson(
          Map<String, dynamic>.from(row['data'] as Map),
        );
        final existing = latestChildLogById[log.childId];
        if (existing == null || log.date.isAfter(existing.date)) {
          latestChildLogById[log.childId] = log;
        }
      } catch (_) {
        // Skip malformed log rows.
      }
    }

    final notificationTargetIds = notificationRows
        .map((row) => (row['data'] as Map<String, dynamic>)['targetUserId']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final notificationProfiles = await _fetchProfilesById(notificationTargetIds);

    final activityLogs = await fetchActivityLogs();
    final householdActivity = activityLogs
        .where((row) => row.household == household.name || row.household == household.householdId)
        .take(10)
        .map(
          (row) => AdminDetailItem(
            title: row.action,
            subtitle: row.entity,
            status: row.user,
            meta: row.datetime,
            note: row.metadata,
          ),
        )
        .toList();

    final members = memberRows.isEmpty
        ? [
            AdminDetailItem(
              title: household.ownerName,
              subtitle: household.ownerEmail,
              status: 'Owner',
              meta: 'Primary household contact',
            ),
          ]
        : memberRows.map((row) {
            final userId = row['user_id']?.toString() ?? '';
            final profile = memberProfiles[userId] ?? const {};
            return AdminDetailItem(
              title: profile['full_name']?.toString() ?? profile['email']?.toString() ?? 'Household member',
              subtitle: profile['email']?.toString() ?? 'No email recorded',
              status: _roleLabel(row['role']?.toString()),
              meta: 'Joined ${_formatDateOnly(row['created_at'])}',
              note: profile['updated_at'] != null ? 'Last active ${_formatDateTime(profile['updated_at'])}' : null,
            );
          }).toList();

    final children = childRows.map((row) {
      final child = ChildModel.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      final latestLog = latestChildLogById[child.id];
      return AdminDetailItem(
        title: child.name,
        subtitle: [child.schoolName, child.className].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • ').isEmpty
            ? 'No school profile recorded'
            : [child.schoolName, child.className].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • '),
        status: latestLog != null ? '${latestLog.checkedCount}/6 ready' : (child.snackRequired ? 'Snack required' : null),
        meta: [child.dropoffTime, child.pickupTime].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • '),
        note: child.specialDayNotes ?? child.notes,
      );
    }).toList();

    final supplies = supplyRows.map((row) {
      final item = SupplyItem.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      final noteParts = <String>[];
      if (item.isOwnerOnly) noteParts.add('Owner only');
      if (item.isGasLowAlert) noteParts.add('Gas low alert');
      if (item.notes?.trim().isNotEmpty == true) noteParts.add(item.notes!.trim());
      return AdminDetailItem(
        title: item.name,
        subtitle: '${item.category} • ${item.unitType}',
        status: _titleCase(item.status.name),
        meta: item.lastRestockedAt != null ? 'Restocked ${_formatDateOnly(item.lastRestockedAt)}' : null,
        note: noteParts.isEmpty ? null : noteParts.join(' • '),
      );
    }).toList();

    final shopping = shoppingRows.map((row) {
      final request = ShoppingRequest.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      return AdminDetailItem(
        title: '${request.itemName} • ${request.quantity}',
        subtitle: 'Requested by ${request.requestedByName}',
        status: _titleCase(request.status.name),
        meta: '${_humanizeLabel(request.urgency.name)} • ${_formatDateTime(request.updatedAt)}',
        note: request.notes?.trim().isNotEmpty == true
            ? request.notes!.trim()
            : _humanizeLabel(request.purchaseType.name),
      );
    }).toList();

    final meals = mealRows.map((row) {
      final meal = MealLog.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      final title = meal.selectedFoods.isEmpty
          ? 'Meal log'
          : meal.selectedFoods.take(3).join(' + ');
      return AdminDetailItem(
        title: title,
        subtitle: '${_humanizeLabel(meal.mealPeriod)} • ${_formatDateOnly(meal.date)}',
        status: meal.packedForSchool ? 'Packed' : 'Logged',
        meta: meal.childName?.trim().isNotEmpty == true ? meal.childName : 'Whole household',
        note: meal.nutritionTags.isEmpty ? meal.notes : meal.nutritionTags.take(4).join(', '),
      );
    }).toList();

    final laundry = laundryRows.map((row) {
      final item = LaundryItem.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      final loadLabel = item.numberOfLoads == 1 ? '1 load' : '${item.numberOfLoads} loads';
      return AdminDetailItem(
        title: item.bedroom,
        subtitle: loadLabel,
        status: _titleCase(item.stage.name),
        meta: 'Updated ${_formatDateTime(item.updatedAt)}',
        note: item.notes?.trim().isNotEmpty == true ? item.notes!.trim() : null,
      );
    }).toList();

    final notifications = notificationRows.map((row) {
      final notification = AppNotification.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      final profile = notification.targetUserId == null ? null : notificationProfiles[notification.targetUserId!];
      return AdminDetailItem(
        title: notification.title,
        subtitle: notification.body,
        status: _titleCase(notification.priority.name),
        meta: profile?['full_name']?.toString() ?? profile?['email']?.toString() ?? 'Household audience',
        note: '${_humanizeLabel(notification.type)} • ${notification.isRead ? 'Read' : 'Unread'} • ${_formatDateTime(notification.createdAt)}',
      );
    }).toList();

    final billing = <AdminDetailItem>[
      AdminDetailItem(
        title: 'Current plan',
        subtitle: '${household.plan} • ${household.status}',
        status: household.plan,
        meta: 'Created ${household.createdDate}',
        note: 'Usage ${(household.usage * 100).round()}% • ${household.children} children • ${household.supplies} supplies • ${household.zones} zones',
      ),
      ...featureLimitRows.map(
        (row) => AdminDetailItem(
          title: 'Feature limits',
          subtitle: 'Bedrooms ${row['max_bedrooms'] ?? '—'} • Supplies ${row['max_supplies'] ?? '—'} • Children ${row['max_children'] ?? '—'}',
          status: _titleCase(row['source']?.toString() ?? 'plan'),
          meta: row['updated_at'] != null ? 'Updated ${_formatDateTime(row['updated_at'])}' : null,
        ),
      ),
      ...upgradeRows.map(
        (row) => AdminDetailItem(
          title: 'Upgrade request',
          subtitle: '${_planLabel(row['requested_plan_code']?.toString() ?? 'home_pro')} via ${row['source']?.toString() ?? 'app'}',
          status: _titleCase(row['status']?.toString() ?? 'requested'),
          meta: _formatDateTime(row['created_at']),
          note: row['notes']?.toString(),
        ),
      ),
      ...planAdjustmentRows.map(
        (row) => AdminDetailItem(
          title: _humanizeLabel(row['adjustment_type']?.toString() ?? 'plan adjustment'),
          subtitle: '${row['previous_plan']?.toString() ?? '—'} → ${row['new_plan']?.toString() ?? '—'}',
          status: _humanizeLabel(row['adjustment_type']?.toString() ?? 'plan adjustment'),
          meta: row['starts_at'] != null ? 'Starts ${_formatDateOnly(row['starts_at'])}' : _formatDateTime(row['created_at']),
          note: row['notes']?.toString() ?? (row['ends_at'] != null ? 'Ends ${_formatDateOnly(row['ends_at'])}' : null),
        ),
      ),
    ];

    return AdminHouseholdDetailData(
      household: household,
      members: members,
      children: children,
      supplies: supplies,
      shopping: shopping,
      meals: meals,
      laundry: laundry,
      notifications: notifications,
      billing: billing,
      activityLog: householdActivity,
    );
  }

  Future<List<_HouseholdMetrics>> _loadHouseholdMetrics() async {
    final households = await _safeSelect(
      'app_households',
      'id, household_name, invite_code, owner_user_id, plan_code, plan_status, plan_expires_at, created_at',
      orderBy: 'created_at',
      ascending: false,
    );

    final ownerIds = households
        .map((row) => row['owner_user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final profilesById = await _fetchProfilesById(ownerIds);
    final memberCounts = await _countByHousehold('app_household_members');
    final childCounts = await _countByHousehold('app_children');
    final supplyCounts = await _countByHousehold('app_supplies');
    final zoneCounts = await _countLaundryZonesByHousehold();
    final featureLimits = await _fetchFeatureLimitsByHousehold();

    return households.map((row) {
      final householdId = row['id']?.toString() ?? '';
      final ownerId = row['owner_user_id']?.toString() ?? '';
      final profile = profilesById[ownerId] ?? const {};
      final planCode = row['plan_code']?.toString() ?? 'free';
      final limits = featureLimits[householdId] ??
          _defaultLimitsForPlan(
            planCode,
            zonesUsed: zoneCounts[householdId] ?? 0,
            suppliesUsed: supplyCounts[householdId] ?? 0,
            childrenUsed: childCounts[householdId] ?? 0,
          );

      final zones = zoneCounts[householdId] ?? 0;
      final supplies = supplyCounts[householdId] ?? 0;
      final children = childCounts[householdId] ?? 0;
      final usage = _usageRatio(
        zonesUsed: zones,
        suppliesUsed: supplies,
        childrenUsed: children,
        maxZones: limits['zones'] ?? AppConstants.freeMaxLaundryZones,
        maxSupplies: limits['supplies'] ?? AppConstants.freeMaxSupplies,
        maxChildren: limits['children'] ?? AppConstants.freeMaxChildren,
      );

      return _HouseholdMetrics(
        householdId: householdId,
        inviteCode: row['invite_code']?.toString() ?? '',
        householdName: row['household_name']?.toString() ?? 'Household',
        ownerName: profile['full_name']?.toString() ?? 'Unknown owner',
        ownerEmail: profile['email']?.toString() ?? '—',
        ownerPhone: '—',
        planLabel: _planLabel(planCode),
        planStatus: _householdStatusLabel(
          rawPlanStatus: row['plan_status']?.toString(),
          usage: usage,
        ),
        billingStatus: _billingStatusLabel(
          planCode: planCode,
          rawPlanStatus: row['plan_status']?.toString(),
          planExpiresAt: row['plan_expires_at'],
        ),
        members: math.max(memberCounts[householdId] ?? 0, 1),
        children: children,
        supplies: supplies,
        zones: zones,
        maxBedrooms: limits['zones'] ?? AppConstants.freeMaxLaundryZones,
        maxSupplies: limits['supplies'] ?? AppConstants.freeMaxSupplies,
        maxChildren: limits['children'] ?? AppConstants.freeMaxChildren,
        createdDate: _formatDateOnly(row['created_at']),
        expiryDate: _formatDateOnly(row['plan_expires_at']),
        planExpiresAt: _parseDate(row['plan_expires_at']),
        usage: usage,
      );
    }).toList();
  }

  Future<List<AdminStat>> _loadStats(
    List<_HouseholdMetrics> households,
    Map<String, List<Map<String, dynamic>>> activityRows,
  ) async {
    final householdRows = _normalizeTimestampRows(
      await _safeSelect('app_households', 'id, created_at'),
      timestampField: 'created_at',
      householdField: 'id',
    );
    final supportRows = await _safeSelect('support_issues', 'priority, status');
    final mockStats = AdminMockData.stats;
    final totalHouseholds = households.length;
    final totalMembers = households.fold<int>(0, (sum, row) => sum + row.members);
    final totalOwners = totalHouseholds;
    final totalManagers = math.max(totalMembers - totalOwners, 0);
    final homeProHouseholds = households.where((row) => row.planLabel == 'Home Pro').length;
    final freeHouseholds = math.max(totalHouseholds - homeProHouseholds, 0);
    final totalChildren = households.fold<int>(0, (sum, row) => sum + row.children);
    final totalSupplies = households.fold<int>(0, (sum, row) => sum + row.supplies);
    final shoppingRows = activityRows['Shopping'] ?? const <Map<String, dynamic>>[];
    final laundryRows = activityRows['Laundry'] ?? const <Map<String, dynamic>>[];
    final suppliesRows = activityRows['Supplies'] ?? const <Map<String, dynamic>>[];
    final unreadIssues = supportRows.where((row) {
      final status = row['status']?.toString();
      return status != 'resolved' && status != 'closed';
    }).length;
    final criticalIssues = supportRows.where((row) {
      final priority = row['priority']?.toString();
      final status = row['status']?.toString();
      return priority == 'critical' && status != 'resolved' && status != 'closed';
    }).length;
    final recentSignups = _countRowsSince(householdRows, const Duration(days: 7));
    final suppliesTouched = _countRowsSince(suppliesRows, const Duration(days: 7));
    final shoppingTouched = _countRowsSince(shoppingRows, const Duration(days: 7));
    final laundryTouched = _countRowsSince(laundryRows, const Duration(days: 7));
    final freeShare = totalHouseholds == 0 ? 0 : ((freeHouseholds / totalHouseholds) * 100).round();
    final homeProShare = totalHouseholds == 0 ? 0 : ((homeProHouseholds / totalHouseholds) * 100).round();

    return [
      AdminStat(
        label: mockStats[0].label,
        value: '$totalHouseholds',
        delta: '+$recentSignups this week',
        icon: mockStats[0].icon,
        color: mockStats[0].color,
      ),
      AdminStat(
        label: mockStats[1].label,
        value: '$totalMembers',
        delta: 'Across $totalHouseholds households',
        icon: mockStats[1].icon,
        color: mockStats[1].color,
      ),
      AdminStat(
        label: mockStats[2].label,
        value: '$totalOwners',
        delta: 'One owner per household',
        icon: mockStats[2].icon,
        color: mockStats[2].color,
      ),
      AdminStat(
        label: mockStats[3].label,
        value: '$totalManagers',
        delta: totalHouseholds == 0
            ? 'No active households yet'
            : '${(totalManagers / totalHouseholds).toStringAsFixed(1)} per household',
        icon: mockStats[3].icon,
        color: mockStats[3].color,
      ),
      AdminStat(
        label: mockStats[4].label,
        value: '$freeHouseholds',
        delta: '$freeShare% of households',
        icon: mockStats[4].icon,
        color: mockStats[4].color,
      ),
      AdminStat(
        label: mockStats[5].label,
        value: '$homeProHouseholds',
        delta: '$homeProShare% of households',
        icon: mockStats[5].icon,
        color: mockStats[5].color,
      ),
      AdminStat(
        label: mockStats[6].label,
        value: '$totalChildren',
        delta: totalHouseholds == 0
            ? 'No children synced yet'
            : '${(totalChildren / totalHouseholds).toStringAsFixed(1)} per household',
        icon: mockStats[6].icon,
        color: mockStats[6].color,
      ),
      AdminStat(
        label: mockStats[7].label,
        value: '$totalSupplies',
        delta: '+$suppliesTouched updated this week',
        icon: mockStats[7].icon,
        color: mockStats[7].color,
      ),
      AdminStat(
        label: mockStats[8].label,
        value: '${shoppingRows.length}',
        delta: '+$shoppingTouched updated this week',
        icon: mockStats[8].icon,
        color: mockStats[8].color,
      ),
      AdminStat(
        label: mockStats[9].label,
        value: '${laundryRows.length}',
        delta: '+$laundryTouched updated this week',
        icon: mockStats[9].icon,
        color: mockStats[9].color,
      ),
      AdminStat(
        label: mockStats[10].label,
        value: '$unreadIssues',
        delta: '$criticalIssues critical',
        icon: mockStats[10].icon,
        color: mockStats[10].color,
      ),
      AdminStat(
        label: mockStats[11].label,
        value: '$recentSignups',
        delta: _deltaVsPreviousPeriod(
          recentSignups,
          _countRowsBetween(
            householdRows,
            start: _startOfToday().subtract(const Duration(days: 14)),
            end: _startOfToday().subtract(const Duration(days: 7)),
          ),
          suffix: 'vs last week',
        ),
        icon: mockStats[11].icon,
        color: mockStats[11].color,
      ),
    ];
  }

  Future<List<AnalyticsMetric>> _loadMomentumInsights(
    List<_HouseholdMetrics> households,
    Map<String, List<Map<String, dynamic>>> activityRows,
    List<FailedJobRow> failedJobs,
  ) async {
    final householdRows = _normalizeTimestampRows(
      await _safeSelect('app_households', 'id, created_at'),
      timestampField: 'created_at',
      householdField: 'id',
    );
    final upgradeRows = activityRows['Upgrade requests'] ?? const <Map<String, dynamic>>[];
    final newHouseholdsThisWeek = _countRowsSince(householdRows, const Duration(days: 7));
    final newHouseholdsLastWeek = _countRowsBetween(
      householdRows,
      start: _startOfToday().subtract(const Duration(days: 14)),
      end: _startOfToday().subtract(const Duration(days: 7)),
    );
    final homeProRequestsThisMonth = _countRowsSince(upgradeRows, const Duration(days: 30));
    final homeProRequestsThisWeek = _countRowsSince(upgradeRows, const Duration(days: 7));
    final retryingJobs = failedJobs.where((job) => job.status == 'retrying').length;
    final activePlanCount = households.where((row) => row.planLabel == 'Home Pro').length;

    return [
      AnalyticsMetric(
        label: 'New households this week',
        value: '$newHouseholdsThisWeek',
        note: _deltaVsPreviousPeriod(
          newHouseholdsThisWeek,
          newHouseholdsLastWeek,
          suffix: 'vs last week',
        ),
      ),
      AnalyticsMetric(
        label: 'Home Pro requests this month',
        value: '$homeProRequestsThisMonth',
        note: '$homeProRequestsThisWeek in the last 7 days • $activePlanCount households already active',
      ),
      AnalyticsMetric(
        label: 'Failed jobs',
        value: '${failedJobs.length}',
        note: retryingJobs == 0
            ? 'No retry queue right now'
            : '$retryingJobs currently retrying',
      ),
    ];
  }

  Future<List<AnalyticsMetric>> _loadAnalyticsMetrics(
    List<_HouseholdMetrics> households,
    Map<String, List<Map<String, dynamic>>> activityRows,
  ) async {
    final suppliesRows = activityRows['Supplies'] ?? const <Map<String, dynamic>>[];
    final shoppingRows = activityRows['Shopping'] ?? const <Map<String, dynamic>>[];
    final laundryRows = activityRows['Laundry'] ?? const <Map<String, dynamic>>[];
    final dailyActiveHouseholds = _countUniqueHouseholdsSince(
      activityRows.values,
      const Duration(days: 1),
    );
    final weeklyActiveHouseholds = _countUniqueHouseholdsSince(
      activityRows.values,
      const Duration(days: 7),
    );
    final averageSupplies = households.isEmpty
        ? 0.0
        : households.fold<int>(0, (sum, row) => sum + row.supplies) /
            households.length;
    final averageLaundryPerWeek = households.isEmpty
        ? 0.0
        : _countRowsSince(laundryRows, const Duration(days: 7)) /
            households.length;
    final averageShoppingPerWeek = households.isEmpty
        ? 0.0
        : _countRowsSince(shoppingRows, const Duration(days: 7)) /
            households.length;
    final upgradeTrigger = _topUpgradeTrigger(households);

    return [
      AnalyticsMetric(
        label: 'Daily active households',
        value: '$dailyActiveHouseholds',
        note: 'Households with any synced activity in the last 24 hours',
      ),
      AnalyticsMetric(
        label: 'Weekly active households',
        value: '$weeklyActiveHouseholds',
        note: 'Based on recent supply, laundry, meal, shopping, notification, and billing events',
      ),
      AnalyticsMetric(
        label: 'Average supplies per household',
        value: averageSupplies.toStringAsFixed(1),
        note: '${suppliesRows.length} total supply records synced',
      ),
      AnalyticsMetric(
        label: 'Average laundry batches / week',
        value: averageLaundryPerWeek.toStringAsFixed(1),
        note: '${_countRowsSince(laundryRows, const Duration(days: 7))} batches updated in the last 7 days',
      ),
      AnalyticsMetric(
        label: 'Average shopping requests / week',
        value: averageShoppingPerWeek.toStringAsFixed(1),
        note: '${_countRowsSince(shoppingRows, const Duration(days: 7))} request updates in the last 7 days',
      ),
      AnalyticsMetric(
        label: 'Most common upgrade trigger',
        value: upgradeTrigger['value'] ?? 'No pressure yet',
        note: upgradeTrigger['note'] ?? 'No households are close to current plan limits',
      ),
    ];
  }

  List<double> _loadTrendData(
    Map<String, List<Map<String, dynamic>>> activityRows,
  ) {
    final now = _startOfToday();
    final values = List<double>.generate(7, (index) {
      final start = now.subtract(Duration(days: 6 - index));
      final end = start.add(const Duration(days: 1));
      var count = 0;
      for (final rows in activityRows.values) {
        count += _countRowsBetween(rows, start: start, end: end);
      }
      return count.toDouble();
    });
    if (values.every((value) => value == 0)) {
      return AdminMockData.trendData;
    }
    return values;
  }

  List<ModuleUsageMetric> _loadModuleUsage(
    Map<String, List<Map<String, dynamic>>> activityRows,
  ) {
    final counts = <String, int>{
      'Supplies': (activityRows['Supplies'] ?? const <Map<String, dynamic>>[]).length,
      'Laundry': (activityRows['Laundry'] ?? const <Map<String, dynamic>>[]).length,
      'Shopping': (activityRows['Shopping'] ?? const <Map<String, dynamic>>[]).length,
      'Meals': (activityRows['Meals'] ?? const <Map<String, dynamic>>[]).length,
      'Notifications': (activityRows['Notifications'] ?? const <Map<String, dynamic>>[]).length,
    };
    final maxCount = counts.values.fold<int>(0, math.max);
    if (maxCount == 0) {
      return AdminMockData.moduleUsage;
    }

    return counts.entries
        .map(
          (entry) => ModuleUsageMetric(
            label: entry.key,
            current: ((entry.value / maxCount) * 100).round(),
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _safeSelect(
    String table,
    String columns, {
    Map<String, Object?>? equals,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseService.client.from(table).select(columns);
      if (equals != null) {
        for (final entry in equals.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }
      if (limit != null) {
        query = query.limit(limit);
      }
      final rows = await query;
      return (rows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFeatureRows(
    String table, {
    String? householdId,
    int? limit,
  }) async {
    final rows = await _safeSelect(
      table,
      'household_id, data, updated_at',
      equals: householdId == null ? null : {'household_id': householdId},
      orderBy: 'updated_at',
      ascending: false,
      limit: limit,
    );

    return rows
        .where((row) => row['data'] is Map)
        .map(
          (row) => {
            'household_id': row['household_id']?.toString(),
            'updated_at': row['updated_at'],
            'data': Map<String, dynamic>.from(row['data'] as Map),
          },
        )
        .toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadActivityRows(
    List<_ActivitySource> sources,
  ) async {
    final rows = await Future.wait(
      sources.map((source) async {
        final rawRows = await _safeSelect(
          source.table,
          'household_id, ${source.timestampField}',
        );
        return MapEntry(
          source.label,
          rawRows
              .map(
                (row) => {
                  'household_id': row['household_id']?.toString(),
                  'event_at': row[source.timestampField],
                },
              )
              .toList(),
        );
      }),
    );

    return {for (final entry in rows) entry.key: entry.value};
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfilesById(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, email, created_at, updated_at')
          .inFilter('id', ids);
      return {
        for (final row in rows as List)
          row['id'].toString(): Map<String, dynamic>.from(row as Map),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchHouseholdsById(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await SupabaseService.client
          .from('app_households')
          .select('id, household_name, plan_code, plan_status')
          .inFilter('id', ids);
      return {
        for (final row in rows as List)
          row['id'].toString(): Map<String, dynamic>.from(row as Map),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, int>> _countByHousehold(String table) async {
    final rows = await _safeSelect(table, 'household_id');
    final counts = <String, int>{};
    for (final row in rows) {
      final householdId = row['household_id']?.toString();
      if (householdId == null || householdId.isEmpty) continue;
      counts[householdId] = (counts[householdId] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<String, int>> _countLaundryZonesByHousehold() async {
    final rows = await _safeSelect('app_laundry_items', 'household_id, data');
    final zonesByHousehold = <String, Set<String>>{};

    for (final row in rows) {
      final householdId = row['household_id']?.toString();
      final data = row['data'];
      if (householdId == null || householdId.isEmpty || data is! Map) continue;
      final payload = Map<String, dynamic>.from(data);
      final bedroom = payload['bedroom']?.toString() ?? payload['category']?.toString();
      if (bedroom == null || bedroom.isEmpty) continue;
      zonesByHousehold.putIfAbsent(householdId, () => <String>{}).add(bedroom);
    }

    return {
      for (final entry in zonesByHousehold.entries) entry.key: entry.value.length,
    };
  }

  Future<Map<String, Map<String, int>>> _fetchFeatureLimitsByHousehold() async {
    final rows = await _safeSelect(
      'household_feature_limits',
      'household_id, max_bedrooms, max_supplies, max_children',
    );

    final limits = <String, Map<String, int>>{};
    for (final row in rows) {
      final householdId = row['household_id']?.toString();
      if (householdId == null || householdId.isEmpty) continue;
      limits[householdId] = {
        'zones': (row['max_bedrooms'] as num?)?.toInt() ?? AppConstants.freeMaxLaundryZones,
        'supplies': (row['max_supplies'] as num?)?.toInt() ?? AppConstants.freeMaxSupplies,
        'children': (row['max_children'] as num?)?.toInt() ?? AppConstants.freeMaxChildren,
      };
    }
    return limits;
  }

  Map<String, int> _defaultLimitsForPlan(
    String planCode, {
    required int zonesUsed,
    required int suppliesUsed,
    required int childrenUsed,
  }) {
    if (_normalizedPlanCode(planCode) == 'home_pro') {
      return {
        'zones': math.max(zonesUsed, 8),
        'supplies': math.max(suppliesUsed, 100),
        'children': math.max(childrenUsed, 10),
      };
    }

    return {
      'zones': AppConstants.freeMaxLaundryZones,
      'supplies': AppConstants.freeMaxSupplies,
      'children': AppConstants.freeMaxChildren,
    };
  }

  double _usageRatio({
    required int zonesUsed,
    required int suppliesUsed,
    required int childrenUsed,
    required int maxZones,
    required int maxSupplies,
    required int maxChildren,
  }) {
    final zoneRatio = maxZones <= 0 ? 0.0 : zonesUsed / maxZones;
    final supplyRatio = maxSupplies <= 0 ? 0.0 : suppliesUsed / maxSupplies;
    final childRatio = maxChildren <= 0 ? 0.0 : childrenUsed / maxChildren;
    return [zoneRatio, supplyRatio, childRatio].reduce(math.max);
  }

  String _planLabel(String raw) {
    switch (_normalizedPlanCode(raw)) {
      case 'home_pro':
        return 'Home Pro';
      default:
        return 'Free';
    }
  }

  String _billingStatusLabel({
    required String planCode,
    required String? rawPlanStatus,
    required dynamic planExpiresAt,
  }) {
    final normalizedPlan = _normalizedPlanCode(planCode);
    final normalizedStatus = rawPlanStatus ?? 'active';
    if (normalizedPlan != 'home_pro') return 'N/A';
    if (normalizedStatus == 'cancelled') return 'Cancelled';
    if (normalizedStatus == 'expired') return 'Expired';
    final expiry = _parseDate(planExpiresAt);
    if (expiry != null && expiry.isAfter(DateTime.now()) &&
        expiry.difference(DateTime.now()).inDays <= 14) {
      return 'Trial';
    }
    return 'Current';
  }

  String _normalizedPlanCode(String raw) {
    switch (raw.toLowerCase()) {
      case 'home_pro':
      case 'homepro':
      case 'plus':
      case 'gold':
      case 'premium':
      case 'pro':
        return 'home_pro';
      default:
        return 'free';
    }
  }


  Future<HouseholdRow> _resolveHouseholdRow(String identifier) async {
    final liveRows = await fetchHouseholdRows();
    final rows = liveRows.isEmpty ? AdminMockData.householdRows : liveRows;

    for (final row in rows) {
      if (row.householdId == identifier ||
          row.name == identifier ||
          _slugify(row.name) == _slugify(identifier)) {
        return row;
      }
    }

    return rows.first;
  }

  Future<List<_TimedActivityLogRow>> _fetchAppActivityRows({
    String? householdId,
    int limit = 20,
  }) async {
    final shoppingRows = await _fetchFeatureRows(
      'app_shopping_requests',
      householdId: householdId,
      limit: limit,
    );
    final mealRows = await _fetchFeatureRows(
      'app_meal_logs',
      householdId: householdId,
      limit: limit,
    );
    final laundryRows = await _fetchFeatureRows(
      'app_laundry_items',
      householdId: householdId,
      limit: limit,
    );
    final notificationRows = await _fetchFeatureRows(
      'app_notifications',
      householdId: householdId,
      limit: limit,
    );
    final upgradeRows = await _safeSelect(
      'app_upgrade_requests',
      'household_id, requested_plan_code, source, status, created_at',
      equals: householdId == null ? null : {'household_id': householdId},
      orderBy: 'created_at',
      ascending: false,
      limit: limit,
    );

    final householdIds = {
      ...shoppingRows.map((row) => row['household_id']?.toString()),
      ...mealRows.map((row) => row['household_id']?.toString()),
      ...laundryRows.map((row) => row['household_id']?.toString()),
      ...notificationRows.map((row) => row['household_id']?.toString()),
      ...upgradeRows.map((row) => row['household_id']?.toString()),
    }.whereType<String>().where((id) => id.isNotEmpty).toList();
    final householdsById = await _fetchHouseholdsById(householdIds);

    final events = <_TimedActivityLogRow>[];

    for (final row in shoppingRows) {
      final request = ShoppingRequest.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      events.add(
        _TimedActivityLogRow(
          eventAt: request.updatedAt,
          row: ActivityLogRow(
            user: request.requestedByName,
            household: householdsById[request.householdId]?['household_name']?.toString() ?? 'Household',
            action: 'Updated shopping request',
            entity: 'Shopping',
            datetime: _formatDateTime(request.updatedAt),
            metadata: '${request.itemName} • ${_titleCase(request.status.name)}',
          ),
        ),
      );
    }

    for (final row in mealRows) {
      final meal = MealLog.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      events.add(
        _TimedActivityLogRow(
          eventAt: meal.date,
          row: ActivityLogRow(
            user: meal.childName ?? 'Household',
            household: householdsById[meal.householdId]?['household_name']?.toString() ?? 'Household',
            action: 'Logged meal',
            entity: 'Meals',
            datetime: _formatDateTime(meal.date),
            metadata: meal.selectedFoods.take(3).join(' + '),
          ),
        ),
      );
    }

    for (final row in laundryRows) {
      final item = LaundryItem.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      events.add(
        _TimedActivityLogRow(
          eventAt: item.updatedAt,
          row: ActivityLogRow(
            user: 'Household',
            household: householdsById[item.householdId]?['household_name']?.toString() ?? 'Household',
            action: 'Updated laundry batch',
            entity: 'Laundry',
            datetime: _formatDateTime(item.updatedAt),
            metadata: '${item.bedroom} • ${_titleCase(item.stage.name)}',
          ),
        ),
      );
    }

    for (final row in notificationRows) {
      final notification = AppNotification.fromJson(Map<String, dynamic>.from(row['data'] as Map));
      events.add(
        _TimedActivityLogRow(
          eventAt: notification.createdAt,
          row: ActivityLogRow(
            user: 'System',
            household: householdsById[notification.householdId]?['household_name']?.toString() ?? 'Household',
            action: 'Queued notification',
            entity: 'Notifications',
            datetime: _formatDateTime(notification.createdAt),
            metadata: notification.title,
          ),
        ),
      );
    }

    for (final row in upgradeRows) {
      final createdAt = _parseDate(row['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final planCode = row['requested_plan_code']?.toString() ?? 'home_pro';
      events.add(
        _TimedActivityLogRow(
          eventAt: createdAt,
          row: ActivityLogRow(
            user: 'Household',
            household: householdsById[row['household_id']?.toString()]?['household_name']?.toString() ?? 'Household',
            action: 'Submitted upgrade request',
            entity: 'Billing',
            datetime: _formatDateTime(createdAt),
            metadata: '${_planLabel(planCode)} • ${row['status']?.toString() ?? 'requested'}',
          ),
        ),
      );
    }

    events.sort((a, b) => b.eventAt.compareTo(a.eventAt));
    return events.take(limit).toList();
  }

  List<String> _topRankedStrings(Iterable<String> values, {int limit = 5}) {
    final counts = <String, int>{};
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }

    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return ranked.take(limit).map((entry) => entry.key).toList();
  }

  static String? _metadataField(dynamic metadata, String key) {
    if (metadata is Map<String, dynamic>) {
      return metadata[key]?.toString();
    }
    if (metadata is Map) {
      return metadata[key]?.toString();
    }
    return null;
  }

  static String _humanizeLabel(String value) {
    if (value.isEmpty) return value;
    final normalized = value
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)}_${match.group(2)}')
        .toLowerCase();
    return _titleCase(normalized);
  }

  static String _slugify(String input) => input.toLowerCase().replaceAll(' ', '-');
  String _householdStatusLabel({
    required String? rawPlanStatus,
    required double usage,
  }) {
    final normalized = rawPlanStatus ?? 'active';
    if (normalized == 'cancelled') return 'Cancelled';
    if (normalized == 'expired') return 'Expired';
    if (normalized == 'grace_period') return 'Grace period';
    if (usage >= 1) return 'Upgrade candidate';
    if (usage >= 0.85) return 'Near limits';
    return 'Active';
  }

  String _roleLabel(String? rawRole) {
    switch (rawRole) {
      case 'house_manager':
        return 'House manager';
      case 'owner':
        return 'Owner';
      default:
        return 'User';
    }
  }

  String _userStatusLabel(String? rawPlanStatus) {
    switch (rawPlanStatus) {
      case 'cancelled':
      case 'expired':
        return 'Needs review';
      default:
        return 'Active';
    }
  }

  String _generateInviteCode() {
    const uuid = Uuid();
    return uuid.v4().substring(0, 8).toUpperCase();
  }

  Future<AdminPlanActionResult> _applyHouseholdPlanAction({
    required String householdId,
    required String householdName,
    required String targetPlanCode,
    required String targetPlanStatus,
    required String adjustmentType,
    required String successMessage,
    DateTime? planExpiresAt,
  }) async {
    final rpcParams = {
      'target_household_id': householdId,
      'target_plan_code': targetPlanCode,
      'target_plan_status': targetPlanStatus,
      'target_plan_expires_at': planExpiresAt?.toUtc().toIso8601String(),
      'adjustment_type': adjustmentType,
      'action_notes': 'Triggered from admin panel',
    };

    try {
      final result = await SupabaseService.client
          .rpc('admin_apply_household_plan_action', params: rpcParams);
      if (result is Map && result['ok'] == true) {
        return AdminPlanActionResult(
          success: true,
          message: result['message']?.toString() ?? successMessage,
        );
      }
      if (result == true) {
        return AdminPlanActionResult(success: true, message: successMessage);
      }
    } catch (_) {
      // Fall through to direct update for owner-authenticated local testing.
    }

    try {
      final rows = await SupabaseService.client
          .from('app_households')
          .update({
            'plan_code': targetPlanCode,
            'plan_status': targetPlanStatus,
            'plan_expires_at': planExpiresAt?.toUtc().toIso8601String(),
          })
          .eq('id', householdId)
          .select('id');
      if ((rows as List).isNotEmpty) {
        return AdminPlanActionResult(success: true, message: successMessage);
      }
    } catch (error) {
      final raw = error.toString().toLowerCase();
      return AdminPlanActionResult(
        success: false,
        requiresBackendSetup: _requiresAdminPlanSetup(raw),
        message: _requiresAdminPlanSetup(raw)
            ? 'Admin write access is not available for $householdName yet. Apply docs/supabase-admin-billing-rpc.sql or sign in as the household owner to test direct updates.'
            : 'Unable to update $householdName: $error',
      );
    }

    return AdminPlanActionResult(
      success: false,
      requiresBackendSetup: true,
      message: 'No admin write path is available for $householdName yet. Apply docs/supabase-admin-billing-rpc.sql before using billing actions from admin.',
    );
  }

  bool _requiresAdminPlanSetup(String error) {
    return error.contains('row-level security') ||
        error.contains('permission denied') ||
        error.contains('function public.admin_apply_household_plan_action') ||
        error.contains('pgrst202');
  }

  bool _requiresAdminHouseholdSetup(String error) {
    return error.contains('row-level security') ||
        error.contains('permission denied') ||
        error.contains('function public.admin_create_household') ||
        error.contains('function public.admin_reset_household_invite_code') ||
        error.contains('pgrst202');
  }

  Future<T> _guard<T>(Future<T> Function() action, T fallback) async {
    try {
      return await action();
    } catch (_) {
      return fallback;
    }
  }

  List<Map<String, dynamic>> _normalizeTimestampRows(
    List<Map<String, dynamic>> rows, {
    required String timestampField,
    String householdField = 'household_id',
  }) {
    return rows
        .map(
          (row) => {
            'household_id': row[householdField]?.toString(),
            'event_at': row[timestampField],
          },
        )
        .toList();
  }

  int _countRowsSince(List<Map<String, dynamic>> rows, Duration duration) {
    return _countRowsBetween(
      rows,
      start: DateTime.now().subtract(duration),
      end: DateTime.now().add(const Duration(milliseconds: 1)),
    );
  }

  int _countRowsBetween(
    List<Map<String, dynamic>> rows, {
    required DateTime start,
    required DateTime end,
  }) {
    return rows.where((row) {
      final parsed = _parseDate(row['event_at']);
      return parsed != null && !parsed.isBefore(start) && parsed.isBefore(end);
    }).length;
  }

  int _countUniqueHouseholdsSince(
    Iterable<List<Map<String, dynamic>>> groups,
    Duration duration,
  ) {
    final start = DateTime.now().subtract(duration);
    final ids = <String>{};
    for (final rows in groups) {
      for (final row in rows) {
        final parsed = _parseDate(row['event_at']);
        final householdId = row['household_id']?.toString();
        if (parsed == null || householdId == null || householdId.isEmpty) continue;
        if (!parsed.isBefore(start)) {
          ids.add(householdId);
        }
      }
    }
    return ids.length;
  }

  Map<String, String> _topUpgradeTrigger(List<_HouseholdMetrics> households) {
    var supplies = 0;
    var children = 0;
    var zones = 0;

    for (final household in households) {
      if (household.planLabel != 'Free') continue;
      if (household.maxSupplies > 0 &&
          (household.supplies / household.maxSupplies) >= 0.85) {
        supplies += 1;
      }
      if (household.maxChildren > 0 &&
          (household.children / household.maxChildren) >= 0.85) {
        children += 1;
      }
      if (household.maxBedrooms > 0 &&
          (household.zones / household.maxBedrooms) >= 0.85) {
        zones += 1;
      }
    }

    final ranked = <String, int>{
      'Supply limit pressure': supplies,
      'Child limit pressure': children,
      'Zone limit pressure': zones,
    };
    final top = ranked.entries.reduce(
      (best, current) => current.value > best.value ? current : best,
    );
    if (top.value == 0) {
      return const {
        'value': 'No pressure yet',
        'note': 'No free households are above 85% of their tracked plan limits',
      };
    }
    return {
      'value': top.key,
      'note': '${top.value} free households are at or above 85% of that limit',
    };
  }

  String _deltaVsPreviousPeriod(
    int current,
    int previous, {
    required String suffix,
  }) {
    if (previous == 0) {
      return current == 0 ? 'No change' : '+$current $suffix';
    }
    final delta = ((current - previous) / previous) * 100;
    final rounded = delta.round();
    return '${rounded >= 0 ? '+' : ''}$rounded% $suffix';
  }

  static String? _nested(Map<String, dynamic> row, String relation, String field) {
    final nested = row[relation];
    if (nested is Map<String, dynamic>) return nested[field]?.toString();
    if (nested is List && nested.isNotEmpty && nested.first is Map<String, dynamic>) {
      return (nested.first as Map<String, dynamic>)[field]?.toString();
    }
    return null;
  }

  static String _formatDateTime(dynamic value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat('dd MMM, HH:mm').format(parsed.toLocal());
  }

  static String _formatDateOnly(dynamic value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(parsed.toLocal());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _metadataPreview(dynamic value) {
    if (value == null) return '—';
    final text = value.toString();
    return text.length > 60 ? '${text.substring(0, 57)}...' : text;
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split('_')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
