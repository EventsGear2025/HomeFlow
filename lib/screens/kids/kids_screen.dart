import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/child_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_colors.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/status_chips.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KIDS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class KidsScreen extends StatefulWidget {
  const KidsScreen({super.key});

  @override
  State<KidsScreen> createState() => _KidsScreenState();
}

class _KidsScreenState extends State<KidsScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  // ── date strip helpers ─────────────────────────────────────────────────────

  String _formatDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    if (day == tomorrow) return 'Tomorrow';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[d.weekday - 1];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final childProvider = context.watch<ChildProvider>();
    final auth = context.watch<AuthProvider>();
    final children = childProvider.children;

    final today = DateTime.now();
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    final todayLogs = children
        .map((child) => childProvider.getLogForDate(child.id, _selectedDate))
        .whereType<ChildRoutineLog>()
        .toList();
    final readyCount = todayLogs.where((log) => log.checkedCount >= 4).length;
    final snackCount = children.where((c) => c.snackRequired).length;

    // 7-day strip: today + 3 future + 3 past
    final stripDates = List.generate(7, (i) {
      return DateTime(today.year, today.month, today.day).add(Duration(days: 1 - i));
    }).reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Kids & School'),
        actions: [
          if (auth.isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Add child',
              onPressed: () => _showAddChildSheet(context),
            ),
        ],
      ),
      floatingActionButton: auth.isOwner
          ? FloatingActionButton.extended(
              heroTag: 'kids_fab',
              backgroundColor: AppColors.primaryTeal,
              onPressed: () => _showAddChildSheet(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Child',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: childProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── 7-day date strip ──────────────────────────────────────
                Container(
                  color: AppColors.white,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 72,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          itemCount: stripDates.length,
                          itemBuilder: (ctx, i) {
                            final d = stripDates[i];
                            final selected = _isSameDay(d, _selectedDate);
                            final isToday =
                                _isSameDay(d, DateTime.now());
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedDate = d),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primaryTeal
                                      : AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primaryTeal
                                        : isToday
                                            ? AppColors.primaryTeal
                                                .withValues(alpha: 0.4)
                                            : AppColors.divider,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatDay(d),
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
                                      '${d.day}/${d.month}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: selected
                                            ? AppColors.white
                                                .withAlpha(200)
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
                    ],
                  ),
                ),

                // ── Body ─────────────────────────────────────────────────
                Expanded(
                  child: children.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.child_care_outlined,
                          title: 'No children added yet',
                          subtitle: auth.isOwner
                              ? 'Add your children to track their daily school routine'
                              : 'The household owner has not added any children yet',
                          buttonLabel: auth.isOwner ? 'Add Child' : null,
                          onButton: auth.isOwner
                              ? () => _showAddChildSheet(context)
                              : null,
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _KidsOverviewCard(
                              totalChildren: children.length,
                              readyCount: readyCount,
                              snackCount: snackCount,
                              date: _selectedDate,
                            ),
                            const SizedBox(height: 16),
                            ...childProvider.children.map(
                              (child) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ChildCard(
                                  child: child,
                                  selectedDate: _selectedDate,
                                ),
                              ),
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  void _showAddChildSheet(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final childProvider = context.read<ChildProvider>();
    final hasReachedFreeLimit =
        !auth.isHomePro &&
        childProvider.children.length >= AppConstants.freeMaxChildren;
    if (hasReachedFreeLimit) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: PlanUpsellCard(
            title: 'Add more than 2 children',
            subtitle:
                'Free households can track up to 2 children. Upgrade to Home Pro to add unlimited children and unlock deeper household analytics.',
            onPressed: () {
              Navigator.pop(context);
              openHomeProUpgrade(context, source: 'kids_limit');
            },
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddChildSheet(),
    );
  }
}

class _KidsOverviewCard extends StatelessWidget {
  final int totalChildren;
  final int readyCount;
  final int snackCount;
  final DateTime date;

