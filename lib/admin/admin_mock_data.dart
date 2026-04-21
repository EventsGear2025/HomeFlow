import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'models/admin_models.dart';

class AdminMockData {
  static const navItems = <AdminNavItem>[
    AdminNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined),
    AdminNavItem(label: 'Households', icon: Icons.home_work_outlined),
    AdminNavItem(label: 'Users', icon: Icons.people_outline),
    AdminNavItem(label: 'Plans & Billing', icon: Icons.workspace_premium_outlined),
    AdminNavItem(label: 'Usage Analytics', icon: Icons.query_stats_outlined),
    AdminNavItem(label: 'Presets', icon: Icons.tune_outlined),
    AdminNavItem(label: 'Notifications', icon: Icons.notifications_active_outlined),
    AdminNavItem(label: 'Support Issues', icon: Icons.support_agent_outlined),
    AdminNavItem(label: 'Activity Logs', icon: Icons.history_toggle_off_outlined),
    AdminNavItem(label: 'Admin Users', icon: Icons.admin_panel_settings_outlined),
    AdminNavItem(label: 'Settings', icon: Icons.settings_outlined),
  ];

  static final stats = <AdminStat>[
    const AdminStat(label: 'Total households', value: '1,284', delta: '+42 this week', icon: Icons.home_work_rounded, color: AppColors.primaryTeal),
    const AdminStat(label: 'Total active users', value: '3,961', delta: '+8.2%', icon: Icons.people_alt_rounded, color: AppColors.supportBlue),
    const AdminStat(label: 'Total owners', value: '1,284', delta: '+22', icon: Icons.verified_user_rounded, color: AppColors.uiBlue),
    const AdminStat(label: 'Total house managers', value: '2,114', delta: '+31', icon: Icons.manage_accounts_rounded, color: AppColors.cardBlue),
    const AdminStat(label: 'Free plan households', value: '802', delta: '62.4%', icon: Icons.lock_open_rounded, color: AppColors.accentYellow),
    const AdminStat(label: 'Home Pro households', value: '311', delta: '+16 this month', icon: Icons.workspace_premium_rounded, color: AppColors.accentOrange),
    const AdminStat(label: 'Active children profiles', value: '2,790', delta: '+73', icon: Icons.child_friendly_rounded, color: Color(0xFF6C63FF)),
    const AdminStat(label: 'Active supplies tracked', value: '18,452', delta: '+410', icon: Icons.inventory_2_rounded, color: AppColors.secondaryTeal),
    const AdminStat(label: 'Active shopping requests', value: '286', delta: '19 urgent', icon: Icons.shopping_cart_checkout_rounded, color: Color(0xFFF4A261)),
    const AdminStat(label: 'Active laundry batches', value: '173', delta: '12 delayed', icon: Icons.local_laundry_service_rounded, color: Color(0xFF7B8CDE)),
    const AdminStat(label: 'Unread support issues', value: '27', delta: '5 critical', icon: Icons.report_problem_rounded, color: Color(0xFFD96C06)),
    const AdminStat(label: 'Recent signups', value: '91', delta: 'last 7 days', icon: Icons.person_add_alt_1_rounded, color: Color(0xFF1D3557)),
  ];

  static const dashboardMomentumInsights = <AnalyticsMetric>[
    AnalyticsMetric(label: 'New households this week', value: '42', note: '+12% vs last week'),
    AnalyticsMetric(label: 'Home Pro requests this month', value: '16', note: '7 in the last 7 days'),
    AnalyticsMetric(label: 'Failed jobs', value: '3', note: '2 forecast, 1 notifications'),
  ];

  static const householdRows = <HouseholdRow>[
    HouseholdRow(householdId: '11111111-1111-1111-1111-111111111111', inviteCode: 'MWAURA12', name: 'Mwaura Residence', location: 'Nairobi', ownerName: 'Janet Mwaura', ownerEmail: 'janet@homeflow.app', ownerPhone: '+254 712 230 111', plan: 'Home Pro', members: 4, children: 2, supplies: 24, zones: 5, status: 'Active', createdDate: '12 Mar 2026', usage: 0.63),
    HouseholdRow(householdId: '22222222-2222-2222-2222-222222222222', inviteCode: 'KARIUKI9', name: 'Kariuki Home', location: 'Kiambu', ownerName: 'Grace Kariuki', ownerEmail: 'grace@homeflow.app', ownerPhone: '+254 700 500 100', plan: 'Home Pro', members: 3, children: 1, supplies: 19, zones: 3, status: 'Active', createdDate: '03 Feb 2026', usage: 0.38),
    HouseholdRow(householdId: '33333333-3333-3333-3333-333333333333', inviteCode: 'AKINYI25', name: 'Akinyi Apartment', location: 'Kisumu', ownerName: 'Akinyi Omondi', ownerEmail: 'akinyi@homeflow.app', ownerPhone: '+254 733 881 220', plan: 'Free', members: 2, children: 2, supplies: 25, zones: 2, status: 'Upgrade candidate', createdDate: '17 Jan 2026', usage: 1.0),
    HouseholdRow(householdId: '44444444-4444-4444-4444-444444444444', inviteCode: 'MWENDE77', name: 'Mwende Family', location: 'Mombasa', ownerName: 'Mercy Mwende', ownerEmail: 'mercy@homeflow.app', ownerPhone: '+254 721 773 551', plan: 'Home Pro', members: 6, children: 3, supplies: 40, zones: 7, status: 'Near limits', createdDate: '22 Dec 2025', usage: 0.88),
  ];

  static const userRows = <UserRow>[
    UserRow(fullName: 'Janet Mwaura', email: 'janet@homeflow.app', phone: '+254 712 230 111', role: 'Owner', household: 'Mwaura Residence', status: 'Active', plan: 'Home Pro', createdAt: '12 Mar 2026', lastActive: '2 mins ago'),
    UserRow(fullName: 'Lucy Wambui', email: 'lucy.manager@homeflow.app', phone: '+254 711 320 777', role: 'House Manager', household: 'Mwaura Residence', status: 'Active', plan: 'Home Pro', createdAt: '13 Mar 2026', lastActive: '9 mins ago'),
    UserRow(fullName: 'Grace Kariuki', email: 'grace@homeflow.app', phone: '+254 700 500 100', role: 'Owner', household: 'Kariuki Home', status: 'Active', plan: 'Home Pro', createdAt: '03 Feb 2026', lastActive: '1 hour ago'),
    UserRow(fullName: 'Kevin Otieno', email: 'kevin.ops@homeflow.app', phone: '+254 723 211 421', role: 'House Manager', household: 'Akinyi Apartment', status: 'Inactive', plan: 'Free', createdAt: '18 Jan 2026', lastActive: '3 days ago'),
  ];

  static const subscriptionRows = <SubscriptionRow>[
    SubscriptionRow(householdId: '11111111-1111-1111-1111-111111111111', household: 'Mwaura Residence', owner: 'Janet Mwaura', plan: 'Home Pro', billingStatus: 'Current', maxBedrooms: 8, maxSupplies: 100, maxChildren: 10, bedroomUsage: 5, supplyUsage: 24, childUsage: 2, startedDate: '12 Mar 2026', expiryDate: '12 Apr 2026'),
    SubscriptionRow(householdId: '22222222-2222-2222-2222-222222222222', household: 'Kariuki Home', owner: 'Grace Kariuki', plan: 'Home Pro', billingStatus: 'Trial', maxBedrooms: 8, maxSupplies: 100, maxChildren: 10, bedroomUsage: 3, supplyUsage: 19, childUsage: 1, startedDate: '03 Feb 2026', expiryDate: '03 Apr 2026'),
    SubscriptionRow(householdId: '33333333-3333-3333-3333-333333333333', household: 'Akinyi Apartment', owner: 'Akinyi Omondi', plan: 'Free', billingStatus: 'N/A', maxBedrooms: 2, maxSupplies: 60, maxChildren: 2, bedroomUsage: 2, supplyUsage: 25, childUsage: 2, startedDate: '17 Jan 2026', expiryDate: '—'),
  ];

  static const supportIssues = <SupportIssueRow>[
    SupportIssueRow(title: 'Notifications not showing on Android', household: 'Kariuki Home', user: 'Grace Kariuki', category: 'Notifications', priority: 'High', status: 'Open', assignedAdmin: 'Support Desk', createdAt: 'Today, 10:42'),
    SupportIssueRow(title: 'Cannot upgrade from Free to Home Pro', household: 'Akinyi Apartment', user: 'Akinyi Omondi', category: 'Subscription', priority: 'Critical', status: 'In progress', assignedAdmin: 'Billing Admin', createdAt: 'Today, 09:15'),
    SupportIssueRow(title: 'Laundry stage stuck on washing', household: 'Mwaura Residence', user: 'Lucy Wambui', category: 'Laundry bug', priority: 'Medium', status: 'Open', assignedAdmin: 'Support Desk', createdAt: 'Yesterday, 17:20'),
  ];

  static const activityLogs = <ActivityLogRow>[
    ActivityLogRow(user: 'Janet Mwaura', household: 'Mwaura Residence', action: 'Activated Home Pro', entity: 'Subscription', datetime: 'Today, 08:12', metadata: 'Plan changed from Free → Home Pro'),
    ActivityLogRow(user: 'Grace Kariuki', household: 'Kariuki Home', action: 'Approved shopping request', entity: 'Shopping', datetime: 'Today, 07:55', metadata: '12 item request approved'),
    ActivityLogRow(user: 'Lucy Wambui', household: 'Mwaura Residence', action: 'Laundry batch moved to ironing', entity: 'Laundry', datetime: 'Today, 07:20', metadata: 'Batch #LB-129'),
    ActivityLogRow(user: 'Admin · Ruth', household: 'Akinyi Apartment', action: 'Applied 14-day trial', entity: 'Billing', datetime: 'Yesterday, 18:32', metadata: 'Manual sales assist'),
  ];

  static const presetCategories = <PresetCategory>[
    PresetCategory(title: 'Supply categories', items: ['Washing powder', '13kg gas', 'Mandazi', 'School snack', 'Tissue paper']),
    PresetCategory(title: 'Meal presets', items: ['Chapati + ndengu', 'Rice + beans', 'Uji', 'Sandwich snack']),
    PresetCategory(title: 'Laundry presets', items: ['School uniforms', 'White load', 'Bedding wash']),
    PresetCategory(title: 'School item presets', items: ['Swimming costume', 'Water bottle', 'Homework folder']),
    PresetCategory(title: 'Notification templates', items: ['Low stock alert', 'Plan limit warning', 'Laundry delayed notice']),
  ];

  static const moduleUsage = <ModuleUsageMetric>[
    ModuleUsageMetric(label: 'Supplies', current: 92),
    ModuleUsageMetric(label: 'Laundry', current: 78),
    ModuleUsageMetric(label: 'Shopping', current: 67),
    ModuleUsageMetric(label: 'Meals', current: 59),
    ModuleUsageMetric(label: 'Notifications', current: 44),
  ];

  static const notificationRows = <NotificationRow>[
    NotificationRow(template: 'Low stock alert', user: 'Lucy Wambui', household: 'Mwaura Residence', type: 'Inventory', severity: 'Warning', readState: 'Unread', result: 'Delivered'),
    NotificationRow(template: 'Plan limit warning', user: 'Akinyi Omondi', household: 'Akinyi Apartment', type: 'Billing', severity: 'Critical', readState: 'Unread', result: 'Delivered'),
    NotificationRow(template: 'Laundry delayed notice', user: 'Grace Kariuki', household: 'Kariuki Home', type: 'Laundry', severity: 'Warning', readState: 'Read', result: 'Delivered'),
    NotificationRow(template: 'Push retry batch', user: '—', household: 'System', type: 'Ops', severity: 'Critical', readState: 'N/A', result: 'Failed 11'),
  ];

  static const analyticsMetrics = <AnalyticsMetric>[
    AnalyticsMetric(label: 'Daily active households', value: '684', note: '+9.1% vs last week'),
    AnalyticsMetric(label: 'Weekly active users', value: '2,931', note: 'Owners + house managers'),
    AnalyticsMetric(label: 'Average supplies per household', value: '14.4', note: 'Higher on Home Pro households'),
    AnalyticsMetric(label: 'Average laundry batches / week', value: '3.2', note: 'Peak usage on Mondays'),
    AnalyticsMetric(label: 'Average shopping requests / week', value: '2.1', note: 'Mostly food + cleaning'),
    AnalyticsMetric(label: 'Most common upgrade trigger', value: 'Supply limit reached', note: 'Free plan conversion signal'),
  ];

  static const adminUsers = <AdminRoleRow>[
    AdminRoleRow(name: 'Ruth Ops', role: 'Super Admin', scope: 'All modules', lastActive: '5 mins ago', status: 'Active'),
    AdminRoleRow(name: 'Kevin Support', role: 'Support Admin', scope: 'Households, users, tickets', lastActive: '22 mins ago', status: 'Active'),
    AdminRoleRow(name: 'Mary Billing', role: 'Billing Admin', scope: 'Plans, trials, extensions', lastActive: '1 hour ago', status: 'Active'),
    AdminRoleRow(name: 'Brian Content', role: 'Content Admin', scope: 'Presets, templates, onboarding', lastActive: 'Yesterday', status: 'Limited'),
  ];

  static const settingsItems = <SettingsItem>[
    SettingsItem(label: 'Theme direction', value: 'White + teal + muted orange', description: 'Operations console styling for the web admin panel'),
    SettingsItem(label: 'Critical support SLA', value: '< 30 minutes', description: 'Alert threshold for unread high-priority issues'),
    SettingsItem(label: 'Forecast failure threshold', value: '3 jobs / day', description: 'When to show top-level platform alert on the dashboard'),
    SettingsItem(label: 'Free-plan warning point', value: '85%', description: 'When households start showing as near-limits'),
  ];

  static const trendData = <double>[48, 56, 53, 72, 75, 88, 94];
}