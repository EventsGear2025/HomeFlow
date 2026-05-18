import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/staff_schedule.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../models/task_item.dart';
import '../../providers/task_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh household members so newly joined managers are visible
    // immediately when the owner opens this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().refreshHouseholdMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffProvider>();
    final auth = context.watch<AuthProvider>();
    final isHomePro = auth.isHomePro;

    final Widget scheduleSection = staff.isLoading
        ? const Center(child: CircularProgressIndicator())
        : !isHomePro
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: PlanUpsellCard(
                  title: 'Staff scheduling is available on Home Pro',
                  subtitle:
                      'Upgrade to create and manage staff schedules, availability, leave periods, and replacement planning.',
                  onPressed: () =>
                      openHomeProUpgrade(context, source: 'staff_schedule'),
                ),
              )
            : staff.schedule == null
                ? _NoStaffView(isOwner: auth.isOwner)
                : _StaffBody(schedule: staff.schedule!, isOwner: auth.isOwner);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Staff'),
        actions: [
          if (auth.isOwner && isHomePro)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Schedule',
              onPressed: () => _showEditSheet(context, staff.schedule),
            ),
        ],
      ),
      // For the owner: always show the linked-managers section at the top
      // so they can see who has joined via invite code (and refresh live).
      // The schedule section appears below.
      body: auth.isOwner
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LinkedManagersSection(managers: auth.managers),
                Expanded(child: scheduleSection),
              ],
            )
          : scheduleSection,
    );
  }

  void _showEditSheet(BuildContext context, StaffSchedule? current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditScheduleSheet(current: current),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LINKED MANAGERS SECTION (owner-only, always shown at top)
// ═══════════════════════════════════════════════════════════════

class _LinkedManagersSection extends StatelessWidget {
  final List<UserModel> managers;
  const _LinkedManagersSection({required this.managers});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HOUSE MANAGERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          if (managers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No house manager has joined yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ShareInviteCodeButton(),
                ],
              ),
            )
          else
            ...managers.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        AppColors.primaryTeal.withValues(alpha: 0.12),
                    child: Text(
                      m.fullName.isNotEmpty
                          ? m.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  title: Text(
                    m.fullName.isEmpty ? 'House Manager' : m.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: m.email.isNotEmpty
                      ? Text(
                          m.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.statusEnough,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.statusEnoughText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textSecondary, size: 18),
                    ],
                  ),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => _ManagerProfileSheet(manager: m),
                  ),
                ),
              ),
            ),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NO STAFF VIEW
// ═══════════════════════════════════════════════════════════════