  const _KidsOverviewCard({
    required this.totalChildren,
    required this.readyCount,
    required this.snackCount,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalChildren == 0 ? 0.0 : readyCount / totalChildren;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondaryTeal, AppColors.primaryTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.school_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'School readiness',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$readyCount of $totalChildren child${totalChildren == 1 ? '' : 'ren'} ready',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OverviewPill(
                  icon: Icons.groups_2_outlined,
                  label:
                      '$totalChildren child${totalChildren == 1 ? '' : 'ren'}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewPill(
                  icon: Icons.cookie_outlined,
                  label: '$snackCount need snack',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverviewPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatefulWidget {
  final ChildModel child;
  final DateTime selectedDate;
  const _ChildCard({required this.child, required this.selectedDate});

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final childProvider = context.read<ChildProvider>();
    final auth = context.read<AuthProvider>();

    final today = DateTime.now();
    var log = childProvider.getLogForDate(widget.child.id, widget.selectedDate);

    if (log == null) {
      const uuid = Uuid();
      log = ChildRoutineLog(
        id: uuid.v4(),
        childId: widget.child.id,
        date: widget.selectedDate,
        updatedByUserId: auth.currentUser?.id ?? '',
      );
    }

    final readyCount = log.checkedCount;
    final totalChecks = widget.child.snackRequired ? 7 : 6;
    final isReady = readyCount >= 4;
    final isToday = widget.selectedDate.year == today.year &&
        widget.selectedDate.month == today.month &&
        widget.selectedDate.day == today.day;

    return HomeFlowCard(
      borderColor: isReady
          ? AppColors.statusEnoughText.withValues(alpha: 0.22)
          : AppColors.primaryTeal.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.child.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.child.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.child.schoolName != null)
                        Text(
                          widget.child.schoolName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ChildMetaChip(
                            icon: Icons.rule_folder_outlined,
                            label: widget.child.className ?? 'Class not set',
                          ),
                          _ChildMetaChip(
                            icon: Icons.access_time_outlined,
                            label:
                                widget.child.dropoffTime != null &&
                                    widget.child.pickupTime != null
                                ? '${widget.child.dropoffTime} • ${widget.child.pickupTime}'
                                : 'Times not set',
                          ),
                          if (widget.child.snackRequired)
                            const _ChildMetaChip(
                              icon: Icons.cookie_outlined,
                              label: 'Snack needed',
                              highlight: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                ReadinessChip(
                  isReady: isReady,
                  label: isReady ? 'Ready' : 'In Progress',
                ),
                if (auth.isOwner) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditChildSheet(context, widget.child);
                      } else if (value == 'delete') {
                        _confirmDeleteChild(context);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text('Edit Child'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 16,
                                color: Colors.red.shade400),
                            const SizedBox(width: 8),
                            Text(
                              'Remove Child',
                              style: TextStyle(color: Colors.red.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isReady
                    ? AppColors.statusEnough.withValues(alpha: 0.5)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isReady
                      ? AppColors.statusEnoughText.withValues(alpha: 0.18)
                      : AppColors.divider,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s routine progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$readyCount of $totalChecks checks completed',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: totalChecks == 0 ? 0 : readyCount / totalChecks,
                        minHeight: 8,
                        backgroundColor: AppColors.divider,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryTeal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CheckItem(
              label: 'Uniform Ready',
              icon: Icons.checkroom_outlined,
              value: log.uniformReady,
              onChanged: (v) {
                log!.uniformReady = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            _CheckItem(
              label: 'Shoes & Socks Ready',
              icon: Icons.directions_walk_outlined,
              value: log.shoesReady,
              onChanged: (v) {
                log!.shoesReady = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            _CheckItem(
              label: 'Lunch Packed',
              icon: Icons.lunch_dining_outlined,
              value: log.lunchPacked,
              onChanged: (v) {
                log!.lunchPacked = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            if (widget.child.snackRequired)
              _CheckItem(
                label: 'Snack Packed',
                icon: Icons.cookie_outlined,
                value: log.snackPacked,
                onChanged: (v) {
                  log!.snackPacked = v;
                  childProvider.updateRoutineLog(log, auth.household!.id);
                  setState(() {});
                },
              ),
            _CheckItem(
              label: 'Swimwear Ready',
              icon: Icons.pool_outlined,
              value: log.swimwearReady,
              onChanged: (v) {
                log!.swimwearReady = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            const Divider(height: 20),
            _CheckItem(
              label: 'Dropped at School',
              icon: Icons.directions_bus_outlined,
              value: log.droppedOff,
              onChanged: (v) {
                log!.droppedOff = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            _CheckItem(
              label: 'Picked Up',
              icon: Icons.home_outlined,
              value: log.pickedUp,
              onChanged: (v) {
                log!.pickedUp = v;
                childProvider.updateRoutineLog(log, auth.household!.id);
                setState(() {});
              },
            ),
            // ── School needs for next day ──────────────────────────────
            const SizedBox(height: 8),
            _SchoolNeedsSection(
              child: widget.child,
              isToday: isToday,
            ),
          ],
        ],
      ),
    );
  }

  void _showEditChildSheet(BuildContext context, ChildModel child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditChildSheet(child: child),
    );
  }

  void _confirmDeleteChild(BuildContext context) {
    final childProvider = context.read<ChildProvider>();
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Remove child?'),
        content: Text(
          'Are you sure you want to remove "${widget.child.name}" and all their routine logs? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              childProvider.deleteChild(
                widget.child.id,
                auth.household!.id,
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCHOOL NEEDS SECTION — shown inside each child card
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolNeedsSection extends StatefulWidget {
  final ChildModel child;
  final bool isToday;

  const _SchoolNeedsSection({required this.child, required this.isToday});

  @override
  State<_SchoolNeedsSection> createState() => _SchoolNeedsSectionState();
}

class _SchoolNeedsSectionState extends State<_SchoolNeedsSection> {
  final _needCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _needCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childProvider = context.watch<ChildProvider>();
    final auth = context.read<AuthProvider>();
    final needs = childProvider.upcomingNeedsForChild(widget.child.id);

    if (needs.isEmpty && !widget.isToday) return const SizedBox.shrink();

    final tomorrow = DateTime.now().add(const Duration(days: 1));

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: needs.isNotEmpty
              ? AppColors.accentOrange.withValues(alpha: 0.25)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.backpack_outlined,
                  size: 15, color: AppColors.accentOrange),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'School bag — needs for next day',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentOrange,
                  ),
                ),
              ),
              if (widget.isToday)
                GestureDetector(
                  onTap: () => setState(() => _adding = !_adding),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _adding ? Icons.close : Icons.add,
                          size: 13,
                          color: AppColors.primaryTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _adding ? 'Cancel' : 'Add',
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
          if (_adding) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _needCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'e.g. PE kit, permission slip…',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _submitNeed(
                        context, childProvider, auth, tomorrow),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () =>
                      _submitNeed(context, childProvider, auth, tomorrow),
                  child: const Text('Add',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          if (needs.isEmpty && !_adding)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Nothing logged yet. Tap + Add to log items needed for school tomorrow.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (needs.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...needs.map((need) => _NeedRow(
                  need: need,
                  onResolved: () => childProvider.markSchoolNeedResolved(
                      need.id, auth.household!.id),
                  onDelete: () => childProvider.deleteSchoolNeed(
                      need.id, auth.household!.id),
                )),
          ],
        ],
      ),
    );
  }

  void _submitNeed(BuildContext context, ChildProvider childProvider,
      AuthProvider auth, DateTime needDate) {
    final text = _needCtrl.text.trim();
    if (text.isEmpty) return;
    const uuid = Uuid();
    childProvider.addSchoolNeed(
      ChildSchoolNeed(
        id: uuid.v4(),
        childId: widget.child.id,
        householdId: auth.household!.id,
        itemName: text,
        neededForDate: needDate,
        createdAt: DateTime.now(),
      ),
      auth.household!.id,
    );
    _needCtrl.clear();
    setState(() => _adding = false);
  }
}

class _NeedRow extends StatelessWidget {
  final ChildSchoolNeed need;
  final VoidCallback onResolved;
  final VoidCallback onDelete;

  const _NeedRow({
    required this.need,
    required this.onResolved,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: onResolved,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: need.isResolved
                    ? AppColors.statusEnoughText
                    : AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: need.isResolved
                      ? AppColors.statusEnoughText
                      : AppColors.divider,
                ),
              ),
              child: need.isResolved
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              need.itemName,
              style: TextStyle(
                fontSize: 13,
                color: need.isResolved
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration:
                    need.isResolved ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textHint,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 15, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _ChildMetaChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? AppColors.accentYellow.withValues(alpha: 0.2)
        : AppColors.surfaceLight;
    final fg = highlight ? AppColors.accentOrange : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight
              ? AppColors.accentOrange.withValues(alpha: 0.18)
              : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckItem({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primaryTeal.withValues(alpha: 0.05)
              : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AppColors.primaryTeal.withValues(alpha: 0.18)
                : AppColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: value ? AppColors.primaryTeal : AppColors.textHint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: value
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  decoration: value ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textHint,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.primaryTeal
                    : AppColors.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: value ? AppColors.primaryTeal : AppColors.divider,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, color: AppColors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChildSheet extends StatefulWidget {
  const _AddChildSheet();

  @override
  State<_AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<_AddChildSheet> {
  final _nameCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _dropoffCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  bool _snackRequired = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _classCtrl.dispose();
    _dropoffCtrl.dispose();
    _pickupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final childProvider = context.read<ChildProvider>();

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Child',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track school readiness, meals, and routine handoffs.',
                      style: TextStyle(
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Child\'s name'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _schoolCtrl,
              decoration: const InputDecoration(
                labelText: 'School name (optional)',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _classCtrl,
              decoration: const InputDecoration(
                labelText: 'Class / Grade (optional)',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimePickerField(
                    controller: _dropoffCtrl,
                    label: 'Drop-off time',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerField(
                    controller: _pickupCtrl,
                    label: 'Pick-up time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Requires school snack?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enable this if snacks should appear in readiness checks.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _snackRequired,
                    onChanged: (v) => setState(() => _snackRequired = v),
                    activeColor: AppColors.primaryTeal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) return;
                final hasReachedFreeLimit =
                    !auth.isHomePro &&
                    childProvider.children.length >=
                        AppConstants.freeMaxChildren;
                if (hasReachedFreeLimit) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Free households can track up to 2 children. Upgrade to Home Pro to add more.',
                      ),
                    ),
                  );
                  return;
                }
                const uuid = Uuid();
                final child = ChildModel(
                  id: uuid.v4(),
                  householdId: auth.household!.id,
                  name: _nameCtrl.text.trim(),
                  schoolName: _schoolCtrl.text.trim().isEmpty
                      ? null
                      : _schoolCtrl.text.trim(),
                  className: _classCtrl.text.trim().isEmpty
                      ? null
                      : _classCtrl.text.trim(),
                  dropoffTime: _dropoffCtrl.text.trim().isEmpty
                      ? null
                      : _dropoffCtrl.text.trim(),
                  pickupTime: _pickupCtrl.text.trim().isEmpty
                      ? null
                      : _pickupCtrl.text.trim(),
                  snackRequired: _snackRequired,
                );
                childProvider.addChild(child, auth.household!.id);
                Navigator.pop(context);
              },
              child: const Text('Add Child'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT CHILD SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _EditChildSheet extends StatefulWidget {
  final ChildModel child;
  const _EditChildSheet({required this.child});

  @override
  State<_EditChildSheet> createState() => _EditChildSheetState();
}

class _EditChildSheetState extends State<_EditChildSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _schoolCtrl;
  late final TextEditingController _classCtrl;
  late final TextEditingController _dropoffCtrl;
  late final TextEditingController _pickupCtrl;
  late bool _snackRequired;

  @override
  void initState() {
    super.initState();
    final c = widget.child;
    _nameCtrl = TextEditingController(text: c.name);
    _schoolCtrl = TextEditingController(text: c.schoolName ?? '');
    _classCtrl = TextEditingController(text: c.className ?? '');
    _dropoffCtrl = TextEditingController(text: c.dropoffTime ?? '');
    _pickupCtrl = TextEditingController(text: c.pickupTime ?? '');
    _snackRequired = c.snackRequired;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _schoolCtrl.dispose();
    _classCtrl.dispose();
    _dropoffCtrl.dispose();
    _pickupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final childProvider = context.read<ChildProvider>();

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Child',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Update name, school details and routine settings.',
                      style: TextStyle(
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration:
                  const InputDecoration(labelText: 'Child\'s name'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _schoolCtrl,
              decoration: const InputDecoration(
                labelText: 'School name (optional)',
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _classCtrl,
              decoration: const InputDecoration(
                labelText: 'Class / Grade (optional)',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimePickerField(
                    controller: _dropoffCtrl,
                    label: 'Drop-off time',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerField(
                    controller: _pickupCtrl,
                    label: 'Pick-up time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Requires school snack?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enable if snacks should appear in readiness checks.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _snackRequired,
                    onChanged: (v) => setState(() => _snackRequired = v),
                    activeColor: AppColors.primaryTeal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) return;
                final updated = widget.child.copyWith(
                  name: _nameCtrl.text.trim(),
                  schoolName: _schoolCtrl.text.trim().isEmpty
                      ? null
                      : _schoolCtrl.text.trim(),
                  className: _classCtrl.text.trim().isEmpty
                      ? null
                      : _classCtrl.text.trim(),
                  dropoffTime: _dropoffCtrl.text.trim().isEmpty
                      ? null
                      : _dropoffCtrl.text.trim(),
                  pickupTime: _pickupCtrl.text.trim().isEmpty
                      ? null
                      : _pickupCtrl.text.trim(),
                  snackRequired: _snackRequired,
                );
                childProvider.updateChild(updated, auth.household!.id);
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIME PICKER FIELD
// Tappable read-only field that opens the native time picker dialog.
// ─────────────────────────────────────────────────────────────────────────────

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  /// Parse "h:mm AM/PM" back to a TimeOfDay for pre-selection.
  TimeOfDay _parseTime() {
    final text = controller.text.trim();
    if (text.isEmpty) return TimeOfDay.now();
    try {
      final upper = text.toUpperCase();
      final isPm = upper.contains('PM');
      final cleaned = upper.replaceAll(RegExp(r'[APM\s]'), '');
      final parts = cleaned.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return TimeOfDay.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        FocusScope.of(context).unfocus();
        final picked = await showTimePicker(
          context: context,
          initialTime: _parseTime(),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
        if (picked != null) {
          controller.text = picked.format(context);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.access_time_rounded, size: 18),
      ),
    );
  }
}
