import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/staff_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final staff = context.watch<StaffProvider>();
    final auth = context.watch<AuthProvider>();
    final isHomePro = auth.isHomePro;

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
      body: staff.isLoading
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
          : _StaffBody(schedule: staff.schedule!, isOwner: auth.isOwner),
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
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isOwner ? 'Assign a Task' : 'Add a Task',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g. Iron clothes, Water plants…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onSubmitted: (_) => _submit(ctx, ctrl, isOwner),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => _submit(ctx, ctrl, isOwner),
            child: Text(isOwner ? 'Assign' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext ctx, TextEditingController ctrl, bool isOwner) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    ctx.read<TaskProvider>().addTask(text, isOwner ? 'owner' : 'manager');
    Navigator.pop(ctx);
  }
}

class _TaskRow extends StatelessWidget {
  final dynamic task; // TaskItem
  final bool isOwner;
  const _TaskRow({required this.task, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final taskProv = context.read<TaskProvider>();
    final checked = task.isDone as bool;
    final addedBy = task.addedBy as String;

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
              onChanged: (_) => taskProv.toggleTask(task.id as String),
            ),
          ),
          // Title
          Expanded(
            child: Text(
              task.title as String,
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
          // Added-by badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: addedBy == 'owner'
                  ? AppColors.accentOrange.withAlpha(25)
                  : AppColors.primaryTeal.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              addedBy == 'owner' ? 'Owner' : 'Me',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: addedBy == 'owner'
                    ? AppColors.accentOrange
                    : AppColors.primaryTeal,
              ),
            ),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.close, size: 14, color: AppColors.textHint),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            splashRadius: 18,
            onPressed: () => taskProv.removeTask(task.id as String),
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
