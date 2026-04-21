import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_colors.dart';
import 'admin_mock_data.dart';
import 'admin_repository.dart';
import 'models/admin_models.dart';
import 'widgets/admin_widgets.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({
    super.key,
    required this.selectedIndex,
    required this.child,
  });

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navItems = AdminMockData.navItems;
    final selectedLabel = navItems[selectedIndex].label;

    return AdminShellScaffold(
      selectedIndex: selectedIndex,
      navItems: navItems,
      onSelect: (index) => _onSelect(context, index),
      title: selectedLabel,
      subtitle: _subtitleFor(selectedLabel),
      trailing: FilledButton.icon(
        onPressed: () => _showQuickActionSheet(context),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick action'),
      ),
      child: child,
    );
  }

  Future<void> _showQuickActionSheet(BuildContext context) async {
    final path = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        const actions = <_QuickActionItem>[
          _QuickActionItem(
            label: 'Households',
            subtitle: 'Open the operations view for household support and plan changes.',
            icon: Icons.home_work_outlined,
            path: '/admin/households',
          ),
          _QuickActionItem(
            label: 'Users',
            subtitle: 'Review owners, house managers, and resend invites.',
            icon: Icons.people_outline,
            path: '/admin/users',
          ),
          _QuickActionItem(
            label: 'Plans & Billing',
            subtitle: 'Apply Home Pro actions and inspect plan usage.',
            icon: Icons.workspace_premium_outlined,
            path: '/admin/plans',
          ),
          _QuickActionItem(
            label: 'Support Issues',
            subtitle: 'Jump straight to the active support queue.',
            icon: Icons.support_agent_outlined,
            path: '/admin/support',
          ),
          _QuickActionItem(
            label: 'Presets',
            subtitle: 'Manage session-level preset drafts and content edits.',
            icon: Icons.tune_outlined,
            path: '/admin/presets',
          ),
        ];

        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: actions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (sheetContext, index) {
              final action = actions[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: AppColors.surfaceLight,
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceMuted,
                  foregroundColor: AppColors.primaryTeal,
                  child: Icon(action.icon),
                ),
                title: Text(action.label),
                subtitle: Text(action.subtitle),
                onTap: () => Navigator.of(sheetContext).pop(action.path),
              );
            },
          ),
        );
      },
    );

    if (!context.mounted || path == null) return;
    context.go(path);
  }

  void _onSelect(BuildContext context, int index) {
    final path = switch (index) {
      0 => '/admin/dashboard',
      1 => '/admin/households',
      2 => '/admin/users',
      3 => '/admin/plans',
      4 => '/admin/analytics',
      5 => '/admin/presets',
      6 => '/admin/notifications',
      7 => '/admin/support',
      8 => '/admin/activity-logs',
      9 => '/admin/admin-users',
      _ => '/admin/settings',
    };
  context.go(path);
  }

  String _subtitleFor(String label) {
    switch (label) {
      case 'Dashboard':
        return 'Monitor platform health, growth, alerts, and admin activity at a glance.';
      case 'Households':
        return 'Search, inspect, support, and manage every household in HomeFlow.';
      case 'Users':
        return 'View owners and house managers, filter by plan, and support account operations.';
      case 'Plans & Billing':
        return 'Manage subscriptions, usage thresholds, upgrades, and complimentary access.';
      case 'Usage Analytics':
        return 'Understand module adoption, upgrade triggers, and household engagement trends.';
      case 'Presets':
        return 'Control system content and default templates without hard-coding.';
      case 'Notifications':
        return 'Review notification volume, read rates, failures, and template noise.';
      case 'Support Issues':
        return 'Track login, subscription, shopping, meals, laundry, and notification issues.';
      case 'Activity Logs':
        return 'Audit user and admin actions for accountability and support troubleshooting.';
      case 'Admin Users':
        return 'Define admin roles and permissions for support, billing, and content operations.';
      case 'Settings':
        return 'Platform-level branding, safeguards, and operational defaults.';
      default:
        return '';
    }
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminDashboardData>(
      future: const AdminRepository().loadDashboardData(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final stats = data?.stats ?? AdminMockData.stats;
        final trendData = data?.trendData ?? AdminMockData.trendData;
        final momentumInsights =
            data?.momentumInsights ?? AdminMockData.dashboardMomentumInsights;
        final moduleUsage = data?.moduleUsage ?? AdminMockData.moduleUsage;
        final activityLogs = data?.activityLogs ?? AdminMockData.activityLogs;
        final alerts = data?.alerts ?? const <SystemAlertRow>[];

        return AdminContentSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.35,
                ),
                itemCount: stats.length,
                itemBuilder: (context, index) => AdminStatCard(stat: stats[index]),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 1150;

                  final leftColumn = Column(
                    children: [
                      AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AdminPageHeader(
                              title: 'Platform momentum',
                              subtitle: 'New households this week, upgrades this month, and household activity trend.',
                            ),
                            const SizedBox(height: 18),
                            SimpleLineChart(values: trendData),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                for (var index = 0; index < momentumInsights.length; index++) ...[
                                  Expanded(
                                    child: _MiniInsight(
                                      label: momentumInsights[index].label,
                                      value: momentumInsights[index].value,
                                      note: momentumInsights[index].note,
                                    ),
                                  ),
                                  if (index != momentumInsights.length - 1)
                                    const SizedBox(width: 12),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AdminPageHeader(
                              title: 'Most-used modules',
                              subtitle: 'Where households spend the most time this week.',
                            ),
                            const SizedBox(height: 16),
                            ...moduleUsage.map(
                              (module) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: UsageBar(
                                  label: module.label,
                                  current: module.current,
                                  max: module.max,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final rightColumn = Column(
                    children: [
                      AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AdminPageHeader(
                              title: 'Alerts & failed jobs',
                              subtitle: 'Warnings that need admin attention right now.',
                            ),
                            const SizedBox(height: 16),
                            ...(alerts.isNotEmpty
                                ? alerts.take(3).expand(
                                    (alert) => [
                                      _AlertTile(title: alert.title, subtitle: alert.body, severity: alert.severity),
                                      const SizedBox(height: 12),
                                    ],
                                  )
                                : const [
                                    _AlertTile(title: 'No live alerts yet', subtitle: 'Seeded or fetched alerts will appear here.', severity: 'warning'),
                                  ]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AdminCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AdminPageHeader(
                              title: 'Recent admin actions',
                              subtitle: 'Latest support, billing, and content operations.',
                            ),
                            const SizedBox(height: 16),
                            ...activityLogs.take(4).map((log) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _TimelineTile(log: log),
                                )),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: leftColumn),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: rightColumn),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftColumn,
                      const SizedBox(height: 16),
                      rightColumn,
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminHouseholdsPage extends StatefulWidget {
  const AdminHouseholdsPage({super.key});

  @override
  State<AdminHouseholdsPage> createState() => _AdminHouseholdsPageState();
}

class _AdminHouseholdsPageState extends State<AdminHouseholdsPage> {
  final AdminRepository _repository = const AdminRepository();

  List<HouseholdRow> _households =
      _AdminSessionStore.mergeHouseholds(AdminMockData.householdRows);
  bool _usingFallback = true;
  bool _isLoading = true;
  int _selectedFilter = 0;

  static const _filters = <String>[
    'All households',
    'Home Pro',
    'Free',
    'Near limits',
    'Suspended',
  ];

  @override
  void initState() {
    super.initState();
    _loadHouseholds();
  }

  Future<void> _loadHouseholds() async {
    var rows = _AdminSessionStore.mergeHouseholds(AdminMockData.householdRows);
    var usingFallback = true;

    try {
      final fetchedRows = await _repository.fetchHouseholdRows();
      if (fetchedRows.isNotEmpty) {
        rows = _AdminSessionStore.mergeHouseholds(fetchedRows);
        usingFallback = false;
      }
    } catch (_) {
      usingFallback = true;
    }

    if (!mounted) return;
    setState(() {
      _households = rows;
      _usingFallback = usingFallback;
      _isLoading = false;
    });
  }

  List<HouseholdRow> get _visibleHouseholds {
    switch (_selectedFilter) {
      case 1:
        return _households.where((row) => row.plan == 'Home Pro').toList();
      case 2:
        return _households.where((row) => row.plan == 'Free').toList();
      case 3:
        return _households
            .where((row) =>
                row.status == 'Near limits' ||
                row.status == 'Upgrade candidate' ||
                row.usage >= 0.85)
            .toList();
      case 4:
        return _households
            .where((row) =>
                row.status == 'Cancelled' ||
                row.status == 'Suspended' ||
                row.status == 'Draft')
            .toList();
      default:
        return _households;
    }
  }

  Future<void> _exportHouseholds() async {
    await _showCopyDialog(
      context,
      title: 'Households CSV',
      description:
          'The current households table export is ready. Copy it into Sheets, Excel, or your support workflow.',
      content: _buildHouseholdCsv(_visibleHouseholds),
      copyLabel: 'Copy CSV',
    );
  }

  Future<void> _handleAddHousehold() async {
    final draft = await _showCreateHouseholdDialog(context);
    if (!mounted || draft == null) return;

    final result = await _repository.createHousehold(
      householdName: draft.name,
      planCode: draft.planCode,
    );
    if (!mounted) return;

    final persisted = result.success;
    final household = HouseholdRow(
      householdId:
          result.householdId ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
      inviteCode: result.inviteCode ?? _generateInviteCode(),
      name: draft.name,
      location: draft.location.isEmpty ? 'No address set' : draft.location,
      ownerName: 'Awaiting owner claim',
      ownerEmail: 'Invite not yet claimed',
      ownerPhone: '—',
      plan: _planLabelForUi(draft.planCode),
      members: 0,
      children: 0,
      supplies: 0,
      zones: 0,
      status: persisted ? 'Active' : 'Draft',
      createdDate: _formatAdminDate(DateTime.now()),
      usage: 0,
    );

    _AdminSessionStore.upsertHousehold(household);
    setState(() {
      _households = _AdminSessionStore.mergeHouseholds(_households);
    });

    final description = persisted
        ? '${result.message} Share the invite code with the owner to complete setup.'
        : 'Household added for this admin session only. ${result.message}';

    await _showCopyDialog(
      context,
      title: 'Household ready',
      description: description,
      content: _buildHouseholdInviteSummary(household),
      copyLabel: 'Copy invite',
    );
  }

  @override
  Widget build(BuildContext context) {
    final households = _visibleHouseholds;
    return AdminContentSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Households management',
            subtitle:
                'Searchable operations view with support-focused actions and household drill-down.',
            actions: [
              _GhostAction(
                label: 'Export CSV',
                icon: Icons.download_outlined,
                onPressed: _exportHouseholds,
              ),
              _GhostAction(
                label: 'Add household',
                icon: Icons.add_home_work_outlined,
                onPressed: _handleAddHousehold,
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          FilterChipBar(
            items: _filters,
            selectedIndex: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const SizedBox(height: 16),
          TableCard(
            title: _usingFallback ? 'Households (fallback data)' : 'Households',
            columns: const [
              'Household',
              'Owner',
              'Plan',
              'Members',
              'Children',
              'Supplies',
              'Zones',
              'Status',
              'Created',
              'Actions',
            ],
            rows: households
                .map(
                  (r) => [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          r.location,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.ownerName),
                        Text(
                          r.ownerEmail,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    StatusPill(label: r.plan),
                    Text('${r.members}'),
                    Text('${r.children}'),
                    Text('${r.supplies}'),
                    Text('${r.zones}'),
                    StatusPill(label: r.status),
                    Text(r.createdDate),
                    _HouseholdLinkButton(row: r),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class AdminHouseholdDetailPage extends StatefulWidget {
  const AdminHouseholdDetailPage({super.key, required this.householdId});

  final String householdId;

  @override
  State<AdminHouseholdDetailPage> createState() => _AdminHouseholdDetailPageState();
}

class _AdminHouseholdDetailPageState extends State<AdminHouseholdDetailPage> {
  final AdminRepository _repository = const AdminRepository();

  int selectedTab = 0;
  late AdminHouseholdDetailData _detail;
  bool _usingFallback = true;
  bool _isLoading = true;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _detail = _fallbackHouseholdDetail(widget.householdId);
    _loadDetail();
  }

  @override
  void didUpdateWidget(covariant AdminHouseholdDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId) {
      selectedTab = 0;
      _busyAction = null;
      _detail = _fallbackHouseholdDetail(widget.householdId);
      _usingFallback = true;
      _isLoading = true;
      _loadDetail();
    }
  }

  Future<void> _loadDetail() async {
    var detail = _fallbackHouseholdDetail(widget.householdId);
    var usingFallback = true;

    try {
      detail = await _repository.fetchHouseholdDetail(widget.householdId);
      usingFallback = false;
    } catch (_) {
      usingFallback = true;
    }

    final sessionHousehold =
        _AdminSessionStore.householdByIdentifier(widget.householdId);
    if (sessionHousehold != null) {
      detail = _withUpdatedHouseholdDetail(detail, sessionHousehold);
    }

    if (!mounted) return;
    setState(() {
      _detail = detail;
      _usingFallback = usingFallback;
      _isLoading = false;
    });
  }

  void _applyHouseholdUpdate(HouseholdRow row) {
    _AdminSessionStore.upsertHousehold(row);
    setState(() {
      _detail = _withUpdatedHouseholdDetail(_detail, row);
    });
  }

  Future<void> _handleResetInviteCode() async {
    final row = _detail.household;
    setState(() => _busyAction = 'invite');

    final result = await _repository.resetHouseholdInviteCode(
      householdId: row.householdId,
      householdName: row.name,
    );
    if (!mounted) return;

    final localOnly = _usingFallback || row.householdId.startsWith('draft-');
    if (!result.success && !localOnly) {
      setState(() => _busyAction = null);
      _showAdminSnackBar(
        context,
        result.message,
        backgroundColor: AppColors.accentOrange,
      );
      return;
    }

    final updated = row.copyWith(
      inviteCode: result.inviteCode ?? _generateInviteCode(),
    );
    _applyHouseholdUpdate(updated);
    setState(() => _busyAction = null);

    await _showCopyDialog(
      context,
      title: 'Invite code ready',
      description: result.success
          ? result.message
          : 'Invite code reset for this admin session only.',
      content: _buildHouseholdInviteSummary(updated),
      copyLabel: 'Copy invite',
    );
  }

  Future<void> _handleChangePlan() async {
    final row = _detail.household;
    final targetPlanCode = await _showPlanSelectionSheet(
      context,
      currentPlanCode: _normalizedPlanCode(row.plan),
    );
    if (!mounted || targetPlanCode == null) return;

    if (targetPlanCode == _normalizedPlanCode(row.plan)) {
      _showAdminSnackBar(
        context,
        '${row.name} is already on ${row.plan}.',
      );
      return;
    }

    setState(() => _busyAction = 'plan');
    final result = targetPlanCode == 'home_pro'
        ? await _repository.grantHomePro(
            householdId: row.householdId,
            householdName: row.name,
          )
        : await _repository.suspendPaidFeatures(
            householdId: row.householdId,
            householdName: row.name,
          );
    if (!mounted) return;

    final localOnly = _usingFallback || row.householdId.startsWith('draft-');
    if (!result.success && !localOnly) {
      setState(() => _busyAction = null);
      _showAdminSnackBar(
        context,
        result.message,
        backgroundColor: AppColors.accentOrange,
      );
      return;
    }

    _applyHouseholdUpdate(
      row.copyWith(
        plan: _planLabelForUi(targetPlanCode),
        status: targetPlanCode == 'home_pro' ? 'Active' : 'Cancelled',
      ),
    );
    setState(() => _busyAction = null);
    _showAdminSnackBar(
      context,
      result.success
          ? result.message
          : 'Plan updated for this admin session only.',
    );
  }

  Future<void> _handleSuspendHousehold() async {
    final row = _detail.household;
    final confirmed = await _showConfirmDialog(
      context,
      title: 'Suspend household',
      description:
          'Suspend paid features for ${row.name} and move the household back to Free plan access.',
      confirmLabel: 'Suspend',
    );
    if (!mounted || !confirmed) return;

    setState(() => _busyAction = 'suspend');
    final result = await _repository.suspendPaidFeatures(
      householdId: row.householdId,
      householdName: row.name,
    );
    if (!mounted) return;

    final localOnly = _usingFallback || row.householdId.startsWith('draft-');
    if (!result.success && !localOnly) {
      setState(() => _busyAction = null);
      _showAdminSnackBar(
        context,
        result.message,
        backgroundColor: AppColors.accentOrange,
      );
      return;
    }

    _applyHouseholdUpdate(
      row.copyWith(
        plan: 'Free',
        status: 'Cancelled',
      ),
    );
    setState(() => _busyAction = null);
    _showAdminSnackBar(
      context,
      result.success
          ? result.message
          : 'Household suspended for this admin session only.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final row = detail.household;

    return AdminContentSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => context.go('/admin/households'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to households'),
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 8),
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            '${row.location} • ${row.ownerName} • ${row.ownerEmail} • ${row.ownerPhone}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            row.inviteCode.trim().isEmpty
                                ? 'Invite code unavailable'
                                : 'Invite code: ${row.inviteCode}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _GhostAction(
                          label: 'Reset invite code',
                          icon: Icons.qr_code_2_outlined,
                          onPressed: _handleResetInviteCode,
                          isBusy: _busyAction == 'invite',
                        ),
                        _GhostAction(
                          label: 'Change plan',
                          icon: Icons.swap_horiz_outlined,
                          onPressed: _handleChangePlan,
                          isBusy: _busyAction == 'plan',
                        ),
                        _DangerAction(
                          label: 'Suspend household',
                          icon: Icons.pause_circle_outline,
                          onPressed: _handleSuspendHousehold,
                          isBusy: _busyAction == 'suspend',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(
                    _householdTabs.length,
                    (index) => InkWell(
                      onTap: () => setState(() => selectedTab = index),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selectedTab == index
                              ? AppColors.surfaceMuted
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selectedTab == index
                                ? AppColors.primaryTeal
                                : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          _householdTabs[index],
                          style: TextStyle(
                            color: selectedTab == index
                                ? AppColors.primaryTeal
                                : AppColors.textSecondary,
                            fontWeight: selectedTab == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _HouseholdDetailPanel(
                  detail: detail,
                  tab: _householdTabs[selectedTab],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final AdminRepository _repository = const AdminRepository();

  List<UserRow> _users = List<UserRow>.from(AdminMockData.userRows);
  List<HouseholdRow> _households =
      _AdminSessionStore.mergeHouseholds(AdminMockData.householdRows);
  bool _usingFallback = true;
  bool _isLoading = true;
  int _selectedFilter = 0;

  static const _filters = <String>[
    'All users',
    'Owners only',
    'House managers only',
    'Active',
    'Inactive',
    'Home Pro households',
    'Joined this month',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    var users = List<UserRow>.from(AdminMockData.userRows);
    var households = _AdminSessionStore.mergeHouseholds(AdminMockData.householdRows);
    var usingFallback = true;

    try {
      final fetchedUsers = await _repository.fetchUserRows();
      final fetchedHouseholds = await _repository.fetchHouseholdRows();
      if (fetchedUsers.isNotEmpty) {
        users = fetchedUsers;
        usingFallback = false;
      }
      if (fetchedHouseholds.isNotEmpty) {
        households = _AdminSessionStore.mergeHouseholds(fetchedHouseholds);
      }
    } catch (_) {
      usingFallback = true;
    }

    if (!mounted) return;
    setState(() {
      _users = users;
      _households = households;
      _usingFallback = usingFallback;
      _isLoading = false;
    });
  }

  HouseholdRow? _householdForUser(UserRow user) {
    for (final household in _households) {
      if (household.name == user.household ||
          _slugify(household.name) == _slugify(user.household)) {
        return household;
      }
    }
    return null;
  }

  List<UserRow> get _visibleUsers {
    switch (_selectedFilter) {
      case 1:
        return _users
            .where((user) => user.role.toLowerCase() == 'owner')
            .toList();
      case 2:
        return _users
            .where((user) => user.role.toLowerCase().contains('manager'))
            .toList();
      case 3:
        return _users.where((user) => user.status == 'Active').toList();
      case 4:
        return _users.where((user) => user.status != 'Active').toList();
      case 5:
        return _users.where((user) => user.plan == 'Home Pro').toList();
      case 6:
        return _users
            .where((user) => _isCurrentMonth(user.createdAt))
            .toList();
      default:
        return _users;
    }
  }

  Future<void> _exportUsers() async {
    await _showCopyDialog(
      context,
      title: 'Users CSV',
      description:
          'The current users table export is ready. Copy it into your CRM, support tracker, or spreadsheet.',
      content: _buildUsersCsv(_visibleUsers, _households),
      copyLabel: 'Copy CSV',
    );
  }

  Future<void> _handleResendInvite() async {
    final users = _visibleUsers;
    if (users.isEmpty) {
      _showAdminSnackBar(
        context,
        'No users match the current filter.',
        backgroundColor: AppColors.accentOrange,
      );
      return;
    }

    final user = await showDialog<UserRow>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resend invite'),
        content: SizedBox(
          width: 520,
          height: 320,
          child: ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (dialogContext, index) {
              final candidate = users[index];
              return ListTile(
                title: Text(candidate.fullName),
                subtitle: Text('${candidate.household} • ${candidate.email}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(dialogContext).pop(candidate),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (!mounted || user == null) return;

    final household = _householdForUser(user);
    if (household == null) {
      _showAdminSnackBar(
        context,
        'No household record is available for ${user.fullName}.',
        backgroundColor: AppColors.accentOrange,
      );
      return;
    }

    var inviteHousehold = household;
    if (inviteHousehold.inviteCode.trim().isEmpty) {
      inviteHousehold = inviteHousehold.copyWith(inviteCode: _generateInviteCode());
      _AdminSessionStore.upsertHousehold(inviteHousehold);
      setState(() {
        _households = _AdminSessionStore.mergeHouseholds(_households);
      });
    }

    await _showCopyDialog(
      context,
      title: 'Invite ready',
      description:
          'The invite message for ${user.fullName} is ready to resend by email, chat, or SMS.',
      content: _buildUserInviteMessage(user, inviteHousehold),
      copyLabel: 'Copy invite',
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _visibleUsers;
    return AdminContentSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Users management',
            subtitle:
                'Filter owners and house managers by status, plan, and last activity.',
            actions: [
              _GhostAction(
                label: 'Resend invite',
                icon: Icons.mark_email_unread_outlined,
                onPressed: _handleResendInvite,
              ),
              _GhostAction(
                label: 'Export users',
                icon: Icons.file_download_outlined,
                onPressed: _exportUsers,
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          FilterChipBar(
            items: _filters,
            selectedIndex: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const SizedBox(height: 16),
          TableCard(
            title: _usingFallback ? 'Platform users (fallback data)' : 'Platform users',
            columns: const [
              'Full name',
              'Email',
              'Phone',
              'Role',
              'Household',
              'Status',
              'Plan',
              'Created',
              'Last active',
            ],
            rows: users
                .map(
                  (u) => [
                    Text(u.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(u.email),
                    Text(u.phone),
                    StatusPill(label: u.role),
                    Text(u.household),
                    StatusPill(label: u.status),
                    StatusPill(label: u.plan),
                    Text(u.createdAt),
                    Text(u.lastActive),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class AdminPlansPage extends StatefulWidget {
  const AdminPlansPage({super.key});

  @override
  State<AdminPlansPage> createState() => _AdminPlansPageState();
}

class _AdminPlansPageState extends State<AdminPlansPage> {
  final AdminRepository _repository = const AdminRepository();
  late Future<List<SubscriptionRow>> _subscriptionsFuture;
  String? _busyHouseholdId;
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _subscriptionsFuture = _repository.fetchSubscriptionRows();
  }

  Future<void> _handlePlanAction({
    required SubscriptionRow subscription,
    required String actionKey,
    required String title,
    required String description,
    required Future<AdminPlanActionResult> Function() run,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(description),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _busyHouseholdId = subscription.householdId;
      _busyAction = actionKey;
    });

    final result = await run();
    if (!mounted) return;

    setState(() {
      _busyHouseholdId = null;
      _busyAction = null;
      if (result.success) {
        _subscriptionsFuture = _repository.fetchSubscriptionRows();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.success ? AppColors.primaryTeal : AppColors.accentOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SubscriptionRow>>(
      future: _subscriptionsFuture,
      builder: (context, snapshot) {
        final subscriptions = snapshot.data ?? AdminMockData.subscriptionRows;
        final usingFallback = snapshot.data == null;
        return AdminContentSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminPageHeader(
                title: 'Plans & subscriptions',
                subtitle: 'Monetization controls with usage bars, upgrades, trials, and support-grade plan operations.',
              ),
              const SizedBox(height: 16),
              ...subscriptions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.household, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text('${s.owner} • ${s.plan} • ${s.billingStatus}', style: const TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _GhostAction(
                                  label: 'Grant Home Pro',
                                  icon: Icons.north_east_outlined,
                                  isBusy: _busyHouseholdId == s.householdId &&
                                      _busyAction == 'grant',
                                  isDisabled: usingFallback,
                                  onPressed: () => _handlePlanAction(
                                    subscription: s,
                                    actionKey: 'grant',
                                    title: 'Grant Home Pro',
                                    description:
                                        'Grant Home Pro access to ${s.household} for the next 30 days. This updates the household plan directly when admin write access is configured.',
                                    run: () => _repository.grantHomePro(
                                      householdId: s.householdId,
                                      householdName: s.household,
                                    ),
                                  ),
                                ),
                                _GhostAction(
                                  label: 'Apply trial',
                                  icon: Icons.timer_outlined,
                                  isBusy: _busyHouseholdId == s.householdId &&
                                      _busyAction == 'trial',
                                  isDisabled: usingFallback,
                                  onPressed: () => _handlePlanAction(
                                    subscription: s,
                                    actionKey: 'trial',
                                    title: 'Apply Home Pro Trial',
                                    description:
                                        'Apply a 14-day Home Pro trial to ${s.household}. This is intended for onboarding or support-assisted conversions.',
                                    run: () => _repository.applyHomeProTrial(
                                      householdId: s.householdId,
                                      householdName: s.household,
                                    ),
                                  ),
                                ),
                                _DangerAction(
                                  label: 'Suspend paid features',
                                  icon: Icons.block_outlined,
                                  isBusy: _busyHouseholdId == s.householdId &&
                                      _busyAction == 'suspend',
                                  isDisabled: usingFallback,
                                  onPressed: () => _handlePlanAction(
                                    subscription: s,
                                    actionKey: 'suspend',
                                    title: 'Suspend Paid Features',
                                    description:
                                        'Suspend Home Pro access for ${s.household} and move the household back to Free plan limits.',
                                    run: () => _repository.suspendPaidFeatures(
                                      householdId: s.householdId,
                                      householdName: s.household,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: UsageBar(label: 'Bedrooms used', current: s.bedroomUsage, max: s.maxBedrooms)),
                            const SizedBox(width: 14),
                            Expanded(child: UsageBar(label: 'Supplies used', current: s.supplyUsage, max: s.maxSupplies)),
                            const SizedBox(width: 14),
                            Expanded(child: UsageBar(label: 'Children used', current: s.childUsage, max: s.maxChildren)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Started ${s.startedDate} • Expires ${s.expiryDate}', style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsViewData {
  const _AdminAnalyticsViewData({
    required this.dashboard,
    required this.subscriptions,
    required this.supportIssues,
  });

  final AdminDashboardData dashboard;
  final List<SubscriptionRow> subscriptions;
  final List<SupportIssueRow> supportIssues;
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  final AdminRepository _repository = const AdminRepository();
  late final Future<_AdminAnalyticsViewData> _analyticsFuture =
      _loadAnalyticsViewData();

  Future<_AdminAnalyticsViewData> _loadAnalyticsViewData() async {
    final dashboard = await _repository.loadDashboardData();

    List<SubscriptionRow> subscriptions;
    try {
      subscriptions = await _repository.fetchSubscriptionRows();
    } catch (_) {
      subscriptions = const <SubscriptionRow>[];
    }

    List<SupportIssueRow> supportIssues;
    try {
      supportIssues = await _repository.fetchSupportIssues();
    } catch (_) {
      supportIssues = const <SupportIssueRow>[];
    }

    return _AdminAnalyticsViewData(
      dashboard: dashboard,
      subscriptions: subscriptions.isEmpty
          ? AdminMockData.subscriptionRows
          : subscriptions,
      supportIssues: supportIssues.isEmpty
          ? AdminMockData.supportIssues
          : supportIssues,
    );
  }

  int _planPressureScore(SubscriptionRow row) {
    final bedroomRatio =
        row.maxBedrooms == 0 ? 0 : row.bedroomUsage / row.maxBedrooms;
    final supplyRatio =
        row.maxSupplies == 0 ? 0 : row.supplyUsage / row.maxSupplies;
    final childRatio = row.maxChildren == 0 ? 0 : row.childUsage / row.maxChildren;

    var highestRatio = bedroomRatio;
    if (supplyRatio > highestRatio) highestRatio = supplyRatio;
    if (childRatio > highestRatio) highestRatio = childRatio;

    var score = (highestRatio * 100).round();
    if (row.plan == 'Free') score += 10;
    if (row.billingStatus == 'Trial') score += 6;
    return score.clamp(0, 100);
  }

  int _supportPriorityRank(String priority) {
    final normalized = priority.toLowerCase();
    if (normalized.contains('critical')) return 3;
    if (normalized.contains('high')) return 2;
    if (normalized.contains('medium')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AdminAnalyticsViewData>(
      future: _analyticsFuture,
      builder: (context, snapshot) {
        final dashboard = snapshot.data?.dashboard;
        final analyticsMetrics =
            dashboard?.analyticsMetrics ?? AdminMockData.analyticsMetrics;
        final trendData = dashboard?.trendData ?? AdminMockData.trendData;
        final momentumInsights = dashboard?.momentumInsights ??
            AdminMockData.dashboardMomentumInsights;
        final moduleUsage = dashboard?.moduleUsage ?? AdminMockData.moduleUsage;
        final alerts = dashboard?.alerts ?? const <SystemAlertRow>[];
        final topUpgradeTrigger = analyticsMetrics.firstWhere(
          (metric) => metric.label == 'Most common upgrade trigger',
          orElse: () => const AnalyticsMetric(
            label: 'Most common upgrade trigger',
            value: 'No pressure yet',
            note: 'No households are close to current plan limits.',
          ),
        );

        final subscriptions = [
          ...(snapshot.data?.subscriptions ?? AdminMockData.subscriptionRows),
        ]..sort(
            (left, right) =>
                _planPressureScore(right).compareTo(_planPressureScore(left)),
          );
        final supportIssues = [
          ...(snapshot.data?.supportIssues ?? AdminMockData.supportIssues),
        ]..sort(
            (left, right) => _supportPriorityRank(right.priority)
                .compareTo(_supportPriorityRank(left.priority)),
          );

        return AdminContentSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminPageHeader(
                title: 'Usage analytics',
                subtitle:
                    'Admin-side operations, adoption, and billing pressure. The premium Home Pro intelligence experience now lives in the app itself.',
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: analyticsMetrics.length,
                itemBuilder: (context, index) =>
                    _AnalyticsMetricTile(metric: analyticsMetrics[index]),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 1120;
                  final trendCard = AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminPageHeader(
                          title: 'Platform activity trend',
                          subtitle:
                              'Seven-day movement across synced product activity, signups, upgrades, and retry pressure.',
                        ),
                        const SizedBox(height: 18),
                        SimpleLineChart(values: trendData),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: momentumInsights
                              .map(
                                (insight) => SizedBox(
                                  width: stacked ? double.infinity : 210,
                                  child: _MiniInsight(
                                    label: insight.label,
                                    value: insight.value,
                                    note: insight.note,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  );

                  final moduleCard = AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminPageHeader(
                          title: 'Module adoption',
                          subtitle:
                              'Normalized activity by product area, so admin can spot where support and product operations are really landing.',
                        ),
                        const SizedBox(height: 16),
                        ...moduleUsage.map(
                          (module) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: UsageBar(
                              label: module.label,
                              current: module.current,
                              max: module.max,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topUpgradeTrigger.value,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                topUpgradeTrigger.note,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        trendCard,
                        const SizedBox(height: 16),
                        moduleCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: trendCard),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: moduleCard),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 1120;
                  final pressureCard = AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminPageHeader(
                          title: 'Plan pressure watchlist',
                          subtitle:
                              'Free-plan squeeze, trial conversions, and premium households nearing operational ceilings.',
                        ),
                        const SizedBox(height: 16),
                        if (subscriptions.isEmpty)
                          const Text(
                            'No subscription analytics available yet.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ...subscriptions.take(3).map(
                            (row) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _PlanPressureTile(
                                row: row,
                                score: _planPressureScore(row),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );

                  final opsCard = AdminCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AdminPageHeader(
                          title: 'Support and ops signals',
                          subtitle:
                              'Platform alerts plus the highest-priority household issues for the admin team to clear next.',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Platform alerts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        if (alerts.isEmpty)
                          const Text(
                            'No active platform alerts right now.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ...alerts.take(2).map(
                            (alert) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _OpsAlertTile(alert: alert),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Support queue',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        if (supportIssues.isEmpty)
                          const Text(
                            'No support issues available.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ...supportIssues.take(3).map(
                            (issue) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SupportIssueTile(issue: issue),
                            ),
                          ),
                      ],
                    ),
                  );

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        pressureCard,
                        const SizedBox(height: 16),
                        opsCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: pressureCard),
                      const SizedBox(width: 16),
                      Expanded(child: opsCard),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsMetricTile extends StatelessWidget {
  const _AnalyticsMetricTile({required this.metric});

  final AnalyticsMetric metric;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.note,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPressureTile extends StatelessWidget {
  const _PlanPressureTile({
    required this.row,
    required this.score,
  });

  final SubscriptionRow row;
  final int score;

  @override
  Widget build(BuildContext context) {
    final tone = row.plan == 'Free'
        ? const Color(0xFFB35A00)
        : score >= 85
            ? AppColors.accentOrange
            : AppColors.primaryTeal;
    final watchLabel = row.plan == 'Free'
        ? 'Upgrade candidate'
        : row.billingStatus == 'Trial'
            ? 'Trial conversion'
            : 'Capacity watch';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.household,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.owner} • ${row.plan} • ${row.billingStatus}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$watchLabel • $score',
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          UsageBar(
            label: 'Bedrooms used',
            current: row.bedroomUsage,
            max: row.maxBedrooms,
          ),
          const SizedBox(height: 10),
          UsageBar(
            label: 'Supplies used',
            current: row.supplyUsage,
            max: row.maxSupplies,
          ),
          const SizedBox(height: 10),
          UsageBar(
            label: 'Children used',
            current: row.childUsage,
            max: row.maxChildren,
          ),
        ],
      ),
    );
  }
}

class _OpsAlertTile extends StatelessWidget {
  const _OpsAlertTile({required this.alert});

  final SystemAlertRow alert;

  @override
  Widget build(BuildContext context) {
    final tone = _signalTone(alert.severity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tone.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  alert.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                alert.severity.toUpperCase(),
                style: TextStyle(
                  color: tone,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${alert.status} • ${alert.createdAt}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportIssueTile extends StatelessWidget {
  const _SupportIssueTile({required this.issue});

  final SupportIssueRow issue;

  @override
  Widget build(BuildContext context) {
    final tone = _signalTone(issue.priority);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  issue.priority,
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${issue.household} • ${issue.category} • ${issue.status}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${issue.user} • ${issue.assignedAdmin} • ${issue.createdAt}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

Color _signalTone(String severity) {
  final normalized = severity.toLowerCase();
  if (normalized.contains('critical')) return AppColors.accentOrange;
  if (normalized.contains('high') || normalized.contains('warning')) {
    return const Color(0xFFB35A00);
  }
  return AppColors.primaryTeal;
}

class AdminPresetsPage extends StatefulWidget {
  const AdminPresetsPage({super.key});

  @override
  State<AdminPresetsPage> createState() => _AdminPresetsPageState();
}

class _AdminPresetsPageState extends State<AdminPresetsPage> {
  final AdminRepository _repository = const AdminRepository();

  List<PresetCategory> _categories =
      _AdminSessionStore.mergePresets(AdminMockData.presetCategories);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    var categories = _AdminSessionStore.mergePresets(AdminMockData.presetCategories);
    try {
      final fetchedCategories = await _repository.fetchPresetCategories();
      if (fetchedCategories.isNotEmpty) {
        categories = _AdminSessionStore.mergePresets(fetchedCategories);
      }
    } catch (_) {
      // Keep session-backed fallback data.
    }

    _AdminSessionStore.syncPresets(categories);

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  Future<void> _handleAddPreset() async {
    final draft = await _showPresetEditorDialog(context);
    if (!mounted || draft == null) return;

    _AdminSessionStore.upsertPreset(
      PresetCategory(title: draft.title, items: draft.items),
    );
    setState(() {
      _categories = _AdminSessionStore.mergePresets(_categories);
    });
    _showAdminSnackBar(context, 'Preset added for this admin session.');
  }

  Future<void> _handleEditPreset(PresetCategory category) async {
    final draft = await _showPresetEditorDialog(
      context,
      initial: _PresetDraft(title: category.title, items: category.items),
    );
    if (!mounted || draft == null) return;

    _AdminSessionStore.upsertPreset(
      PresetCategory(title: draft.title, items: draft.items),
      originalTitle: category.title,
    );
    setState(() {
      _categories = _AdminSessionStore.mergePresets(_categories);
    });
    _showAdminSnackBar(context, 'Preset updated for this admin session.');
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    return AdminContentSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Presets & system content',
            subtitle:
                'Live content catalog sourced from household sync data and notification templates.',
            actions: [
              _GhostAction(
                label: 'Add preset',
                icon: Icons.add_circle_outline,
                onPressed: _handleAddPreset,
              ),
            ],
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.25,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _handleEditPreset(category),
                          tooltip: 'Edit preset',
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...category.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 7,
                              color: AppColors.primaryTeal,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() =>
      _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  final AdminRepository _repository = const AdminRepository();

  List<NotificationRow> _rows = List<NotificationRow>.from(AdminMockData.notificationRows);
  bool _usingFallback = true;
  bool _isLoading = true;
  int _selectedFilter = 0;

  static const _filters = <String>[
    'All',
    'Unread',
    'Failures',
    'Warnings',
    'Inventory',
    'Billing',
    'Laundry',
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    var rows = List<NotificationRow>.from(AdminMockData.notificationRows);
    var usingFallback = true;
    try {
      final fetchedRows = await _repository.fetchNotificationRows();
      if (fetchedRows.isNotEmpty) {
        rows = fetchedRows;
        usingFallback = false;
      }
    } catch (_) {
      usingFallback = true;
    }

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _usingFallback = usingFallback;
      _isLoading = false;
    });
  }

  List<NotificationRow> get _visibleRows {
    switch (_selectedFilter) {
      case 1:
        return _rows.where((row) => row.readState == 'Unread').toList();
      case 2:
        return _rows
            .where((row) => row.result.toLowerCase().contains('fail'))
            .toList();
      case 3:
        return _rows.where((row) => row.severity == 'Warning').toList();
      case 4:
        return _rows.where((row) => row.type == 'Inventory').toList();
      case 5:
        return _rows.where((row) => row.type == 'Billing').toList();
      case 6:
        return _rows.where((row) => row.type == 'Laundry').toList();
      default:
        return _rows;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRows;
    return AdminContentSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Notifications center',
            subtitle:
                'See what is being sent, whether it is read, and where notification noise or failures appear.',
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          FilterChipBar(
            items: _filters,
            selectedIndex: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const SizedBox(height: 16),
          TableCard(
            title: _usingFallback
                ? 'Recent notification activity (fallback data)'
                : 'Recent notification activity',
            columns: const [
              'Template',
              'User',
              'Household',
              'Type',
              'Severity',
              'Read state',
              'Result',
            ],
            rows: rows
                .map(
                  (n) => [
                    Text(n.template),
                    Text(n.user),
                    Text(n.household),
                    StatusPill(label: n.type),
                    StatusPill(label: n.severity),
                    StatusPill(label: n.readState),
                    Text(n.result),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> {
  final AdminRepository _repository = const AdminRepository();

  List<SupportIssueRow> _issues = List<SupportIssueRow>.from(AdminMockData.supportIssues);
  bool _usingFallback = true;
  bool _isLoading = true;
  int _selectedFilter = 0;

  static const _filters = <String>[
    'Open',
    'In progress',
    'Resolved',
    'Login issue',
    'Subscription issue',
    'Laundry bug',
    'Meal logging issue',
  ];

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    var issues = List<SupportIssueRow>.from(AdminMockData.supportIssues);
    var usingFallback = true;
    try {
      final fetchedIssues = await _repository.fetchSupportIssues();
      if (fetchedIssues.isNotEmpty) {
        issues = fetchedIssues;
        usingFallback = false;
      }
    } catch (_) {
      usingFallback = true;
    }

    if (!mounted) return;
    setState(() {
      _issues = issues;
      _usingFallback = usingFallback;
      _isLoading = false;
    });
  }

  List<SupportIssueRow> get _visibleIssues {
    switch (_selectedFilter) {
      case 0:
        return _issues.where((issue) => issue.status == 'Open').toList();
      case 1:
        return _issues.where((issue) => issue.status == 'In progress').toList();
      case 2:
        return _issues.where((issue) => issue.status == 'Resolved').toList();
      case 3:
        return _issues
            .where((issue) => issue.category.toLowerCase().contains('login'))
            .toList();
      case 4:
        return _issues
            .where((issue) => issue.category.toLowerCase().contains('subscription'))
            .toList();
      case 5:
        return _issues
            .where((issue) => issue.category.toLowerCase().contains('laundry'))
            .toList();
      case 6:
        return _issues
            .where((issue) => issue.category.toLowerCase().contains('meal'))
            .toList();
      default:
        return _issues;
    }
  }

  @override
  Widget build(BuildContext context) {
    final issues = _visibleIssues;
    return AdminContentSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Support / issue handling',
            subtitle:
                'Ticket-style workflow for login, subscription, shopping, laundry, meals, and notification issues.',
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          FilterChipBar(
            items: _filters,
            selectedIndex: _selectedFilter,
            onSelected: (index) => setState(() => _selectedFilter = index),
          ),
          const SizedBox(height: 16),
          TableCard(
            title: _usingFallback ? 'Support queue (fallback data)' : 'Support queue',
            columns: const [
              'Issue',
              'Household',
              'User',
              'Category',
              'Priority',
              'Status',
              'Assigned',
              'Created',
            ],
            rows: issues
                .map(
                  (issue) => [
                    Text(issue.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(issue.household),
                    Text(issue.user),
                    StatusPill(label: issue.category),
                    StatusPill(label: issue.priority),
                    StatusPill(label: issue.status),
                    Text(issue.assignedAdmin),
                    Text(issue.createdAt),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class AdminActivityLogsPage extends StatelessWidget {
  const AdminActivityLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ActivityLogRow>>(
      future: const AdminRepository().fetchActivityLogs(),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? AdminMockData.activityLogs;
        return AdminContentSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminPageHeader(
                title: 'Activity logs / audit trail',
                subtitle: 'Audit actions by user, household, entity, date/time, and metadata preview.',
              ),
              const SizedBox(height: 16),
              TableCard(
                title: 'Recent activity',
                columns: const ['User', 'Household', 'Action', 'Entity', 'Date/time', 'Metadata'],
                rows: rows
                    .map(
                      (log) => [
                        Text(log.user, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(log.household),
                        Text(log.action),
                        Text(log.entity),
                        Text(log.datetime),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(log.metadata, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminUsersManagementPage extends StatelessWidget {
  const AdminUsersManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminRoleRow>>(
      future: const AdminRepository().fetchAdminUsers(),
      builder: (context, snapshot) {
        final admins = snapshot.data ?? AdminMockData.adminUsers;
        return AdminContentSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminPageHeader(
                title: 'Admin users',
                subtitle: 'Manage internal admins and role-based access for support, billing, and content operations.',
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 1300 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: const [
                  _RoleCard(title: 'Super Admin', features: ['Everything', 'Can suspend households', 'Can change billing logic', 'Can edit presets']),
                  _RoleCard(title: 'Support Admin', features: ['View households/users', 'Handle support', 'View activity', 'Cannot change billing logic']),
                  _RoleCard(title: 'Billing Admin', features: ['Manage subscriptions', 'Apply trials', 'Complimentary access', 'Cannot edit product presets']),
                  _RoleCard(title: 'Content Admin', features: ['Manage presets', 'Edit templates', 'Improve onboarding content', 'Cannot suspend households']),
                ],
              ),
              const SizedBox(height: 16),
              TableCard(
                title: 'Current admin accounts',
                columns: const ['Name', 'Role', 'Scope', 'Last active', 'Status'],
                rows: admins
                    .map(
                      (admin) => [
                        Text(admin.name),
                        StatusPill(label: admin.role),
                        Text(admin.scope),
                        Text(admin.lastActive),
                        StatusPill(label: admin.status),
                      ],
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SettingsItem>>(
      future: const AdminRepository().fetchSettingsItems(),
      builder: (context, snapshot) {
        final items = snapshot.data?.isNotEmpty == true
            ? snapshot.data!
            : AdminMockData.settingsItems;
        return AdminContentSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminPageHeader(
                title: 'Settings',
                subtitle: 'Operational configuration snapshot for admin access, limits, and monitoring defaults.',
              ),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AdminCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(item.description, style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        StatusPill(label: item.value),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AdminPlaceholderPage extends StatelessWidget {
  const AdminPlaceholderPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdminContentSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.features,
  });

  final String title;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryTeal),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.path,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final String path;
}

class _CreateHouseholdDraft {
  const _CreateHouseholdDraft({
    required this.name,
    required this.location,
    required this.planCode,
  });

  final String name;
  final String location;
  final String planCode;
}

class _PresetDraft {
  const _PresetDraft({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;
}

class _AdminSessionStore {
  static final List<HouseholdRow> _householdOverrides = <HouseholdRow>[];
  static List<PresetCategory>? _presetSnapshot;

  static List<HouseholdRow> mergeHouseholds(List<HouseholdRow> base) {
    final merged = List<HouseholdRow>.from(base);
    for (final row in _householdOverrides) {
      final index = merged.indexWhere(
        (item) =>
            item.householdId == row.householdId ||
            _slugify(item.name) == _slugify(row.name),
      );
      if (index == -1) {
        merged.insert(0, row);
      } else {
        merged[index] = row;
      }
    }
    return merged;
  }

  static HouseholdRow? householdByIdentifier(String identifier) {
    for (final row in mergeHouseholds(AdminMockData.householdRows)) {
      if (row.householdId == identifier ||
          row.name == identifier ||
          _slugify(row.name) == _slugify(identifier)) {
        return row;
      }
    }
    return null;
  }

  static void upsertHousehold(HouseholdRow row) {
    final index = _householdOverrides.indexWhere(
      (item) =>
          item.householdId == row.householdId ||
          _slugify(item.name) == _slugify(row.name),
    );
    if (index == -1) {
      _householdOverrides.insert(0, row);
    } else {
      _householdOverrides[index] = row;
    }
  }

  static List<PresetCategory> mergePresets(List<PresetCategory> base) {
    return List<PresetCategory>.from(_presetSnapshot ?? base);
  }

  static void syncPresets(List<PresetCategory> categories) {
    _presetSnapshot ??= List<PresetCategory>.from(categories);
  }

  static void upsertPreset(
    PresetCategory category, {
    String? originalTitle,
  }) {
    final categories = List<PresetCategory>.from(
      _presetSnapshot ?? AdminMockData.presetCategories,
    );

    if (originalTitle != null) {
      categories.removeWhere(
        (item) => _slugify(item.title) == _slugify(originalTitle),
      );
    }

    final index = categories.indexWhere(
      (item) => _slugify(item.title) == _slugify(category.title),
    );
    if (index == -1) {
      categories.insert(0, category);
    } else {
      categories[index] = category;
    }
    _presetSnapshot = categories;
  }
}

String _generateInviteCode() {
  const uuid = Uuid();
  return uuid.v4().substring(0, 8).toUpperCase();
}

String _normalizedPlanCode(String plan) {
  final normalized = plan.toLowerCase().replaceAll(' ', '_');
  if (normalized.contains('home') || normalized.contains('pro')) {
    return 'home_pro';
  }
  return 'free';
}

String _planLabelForUi(String planCode) {
  return _normalizedPlanCode(planCode) == 'home_pro' ? 'Home Pro' : 'Free';
}

String _formatAdminDate(DateTime date) {
  return DateFormat('dd MMM yyyy').format(date);
}

bool _isCurrentMonth(String label) {
  for (final pattern in const ['dd MMM yyyy', 'd MMM yyyy']) {
    try {
      final date = DateFormat(pattern).parseStrict(label.trim());
      final now = DateTime.now();
      return date.year == now.year && date.month == now.month;
    } catch (_) {
      // Try the next supported format.
    }
  }
  return false;
}

void _showAdminSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? AppColors.primaryTeal,
    ),
  );
}

Future<bool> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String description,
  String confirmLabel = 'Continue',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _showCopyDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String content,
  String copyLabel = 'Copy',
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: SingleChildScrollView(child: SelectableText(content)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: content));
            if (context.mounted) {
              _showAdminSnackBar(context, 'Copied to clipboard.');
            }
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          icon: const Icon(Icons.copy_all_rounded),
          label: Text(copyLabel),
        ),
      ],
    ),
  );
}

Future<_CreateHouseholdDraft?> _showCreateHouseholdDialog(
  BuildContext context,
) async {
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  var planCode = 'free';
  String? errorText;

  final result = await showDialog<_CreateHouseholdDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Add household'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Household name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Optional support label',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: planCode,
                decoration: const InputDecoration(labelText: 'Starting plan'),
                items: const [
                  DropdownMenuItem(value: 'free', child: Text('Free')),
                  DropdownMenuItem(value: 'home_pro', child: Text('Home Pro')),
                ],
                onChanged: (value) {
                  setDialogState(() => planCode = value ?? 'free');
                },
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: AppColors.accentOrange),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setDialogState(() {
                  errorText = 'Household name is required.';
                });
                return;
              }

              Navigator.of(dialogContext).pop(
                _CreateHouseholdDraft(
                  name: name,
                  location: locationController.text.trim(),
                  planCode: planCode,
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );

  nameController.dispose();
  locationController.dispose();
  return result;
}

Future<String?> _showPlanSelectionSheet(
  BuildContext context, {
  required String currentPlanCode,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Move to Home Pro'),
            subtitle:
                const Text('Enable premium limits and support-assisted access.'),
            trailing: currentPlanCode == 'home_pro'
                ? const Icon(Icons.check_rounded, color: AppColors.primaryTeal)
                : null,
            onTap: () => Navigator.of(sheetContext).pop('home_pro'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_open_rounded),
            title: const Text('Move to Free'),
            subtitle:
                const Text('Return the household to free-plan access and limits.'),
            trailing: currentPlanCode == 'free'
                ? const Icon(Icons.check_rounded, color: AppColors.primaryTeal)
                : null,
            onTap: () => Navigator.of(sheetContext).pop('free'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<_PresetDraft?> _showPresetEditorDialog(
  BuildContext context, {
  _PresetDraft? initial,
}) async {
  final titleController = TextEditingController(text: initial?.title ?? '');
  final itemsController = TextEditingController(
    text: initial?.items.join('\n') ?? '',
  );
  String? errorText;

  final result = await showDialog<_PresetDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(initial == null ? 'Add preset' : 'Edit preset'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Category title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: itemsController,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Items',
                  hintText: 'One preset item per line',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: AppColors.accentOrange),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final items = _splitPresetItems(itemsController.text);
              if (title.isEmpty || items.isEmpty) {
                setDialogState(() {
                  errorText = 'Both a title and at least one item are required.';
                });
                return;
              }

              Navigator.of(dialogContext).pop(
                _PresetDraft(title: title, items: items),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  titleController.dispose();
  itemsController.dispose();
  return result;
}

List<String> _splitPresetItems(String raw) {
  return raw
      .split(RegExp(r'[\n,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _buildHouseholdCsv(List<HouseholdRow> households) {
  return _buildCsv(
    const [
      'Household',
      'Owner',
      'Owner email',
      'Invite code',
      'Plan',
      'Members',
      'Children',
      'Supplies',
      'Zones',
      'Status',
      'Created',
    ],
    households
        .map(
          (household) => [
            household.name,
            household.ownerName,
            household.ownerEmail,
            household.inviteCode,
            household.plan,
            '${household.members}',
            '${household.children}',
            '${household.supplies}',
            '${household.zones}',
            household.status,
            household.createdDate,
          ],
        )
        .toList(),
  );
}

String _buildUsersCsv(List<UserRow> users, List<HouseholdRow> households) {
  HouseholdRow? householdFor(String name) {
    for (final household in households) {
      if (household.name == name || _slugify(household.name) == _slugify(name)) {
        return household;
      }
    }
    return null;
  }

  return _buildCsv(
    const [
      'Full name',
      'Email',
      'Phone',
      'Role',
      'Household',
      'Invite code',
      'Status',
      'Plan',
      'Created',
      'Last active',
    ],
    users
        .map(
          (user) {
            final household = householdFor(user.household);
            return [
              user.fullName,
              user.email,
              user.phone,
              user.role,
              user.household,
              household?.inviteCode ?? '',
              user.status,
              user.plan,
              user.createdAt,
              user.lastActive,
            ];
          },
        )
        .toList(),
  );
}

String _buildCsv(List<String> headers, List<List<String>> rows) {
  final lines = <String>[
    headers.map(_escapeCsvCell).join(','),
    ...rows.map((row) => row.map(_escapeCsvCell).join(',')),
  ];
  return lines.join('\n');
}

String _escapeCsvCell(String value) {
  final sanitized = value.replaceAll('"', '""');
  if (sanitized.contains(',') ||
      sanitized.contains('"') ||
      sanitized.contains('\n')) {
    return '"$sanitized"';
  }
  return sanitized;
}

String _buildHouseholdInviteSummary(HouseholdRow household) {
  return [
    'Household: ${household.name}',
    'Invite code: ${household.inviteCode}',
    'Plan: ${household.plan}',
    '',
    'Send this code to the owner or house manager so they can join the household in HomeFlow.',
  ].join('\n');
}

String _buildUserInviteMessage(UserRow user, HouseholdRow household) {
  return [
    'Hi ${user.fullName},',
    '',
    'You have been invited to join ${household.name} on HomeFlow.',
    'Invite code: ${household.inviteCode}',
    '',
    'Open the app, choose Join household, and enter the invite code above.',
  ].join('\n');
}

AdminHouseholdDetailData _withUpdatedHouseholdDetail(
  AdminHouseholdDetailData detail,
  HouseholdRow household,
) {
  final billing = [
    AdminDetailItem(
      title: 'Current plan',
      subtitle: '${household.plan} • ${household.status}',
      status: household.plan,
      meta: 'Created ${household.createdDate}',
      note:
          'Invite ${household.inviteCode.isEmpty ? 'Unavailable' : household.inviteCode} • Usage ${(household.usage * 100).round()}% • ${household.children} children • ${household.supplies} supplies • ${household.zones} zones',
    ),
    ...detail.billing.where((item) => item.title != 'Current plan'),
  ];

  return detail.copyWith(
    household: household,
    billing: billing,
  );
}

String _slugify(String input) => input.toLowerCase().replaceAll(' ', '-');

const _householdTabs = [
  'Overview',
  'Members',
  'Children',
  'Supplies',
  'Shopping',
  'Meals',
  'Laundry',
  'Notifications',
  'Billing',
  'Activity log',
];

class _HouseholdLinkButton extends StatelessWidget {
  const _HouseholdLinkButton({required this.row});

  final HouseholdRow row;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => context.go('/admin/households/${_slugify(row.name)}'),
      child: const Text('Open household'),
    );
  }
}

class _HouseholdDetailPanel extends StatelessWidget {
  const _HouseholdDetailPanel({required this.detail, required this.tab});

  final AdminHouseholdDetailData detail;
  final String tab;

  @override
  Widget build(BuildContext context) {
    final row = detail.household;
    final items = detail.itemsForTab(tab);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tab, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(
            tab == 'Overview'
                ? 'Support-friendly household snapshot with the most important operational and billing signals for this home.'
                : 'Live $tab data for this household pulled from the synced app records and admin operations tables.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          if (tab == 'Overview')
            Row(
              children: [
                Expanded(
                  child: _MiniInsight(
                    label: 'Household status',
                    value: row.status,
                    note: row.status == 'Active' ? 'No current restrictions' : 'Requires admin review',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniInsight(
                    label: 'Current plan',
                    value: row.plan,
                    note: row.plan == 'Home Pro' ? 'Premium features active' : 'Upgrade available',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniInsight(
                    label: 'Household usage',
                    value: '${(row.usage * 100).round()}%',
                    note: row.status == 'Upgrade candidate'
                        ? 'At or above plan limits'
                        : '${row.supplies} supplies, ${row.children} children, ${row.zones} zones',
                  ),
                ),
              ],
            )
          else
            _HouseholdDetailItemsList(tab: tab, items: items),
        ],
      ),
    );
  }
}

class _HouseholdDetailItemsList extends StatelessWidget {
  const _HouseholdDetailItemsList({required this.tab, required this.items});

  final String tab;
  final List<AdminDetailItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _MetricBullet(
        label: 'No recent $tab data',
        value: 'This household has no synced $tab records yet.',
      );
    }

    return Column(
      children: [
        for (final item in items) ...[
          _HouseholdDetailItemCard(item: item),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _HouseholdDetailItemCard extends StatelessWidget {
  const _HouseholdDetailItemCard({required this.item});

  final AdminDetailItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.subtitle, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                if (item.note?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(item.note!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                ],
              ],
            ),
          ),
          if (item.status != null || item.meta != null) ...[
            const SizedBox(width: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.status?.trim().isNotEmpty == true)
                    StatusPill(label: item.status!),
                  if (item.meta?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(item.meta!, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

AdminHouseholdDetailData _fallbackHouseholdDetail(String identifier) {
  final householdRows =
      _AdminSessionStore.mergeHouseholds(AdminMockData.householdRows);
  final household = householdRows.firstWhere(
    (row) => row.householdId == identifier || row.name == identifier || _slugify(row.name) == identifier,
    orElse: () => AdminMockData.householdRows.first,
  );
  final matchingUsers = AdminMockData.userRows
      .where((row) => row.household == household.name)
      .map(
        (row) => AdminDetailItem(
          title: row.fullName,
          subtitle: row.email,
          status: row.role,
          meta: row.lastActive,
        ),
      )
      .toList();
  final matchingNotifications = AdminMockData.notificationRows
      .where((row) => row.household == household.name)
      .map(
        (row) => AdminDetailItem(
          title: row.template,
          subtitle: row.user,
          status: row.severity,
          meta: row.readState,
          note: row.result,
        ),
      )
      .toList();
  final matchingActivity = AdminMockData.activityLogs
      .where((row) => row.household == household.name)
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
  final matchingSubscription = AdminMockData.subscriptionRows.firstWhere(
    (row) => row.household == household.name,
    orElse: () => SubscriptionRow(
      householdId: household.householdId,
      household: household.name,
      owner: household.ownerName,
      plan: household.plan,
      billingStatus: household.status,
      maxBedrooms: household.zones,
      maxSupplies: household.supplies,
      maxChildren: household.children,
      bedroomUsage: household.zones,
      supplyUsage: household.supplies,
      childUsage: household.children,
      startedDate: household.createdDate,
      expiryDate: '—',
    ),
  );

  return AdminHouseholdDetailData(
    household: household,
    members: matchingUsers,
    children: [
      AdminDetailItem(
        title: '${household.children} children tracked',
        subtitle: 'Live child records will appear here once household child sync is available.',
      ),
    ],
    supplies: [
      AdminDetailItem(
        title: '${household.supplies} supplies tracked',
        subtitle: 'Live inventory rows are pending for this fallback household view.',
      ),
    ],
    shopping: const [],
    meals: const [],
    laundry: [
      AdminDetailItem(
        title: '${household.zones} laundry zones',
        subtitle: 'Recent laundry batches will appear here when synced records exist.',
      ),
    ],
    notifications: matchingNotifications,
    billing: [
      AdminDetailItem(
        title: 'Current plan',
        subtitle: '${matchingSubscription.plan} • ${matchingSubscription.billingStatus}',
        status: matchingSubscription.plan,
        meta: 'Expires ${matchingSubscription.expiryDate}',
      ),
    ],
    activityLog: matchingActivity,
  );
}

class _MiniInsight extends StatelessWidget {
  const _MiniInsight({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 4),
          Text(note, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MetricBullet extends StatelessWidget {
  const _MetricBullet({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 8, color: AppColors.primaryTeal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: value, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.title, required this.subtitle, required this.severity});

  final String title;
  final String subtitle;
  final String severity;

  @override
  Widget build(BuildContext context) {
    final critical = severity == 'critical';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: critical ? const Color(0xFFFFEFEA) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(critical ? Icons.error_outline : Icons.warning_amber_rounded, color: critical ? AppColors.accentOrange : const Color(0xFF8A6A00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.log});

  final ActivityLogRow log;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: AppColors.primaryTeal, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.action, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${log.user} • ${log.household}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Text(log.metadata, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Text(log.datetime, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isBusy = false,
    this.isDisabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final callback = isBusy || isDisabled ? null : (onPressed ?? () {});
    return OutlinedButton.icon(
      onPressed: callback,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _DangerAction extends StatelessWidget {
  const _DangerAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isBusy = false,
    this.isDisabled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final callback = isBusy || isDisabled ? null : (onPressed ?? () {});
    return FilledButton.icon(
      onPressed: callback,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