class _NoStaffView extends StatelessWidget {
  final bool isOwner;
  const _NoStaffView({required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.person_outline,
      title: 'No staff assigned',
      subtitle: isOwner
          ? 'Add your house manager or staff member to track their schedule'
          : 'Your household owner has not set up a staff profile yet',
      buttonLabel: isOwner ? 'Add Staff' : null,
      onButton: isOwner
          ? () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const _EditScheduleSheet(current: null),
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MAIN BODY
// ═══════════════════════════════════════════════════════════════

class _StaffBody extends StatelessWidget {
  final StaffSchedule schedule;
  final bool isOwner;

  const _StaffBody({required this.schedule, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Profile hero card ──────────────────────────────────
        _ProfileCard(schedule: schedule),
        const SizedBox(height: 16),

        _StaffOverviewStrip(schedule: schedule, isOwner: isOwner),
        const SizedBox(height: 16),

        // ── Status card ────────────────────────────────────────
        _StatusCard(schedule: schedule, isOwner: isOwner),
        const SizedBox(height: 24),

        // ── Schedule details ───────────────────────────────────
        const _StaffSectionLabel(title: 'Schedule Details'),
        const SizedBox(height: 10),
        _ScheduleDetailsCard(schedule: schedule),
        const SizedBox(height: 24),

        // ── Owner-only: Quick status update ───────────────────
        if (isOwner) ...[
          const _StaffSectionLabel(title: 'Update Status'),
          const SizedBox(height: 10),
          _StatusUpdater(schedule: schedule),
          const SizedBox(height: 24),
        ],

        // ── Daily tasks (owner assigns, manager tracks) ────────
        _StaffSectionLabel(
          title: isOwner ? 'Manager\'s Tasks Today' : 'Your Tasks Today',
        ),
        const SizedBox(height: 10),
        _DailyTasksCard(isOwner: isOwner),
        const SizedBox(height: 24),

        // ── Notes ──────────────────────────────────────────────
        if (schedule.notes != null && schedule.notes!.isNotEmpty) ...[
          const _StaffSectionLabel(title: 'Notes'),
          const SizedBox(height: 10),
          HomeFlowCard(
            child: Text(
              schedule.notes!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Last updated ───────────────────────────────────────
        Center(
          child: Text(
            'Last updated ${_formatDate(schedule.updatedAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  String _formatDate(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d);
}

class _StaffOverviewStrip extends StatelessWidget {
  final StaffSchedule schedule;
  final bool isOwner;

  const _StaffOverviewStrip({required this.schedule, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final leaveDays =
        schedule.leaveStartDate != null && schedule.leaveEndDate != null
        ? schedule.leaveEndDate!.difference(schedule.leaveStartDate!).inDays + 1
        : null;

    return Row(
      children: [
        Expanded(
          child: _MiniInfoCard(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: isOwner ? 'Manager profile' : 'Your profile',
            color: AppColors.primaryTeal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniInfoCard(
            icon: Icons.event_available_outlined,
            label: 'Day off',
            value: schedule.recurringOffDay ?? 'Not set',
            color: AppColors.statusLowText,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniInfoCard(
            icon: Icons.date_range_outlined,
            label: 'Leave',
            value: leaveDays == null
                ? 'None'
                : '$leaveDays day${leaveDays == 1 ? '' : 's'}',
            color: AppColors.accentOrange,
          ),
        ),
      ],
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniInfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffSectionLabel extends StatelessWidget {
  final String title;

  const _StaffSectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PROFILE CARD
// ═══════════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final StaffSchedule schedule;
  const _ProfileCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final isOnDuty = schedule.isOnDuty;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnDuty
              ? [AppColors.primaryTeal, AppColors.secondaryTeal]
              : [AppColors.textSecondary, Colors.grey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                schedule.userName.isNotEmpty
                    ? schedule.userName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'House Manager',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          _StatusBadge(status: schedule.workStatus),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final WorkStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  (String, Color, Color) _statusStyle(WorkStatus s) {
    switch (s) {
      case WorkStatus.onDuty:
        return ('On Duty', AppColors.statusEnough, AppColors.statusEnoughText);
      case WorkStatus.offDay:
        return ('Off Day', Colors.blue.shade50, Colors.blue.shade700);
      case WorkStatus.onLeave:
        return ('On Leave', AppColors.statusLow, AppColors.statusLowText);
      case WorkStatus.sick:
        return ('Sick', AppColors.statusVeryLow, AppColors.statusVeryLowText);
      case WorkStatus.away:
        return ('Away', AppColors.surfaceLight, AppColors.textSecondary);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// STATUS CARD
// ═══════════════════════════════════════════════════════════════

class _StatusCard extends StatelessWidget {
  final StaffSchedule schedule;
  final bool isOwner;
  const _StatusCard({required this.schedule, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final isOnDuty = schedule.isOnDuty;
    final highlightColor = isOnDuty
        ? AppColors.statusEnoughText
        : AppColors.accentOrange;
    final helperText = isOwner
        ? isOnDuty
              ? 'Your house manager is available for today\'s tasks.'
              : 'You may need to confirm cover, rearrange chores, or update the status.'
        : isOnDuty
        ? 'You are marked available and ready for today\'s work.'
        : 'You are currently marked unavailable for regular work today.';

    return HomeFlowCard(
      borderColor: isOnDuty
          ? AppColors.statusEnoughText.withValues(alpha: 0.3)
          : AppColors.accentOrange.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOnDuty
                  ? AppColors.statusEnough
                  : AppColors.statusVeryLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOnDuty ? Icons.check_circle_outline : Icons.info_outline,
              color: isOnDuty
                  ? AppColors.statusEnoughText
                  : AppColors.statusVeryLowText,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnDuty ? 'Available today' : 'Not available today',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: highlightColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  helperText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (schedule.recurringOffDay != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Regular day off: ${schedule.recurringOffDay}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (schedule.leaveStartDate != null &&
                    schedule.leaveEndDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Leave: ${_fmt(schedule.leaveStartDate!)} – ${_fmt(schedule.leaveEndDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isOnDuty && schedule.replacementArranged)
            const Tooltip(
              message: 'Replacement arranged',
              child: Icon(
                Icons.swap_horiz,
                color: AppColors.primaryTeal,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => DateFormat('d MMM').format(d);
}

// ═══════════════════════════════════════════════════════════════
// SCHEDULE DETAILS CARD
// ═══════════════════════════════════════════════════════════════

class _ScheduleDetailsCard extends StatelessWidget {
  final StaffSchedule schedule;
  const _ScheduleDetailsCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return HomeFlowCard(
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'Name',
            value: schedule.userName,
          ),
          _DetailDivider(),
          _DetailRow(
            icon: Icons.work_outline,
            label: 'Status',
            value: _workStatusLabel(schedule.workStatus),
          ),
          if (schedule.recurringOffDay != null) ...[
            _DetailDivider(),
            _DetailRow(
              icon: Icons.event_available_outlined,
              label: 'Day Off',
              value: schedule.recurringOffDay!,
            ),
          ],
          if (schedule.leaveStartDate != null) ...[
            _DetailDivider(),
            _DetailRow(
              icon: Icons.date_range_outlined,
              label: 'Leave From',
              value: DateFormat('d MMM yyyy').format(schedule.leaveStartDate!),
            ),
          ],
          if (schedule.leaveEndDate != null) ...[
            _DetailDivider(),
            _DetailRow(
              icon: Icons.event_outlined,
              label: 'Leave Until',
              value: DateFormat('d MMM yyyy').format(schedule.leaveEndDate!),
            ),
          ],
          _DetailDivider(),
          _DetailRow(
            icon: Icons.swap_horiz,
            label: 'Replacement',
            value: schedule.replacementArranged ? 'Arranged ✓' : 'Not arranged',
            valueColor: schedule.replacementArranged
                ? AppColors.statusEnoughText
                : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  String _workStatusLabel(WorkStatus s) {
    switch (s) {
      case WorkStatus.onDuty:
        return 'On Duty';
      case WorkStatus.offDay:
        return 'Off Day';
      case WorkStatus.onLeave:
        return 'On Leave';
      case WorkStatus.sick:
        return 'Sick';
      case WorkStatus.away:
        return 'Away';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.divider);
}

// ═══════════════════════════════════════════════════════════════
// OWNER: QUICK STATUS UPDATER
// ═══════════════════════════════════════════════════════════════

class _StatusUpdater extends StatelessWidget {
  final StaffSchedule schedule;
  const _StatusUpdater({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set current status',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use this when plans change so the dashboard and reminders stay accurate.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: WorkStatus.values.map((s) {
              final selected = schedule.workStatus == s;
              final (label, bg, fg) = _chipStyle(s);
              return GestureDetector(
                onTap: () {
                  final auth = context.read<AuthProvider>();
                  final staffProv = context.read<StaffProvider>();
                  staffProv.updateSchedule(
                    schedule.copyWith(workStatus: s),
                    auth.household!.id,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? bg : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? fg : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? fg : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  (String, Color, Color) _chipStyle(WorkStatus s) {
    switch (s) {
      case WorkStatus.onDuty:
        return ('On Duty', AppColors.statusEnough, AppColors.statusEnoughText);
      case WorkStatus.offDay:
        return ('Off Day', Colors.blue.shade50, Colors.blue.shade700);
      case WorkStatus.onLeave:
        return ('On Leave', AppColors.statusLow, AppColors.statusLowText);
      case WorkStatus.sick:
        return ('Sick', AppColors.statusVeryLow, AppColors.statusVeryLowText);
      case WorkStatus.away:
        return ('Away', AppColors.surfaceLight, AppColors.textSecondary);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARE INVITE CODE BUTTON (owner-only, shown when no manager linked)
// ─────────────────────────────────────────────────────────────────────────────

class _ShareInviteCodeButton extends StatelessWidget {
  const _ShareInviteCodeButton();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final code = auth.ownerInviteCode;
    if (code.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryTeal.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_outlined,
              color: AppColors.primaryTeal, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share this code with your house manager',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sign-up code copied ✓')),
              );
            },
            icon: const Icon(Icons.copy_outlined, size: 15),
            label: const Text('Copy'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryTeal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DAILY TASKS CARD (owner assigns, manager tracks)
// ═══════════════════════════════════════════════════════════════

class _DailyTasksCard extends StatelessWidget {
  final bool isOwner;
  const _DailyTasksCard({required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final today = tasks.todayTasks;
    final done = tasks.todayDoneCount;
    final total = tasks.todayTotalCount;
    final allDone = total > 0 && done == total;

    return HomeFlowCard(
      borderColor: allDone
          ? AppColors.statusEnoughText.withValues(alpha: 0.25)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  total == 0
                      ? 'No tasks yet today'
                      : '$done / $total tasks done',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: allDone
                        ? AppColors.statusEnoughText
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (allDone)
                const Icon(
                  Icons.celebration_outlined,
                  color: AppColors.statusEnoughText,
                  size: 18,
                ),
              // Add task button
              GestureDetector(
                onTap: () => _showAddTaskDialog(context, isOwner),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryTeal.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add,
                        size: 14,
                        color: AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOwner ? 'Assign task' : 'Add task',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            allDone
                ? 'Everything on the list is done for today. 🎉'
                : isOwner
                ? 'Assign tasks below — the manager can check them off.'
                : 'Knock these out to keep the home day running smoothly.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 5,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(
                  allDone ? AppColors.statusEnoughText : AppColors.primaryTeal,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          if (today.isEmpty) const _EmptyTasksHint(),

          // ── Task rows ───────────────────────────────────────
          ...today.map((task) => _TaskRow(task: task, isOwner: isOwner)),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, bool isOwner) {
    showDialog(
      context: context,
      builder: (ctx) => _AddTaskDialog(isOwner: isOwner),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskItem task;
  final bool isOwner;
  const _TaskRow({required this.task, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final taskProv = context.read<TaskProvider>();
    final checked = task.isDone;
    final addedBy = task.addedBy;

    // Label: show from the viewer's perspective
    final String byLabel;
    final Color byColor;
    if (addedBy == 'owner') {
      byLabel = isOwner ? 'Me' : 'Owner';
      byColor = AppColors.accentOrange;
    } else {
      byLabel = isOwner ? 'Manager' : 'Me';
      byColor = AppColors.primaryTeal;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: checked
            ? AppColors.statusEnough.withValues(alpha: 0.4)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked
              ? AppColors.statusEnoughText.withValues(alpha: 0.18)
              : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          // Checkbox
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Checkbox(
              value: checked,
              activeColor: AppColors.primaryTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (_) => taskProv.toggleTask(task.id),
            ),
          ),
          // Title
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: checked ? FontWeight.w400 : FontWeight.w500,
                decoration: checked
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: AppColors.textHint,
                color: checked ? AppColors.textHint : AppColors.textPrimary,
              ),
            ),
          ),
          // Recurring icon — tappable to toggle
          GestureDetector(
            onTap: () => taskProv.toggleRecurring(task.id),
            child: Tooltip(
              message: task.isRecurring ? 'Repeats daily — tap to stop' : 'Tap to repeat daily',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  task.isRecurring
                      ? Icons.repeat_rounded
                      : Icons.repeat_outlined,
                  size: 16,
                  color: task.isRecurring
                      ? AppColors.primaryTeal
                      : AppColors.textHint,
                ),
              ),
            ),
          ),
          // Added-by badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: byColor.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              byLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: byColor,
              ),
            ),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.close, size: 14, color: AppColors.textHint),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            splashRadius: 18,
            onPressed: () => taskProv.removeTask(task.id),
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksHint extends StatelessWidget {
  const _EmptyTasksHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          'No tasks added yet — tap "Add task" to start.',
          style: TextStyle(fontSize: 12, color: AppColors.textHint),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ADD TASK DIALOG — with Repeat daily toggle
// ═══════════════════════════════════════════════════════════════

class _AddTaskDialog extends StatefulWidget {
  final bool isOwner;
  const _AddTaskDialog({required this.isOwner});

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _ctrl = TextEditingController();
  bool _recurring = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    context.read<TaskProvider>().addTask(
          text,
          widget.isOwner ? 'owner' : 'manager',
          isRecurring: _recurring,
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.isOwner ? 'Assign a Task' : 'Add a Task',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g. Iron clothes, Water plants…',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _recurring = !_recurring),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _recurring
                        ? Icons.repeat_rounded
                        : Icons.repeat_outlined,
                    size: 18,
                    color: _recurring
                        ? AppColors.primaryTeal
                        : AppColors.textHint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Repeat daily',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _recurring
                                ? AppColors.primaryTeal
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Task reappears fresh every morning',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _recurring,
                    activeColor: AppColors.primaryTeal,
                    onChanged: (v) => setState(() => _recurring = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryTeal,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: const Size(0, 40),
          ),
          onPressed: _submit,
          child: Text(widget.isOwner ? 'Assign' : 'Add'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EDIT / ADD SCHEDULE SHEET  (owner only)
// ═══════════════════════════════════════════════════════════════

class _EditScheduleSheet extends StatefulWidget {
  final StaffSchedule? current;
  const _EditScheduleSheet({required this.current});

  @override
  State<_EditScheduleSheet> createState() => _EditScheduleSheetState();
}

class _EditScheduleSheetState extends State<_EditScheduleSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late WorkStatus _status;
  String? _offDay;
  DateTime? _leaveStart;
  DateTime? _leaveEnd;
  bool _replacementArranged = false;

  static const _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _nameCtrl = TextEditingController(text: c?.userName ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _status = c?.workStatus ?? WorkStatus.onDuty;
    _offDay = c?.recurringOffDay;
    _leaveStart = c?.leaveStartDate;
    _leaveEnd = c?.leaveEndDate;
    _replacementArranged = c?.replacementArranged ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.current == null
                          ? 'Add Staff Member'
                          : 'Edit Schedule',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.current == null
                          ? 'Set availability, regular day off, and backup notes.'
                          : 'Update the current schedule so statuses stay accurate.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: widget.current == null,
            ),
            const SizedBox(height: 14),

            // Status
            DropdownButtonFormField<WorkStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Work status',
                prefixIcon: Icon(Icons.work_outline),
              ),
              items: WorkStatus.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(_statusLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 14),

            // Recurring day off
            DropdownButtonFormField<String?>(
              value: _offDay,
              decoration: const InputDecoration(
                labelText: 'Regular day off (optional)',
                prefixIcon: Icon(Icons.event_available_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ..._daysOfWeek.map(
                  (d) => DropdownMenuItem(value: d, child: Text(d)),
                ),
              ],
              onChanged: (v) => setState(() => _offDay = v),
            ),
            const SizedBox(height: 14),

            // Leave dates row
            Row(
              children: [
                Expanded(
                  child: _DatePicker(
                    label: 'Leave from',
                    value: _leaveStart,
                    onPicked: (d) => setState(() => _leaveStart = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePicker(
                    label: 'Leave until',
                    value: _leaveEnd,
                    onPicked: (d) => setState(() => _leaveEnd = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Replacement arranged toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Replacement arranged',
                style: TextStyle(fontSize: 14),
              ),
              value: _replacementArranged,
              activeColor: AppColors.primaryTeal,
              onChanged: (v) => setState(() => _replacementArranged = v),
            ),
            const SizedBox(height: 8),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _save,
                child: Text(
                  widget.current == null ? 'Add Staff' : 'Save Changes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the staff member\'s name')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final staffProv = context.read<StaffProvider>();
    const uuid = Uuid();

    final schedule = StaffSchedule(
      id: widget.current?.id ?? uuid.v4(),
      householdId: auth.household!.id,
      userId: widget.current?.userId ?? uuid.v4(),
      userName: _nameCtrl.text.trim(),
      workStatus: _status,
      recurringOffDay: _offDay,
      leaveStartDate: _leaveStart,
      leaveEndDate: _leaveEnd,
      replacementArranged: _replacementArranged,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );

    staffProv.updateSchedule(schedule, auth.household!.id);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.current == null
              ? '${schedule.userName} added'
              : 'Schedule updated',
        ),
        backgroundColor: AppColors.primaryTeal,
      ),
    );
  }

  String _statusLabel(WorkStatus s) {
    switch (s) {
      case WorkStatus.onDuty:
        return 'On Duty';
      case WorkStatus.offDay:
        return 'Off Day';
      case WorkStatus.onLeave:
        return 'On Leave';
      case WorkStatus.sick:
        return 'Sick';
      case WorkStatus.away:
        return 'Away';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// DATE PICKER HELPER
// ═══════════════════════════════════════════════════════════════

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;

  const _DatePicker({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(
                ctx,
              ).colorScheme.copyWith(primary: AppColors.primaryTeal),
            ),
            child: child!,
          ),
        );
        onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textHint,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? DateFormat('d MMM yyyy').format(value!) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MANAGER PROFILE SHEET (owner-only, tap a manager to open)
// ═══════════════════════════════════════════════════════════════

class _ManagerProfileSheet extends StatefulWidget {
  final UserModel manager;
  const _ManagerProfileSheet({required this.manager});

  @override
  State<_ManagerProfileSheet> createState() => _ManagerProfileSheetState();
}

class _ManagerProfileSheetState extends State<_ManagerProfileSheet> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _totalLeaveCtrl;
  late final TextEditingController _takenLeaveCtrl;
  late final TextEditingController _notesCtrl;
  DateTime? _startDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.manager;
    _idCtrl = TextEditingController(text: m.idNumber ?? '');
    _totalLeaveCtrl =
        TextEditingController(text: m.leaveDaysTotal.toString());
    _takenLeaveCtrl =
        TextEditingController(text: m.leaveDaysTaken.toString());
    _notesCtrl = TextEditingController(text: m.managerNotes ?? '');
    _startDate = m.startDate;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _totalLeaveCtrl.dispose();
    _takenLeaveCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final total = int.tryParse(_totalLeaveCtrl.text.trim()) ?? 21;
    final taken = int.tryParse(_takenLeaveCtrl.text.trim()) ?? 0;
    await context.read<AuthProvider>().updateManagerProfile(
          userId: widget.manager.id,
          idNumber: _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
          startDate: _startDate,
          leaveDaysTotal: total,
          leaveDaysTaken: taken,
          managerNotes:
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.manager;
    final remaining =
        (int.tryParse(_totalLeaveCtrl.text) ?? m.leaveDaysTotal) -
            (int.tryParse(_takenLeaveCtrl.text) ?? m.leaveDaysTaken);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        AppColors.primaryTeal.withValues(alpha: 0.12),
                    child: Text(
                      m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.fullName.isEmpty ? 'House Manager' : m.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (m.email.isNotEmpty)
                          Text(
                            m.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // ID Number
              const Text('National ID / Passport Number',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _idCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. 12345678',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),

              // Start Date
              const Text('Start Date',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickStartDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        _startDate != null
                            ? DateFormat('d MMM yyyy').format(_startDate!)
                            : 'Select start date',
                        style: TextStyle(
                          color: _startDate != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Leave Days
              const Text('Leave Days',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Annual Entitlement',
                            style: TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _totalLeaveCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffixText: 'days',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Days Taken', style: TextStyle(fontSize: 11)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _takenLeaveCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffixText: 'days',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: remaining > 0
                      ? AppColors.statusEnough
                      : AppColors.statusFinished,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$remaining days remaining',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: remaining > 0
                        ? AppColors.statusEnoughText
                        : AppColors.statusFinishedText,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              const Text('Notes',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g. skills, emergency contact, salary notes...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY TASKS FULL SCREEN (navigated to from dashboard "View all tasks")
// ─────────────────────────────────────────────────────────────────────────────

class DailyTasksScreen extends StatefulWidget {
  const DailyTasksScreen({super.key});

  @override
  State<DailyTasksScreen> createState() => _DailyTasksScreenState();
}

class _DailyTasksScreenState extends State<DailyTasksScreen> {
  late String _selectedKey;

  @override
  void initState() {
    super.initState();
    _selectedKey = TaskProvider.todayKey();
  }

  String _formatKey(String key) {
    final d = DateTime.parse(key);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    if (d.year == today.year && d.month == today.month && d.day == today.day) {
      return 'Today';
    }
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) {
      return 'Yesterday';
    }
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final taskProv = context.watch<TaskProvider>();
    final isOwner = auth.isOwner;

    final todayKey = TaskProvider.todayKey();
    final now = DateTime.now();

    // Fixed 7-day window: today → 6 days back, always shown regardless of data
    final windowKeys = List.generate(7, (i) {
      final d = now.subtract(Duration(days: i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });

    // Append any older stored keys (beyond 7 days) that have data
    final olderKeys = taskProv.availableDateKeys
        .where((k) => !windowKeys.contains(k))
        .toList();
    final keys = [...windowKeys, ...olderKeys];

    final forDay = taskProv.tasksForDate(_selectedKey);
    final done = forDay.where((t) => t.isDone).length;
    final total = forDay.length;
    final isToday = _selectedKey == todayKey;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text(isOwner ? "Manager's Tasks" : 'Tasks'),
      ),
      body: Column(
        children: [
          // ── Date strip ──────────────────────────────────────────
          Container(
            color: AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: keys.length,
                    itemBuilder: (ctx, i) {
                      final key = keys[i];
                      final selected = key == _selectedKey;
                      final dayTasks = taskProv.tasksForDate(key);
                      final dayDone = dayTasks.where((t) => t.isDone).length;
                      final dayTotal = dayTasks.length;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedKey = key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryTeal
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primaryTeal
                                  : AppColors.divider,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatKey(key),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dayTotal == 0
                                    ? 'No tasks'
                                    : dayDone == dayTotal
                                        ? 'All done ✓'
                                        : '$dayDone/$dayTotal done',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected
                                      ? AppColors.white.withAlpha(200)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: AppColors.divider),
              ],
            ),
          ),
          // ── Task list for selected day ──────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Show progress header
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          '$done of $total tasks done',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : done / total,
                              minHeight: 5,
                              backgroundColor: AppColors.divider,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                done == total
                                    ? AppColors.statusEnoughText
                                    : AppColors.primaryTeal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // For today show the full interactive card
                // For past days show a read-only list
                if (isToday)
                  _DailyTasksCard(isOwner: isOwner)
                else if (forDay.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text(
                        'No tasks recorded for this day.',
                        style: TextStyle(fontSize: 13, color: AppColors.textHint),
                      ),
                    ),
                  )
                else
                  ...forDay.map(
                    (t) => _HistoryTaskRow(task: t, isOwner: isOwner),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Read-only task row for past days
class _HistoryTaskRow extends StatelessWidget {
  final TaskItem task;
  final bool isOwner;
  const _HistoryTaskRow({required this.task, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final addedBy = task.addedBy;
    final String byLabel;
    final Color byColor;
    if (addedBy == 'owner') {
      byLabel = isOwner ? 'Me' : 'Owner';
      byColor = AppColors.accentOrange;
    } else {
      byLabel = isOwner ? 'Manager' : 'Me';
      byColor = AppColors.primaryTeal;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: task.isDone ? AppColors.primaryTeal : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: task.isDone ? AppColors.primaryTeal : AppColors.textHint,
                width: 1.5,
              ),
            ),
            child: task.isDone
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                color: task.isDone ? AppColors.textHint : AppColors.textPrimary,
                decoration:
                    task.isDone ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: byColor.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              byLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: byColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
