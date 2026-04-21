import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/laundry_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/laundry_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/home_pro_analytics_screen.dart';
import 'package:uuid/uuid.dart';

class LaundryScreen extends StatefulWidget {
  const LaundryScreen({super.key});

  @override
  State<LaundryScreen> createState() => _LaundryScreenState();
}

class _LaundryScreenState extends State<LaundryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final laundry = context.watch<LaundryProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Laundry'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          indicatorColor: AppColors.white,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Stats'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'laundry_fab',
        backgroundColor: AppColors.primaryTeal,
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Load',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: laundry.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _ActiveTab(laundry: laundry),
                auth.isHomePro
                    ? _StatsTab(laundry: laundry)
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: PlanUpsellCard(
                          title: 'Laundry analytics are available on Home Pro',
                          subtitle:
                              'Upgrade to unlock load trends, bedroom breakdowns, and period-based laundry insights.',
                          onPressed: () => openHomeProUpgrade(
                            context,
                            source: 'laundry_analytics',
                          ),
                        ),
                      ),
                _HistoryTab(laundry: laundry),
              ],
            ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddLaundrySheet(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 1 — ACTIVE
// ════════════════════════════════════════════════════════════════════

class _ActiveTab extends StatelessWidget {
  final LaundryProvider laundry;
  const _ActiveTab({required this.laundry});

  @override
  Widget build(BuildContext context) {
    final activeByBedroom = laundry.itemsByBedroom;
    final stored = laundry.storedItems;

    if (laundry.items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.local_laundry_service_outlined,
        title: 'No laundry tracked yet',
        subtitle: 'Add laundry loads by bedroom to track progress',
        buttonLabel: 'New Load',
        onButton: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const _AddLaundrySheet(),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Today's quick-stat bar
        _QuickStatBar(
          active: laundry.activeItems.length,
          loads: laundry.totalActiveLoads,
          stored: stored.length,
        ),
        const SizedBox(height: 20),

        // Active items grouped by bedroom
        if (activeByBedroom.isNotEmpty) ...[
          const _SectionLabel(
            label: 'In Progress',
            helper:
                'Laundry currently moving through wash, dry, fold, and store.',
          ),
          const SizedBox(height: 10),
          ...activeByBedroom.entries.map(
            (entry) => _BedroomGroup(bedroom: entry.key, items: entry.value),
          ),
          const SizedBox(height: 8),
        ],

        // Stored items
        if (stored.isNotEmpty) ...[
          const _SectionLabel(
            label: 'Stored ✓',
            helper: 'Completed loads safely packed away.',
          ),
          const SizedBox(height: 8),
          ...stored
              .take(10)
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StoredCard(item: item),
                ),
              ),
        ],

        if (activeByBedroom.isEmpty && stored.isEmpty)
          const _SectionLabel(
            label: 'All caught up!',
            helper: 'No active or stored laundry items right now.',
          ),

        const SizedBox(height: 80),
      ],
    );
  }
}

class _BedroomGroup extends StatelessWidget {
  final String bedroom;
  final List<LaundryItem> items;
  const _BedroomGroup({required this.bedroom, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Row(
            children: [
              Icon(
                bedroom == 'Whole House'
                    ? Icons.home_outlined
                    : bedroom.contains('Master')
                    ? Icons.king_bed_outlined
                    : bedroom.contains('Staff')
                    ? Icons.single_bed_outlined
                    : Icons.bed_outlined,
                size: 16,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(width: 6),
              Text(
                bedroom,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTeal,
                ),
              ),
            ],
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LaundryCard(item: item),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 2 — STATS
// ════════════════════════════════════════════════════════════════════

class _StatsTab extends StatefulWidget {
  final LaundryProvider laundry;
  const _StatsTab({required this.laundry});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  // 0 = week, 1 = month, 2 = all time
  int _period = 0;

  @override
  Widget build(BuildContext context) {
    final l = widget.laundry;

    final periodLoads = _period == 0
        ? l.weekLoads
        : _period == 1
        ? l.monthLoads
        : l.allTimeLoads;

    final bedroomBreakdown = _period == 0
        ? l.weekLoadsByBedroom
        : _period == 1
        ? l.monthLoadsByBedroom
        : l.loadsByBedroom;

    final maxLoads = bedroomBreakdown.isEmpty
        ? 1
        : bedroomBreakdown.first.value.clamp(1, 9999);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PremiumAnalyticsEntryCard(
          title: 'Home Pro Intelligence',
          subtitle:
              'Laundry becomes more valuable when it is treated as a household reset signal, not just a count of loads.',
          icon: Icons.waves_rounded,
          highlights: const [
            'Reset rhythm',
            'Pressure map',
            'Weekly playbook',
          ],
          isUnlocked: true,
          unlockedLabel: 'Open Home Pro Intelligence',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const HomeProAnalyticsScreen(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Period selector
        _PeriodToggle(
          selected: _period,
          labels: const ['This Week', 'This Month', 'All Time'],
          onSelect: (i) => setState(() => _period = i),
        ),
        const SizedBox(height: 20),

        // Top summary cards
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.local_laundry_service_outlined,
                label: _period == 0
                    ? 'Loads\nThis Week'
                    : _period == 1
                    ? 'Loads\nThis Month'
                    : 'Loads\nAll Time',
                value: '$periodLoads',
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.today_outlined,
                label: 'Loads\nToday',
                value: '${l.todayLoads}',
                color: AppColors.accentOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.check_circle_outline,
                label: 'Stored\nAll Time',
                value: '${l.storedItems.length}',
                color: AppColors.statusEnoughText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 7-day bar chart
        const _SectionLabel(
          label: 'Last 7 Days',
          helper: 'Daily load trend for the past week.',
        ),
        const SizedBox(height: 12),
        _BarChart(data: l.last7DaysTrend),
        const SizedBox(height: 24),

        // Bedroom breakdown
        const _SectionLabel(
          label: 'Loads by Bedroom',
          helper: 'Which rooms generated the most laundry this period.',
        ),
        const SizedBox(height: 4),
        Text(
          _period == 0
              ? 'This week'
              : _period == 1
              ? 'This month'
              : 'All time',
          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
        const SizedBox(height: 12),
        if (bedroomBreakdown.isEmpty)
          const _EmptyHint(text: 'No loads recorded for this period')
        else
          ...bedroomBreakdown.map(
            (entry) => _BedroomBarRow(
              bedroom: entry.key,
              loads: entry.value,
              maxLoads: maxLoads,
              periodLabel: _period == 0
                  ? 'this week'
                  : _period == 1
                  ? 'this month'
                  : 'all time',
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onSelect;
  const _PeriodToggle({
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? AppColors.primaryTeal
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<MapEntry<String, int>> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((e) => e.value).fold(0, (a, b) => a > b ? a : b);
    final peak = maxVal < 1 ? 1 : maxVal;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((entry) {
                final frac = entry.value / peak;
                final isToday = entry.key == _todayLabel();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (entry.value > 0)
                          Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? AppColors.primaryTeal
                                  : AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          height: (frac * 60).clamp(4, 60),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.primaryTeal
                                : AppColors.secondaryTeal.withAlpha(160),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: data
                .map(
                  (e) => Expanded(
                    child: Text(
                      e.key,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: e.key == _todayLabel()
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: e.key == _todayLabel()
                            ? AppColors.primaryTeal
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[DateTime.now().weekday - 1];
  }
}

class _BedroomBarRow extends StatelessWidget {
  final String bedroom;
  final int loads;
  final int maxLoads;
  final String periodLabel;
  const _BedroomBarRow({
    required this.bedroom,
    required this.loads,
    required this.maxLoads,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final frac = loads / maxLoads;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                bedroom.contains('Master')
                    ? Icons.king_bed_outlined
                    : bedroom.contains('Staff')
                    ? Icons.single_bed_outlined
                    : Icons.bed_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bedroom,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$loads load${loads != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTeal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryTeal.withAlpha(200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.textHint),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// TAB 3 — HISTORY
// ════════════════════════════════════════════════════════════════════

class _HistoryTab extends StatelessWidget {
  final LaundryProvider laundry;
  const _HistoryTab({required this.laundry});

  @override
  Widget build(BuildContext context) {
    final history = laundry.historyByDate;

    if (history.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_outlined,
        title: 'No laundry history yet',
        subtitle:
            'Completed and stored loads will appear here for easy review.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...history.entries.map((entry) {
          final date = entry.key;
          final dayItems = entry.value;
          final totalLoads = dayItems.fold(0, (s, i) => s + i.numberOfLoads);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              _DateHeader(date: date, totalLoads: totalLoads),
              const SizedBox(height: 8),
              // Items for that day
              ...dayItems.map((item) => _HistoryCard(item: item)),
              const SizedBox(height: 16),
            ],
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final int totalLoads;
  const _DateHeader({required this.date, required this.totalLoads});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    String label;
    if (date == today) {
      label = 'Today';
    } else if (date == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, d MMM yyyy').format(date);
    }

    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryTeal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$totalLoads load${totalLoads != 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTeal,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final LaundryItem item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final laundry = context.read<LaundryProvider>();
    final auth = context.read<AuthProvider>();

    final timeStarted = DateFormat('h:mm a').format(item.createdAt);
    final timeStored = item.storedAt != null
        ? DateFormat('h:mm a').format(item.storedAt!)
        : null;

    // Duration from start to stored (if done), otherwise from start to now
    final endTime = item.storedAt ?? DateTime.now();
    final duration = endTime.difference(item.createdAt);
    final durationLabel = _formatDuration(duration);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isStored ? AppColors.statusEnough : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.bedroom.contains('Master')
                      ? Icons.king_bed_outlined
                      : item.bedroom.contains('Staff')
                      ? Icons.single_bed_outlined
                      : Icons.bed_outlined,
                  size: 16,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.bedroom,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                _stageChip(item.stage),
              ],
            ),
            const SizedBox(height: 8),
            // Time row
            Row(
              children: [
                // Loads badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${item.numberOfLoads} load${item.numberOfLoads != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.schedule, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  timeStored != null
                      ? '$timeStarted – $timeStored ($durationLabel)'
                      : 'Started $timeStarted · $durationLabel ago',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            // Stage timeline dots
            const SizedBox(height: 10),
            _StageDots(current: item.stage),
            // If still active, show advance button
            if (!item.isStored && item.nextStage != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      laundry.advanceStage(item.id, auth.household!.id),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: Text(
                    'Mark as ${_stageLabel(item.nextStage!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryTeal,
                    side: const BorderSide(color: AppColors.primaryTeal),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
            // Remove button for stored
            if (item.isStored) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      laundry.removeItem(item.id, auth.household!.id),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  Widget _stageChip(LaundryStage stage) {
    Color bg;
    Color fg;
    switch (stage) {
      case LaundryStage.washing:
        bg = AppColors.accentOrange.withAlpha(30);
        fg = AppColors.accentOrange;
        break;
      case LaundryStage.drying:
        bg = AppColors.accentYellow.withAlpha(45);
        fg = AppColors.statusLowText;
        break;
      case LaundryStage.folded:
        bg = AppColors.primaryTeal.withAlpha(25);
        fg = AppColors.primaryTeal;
        break;
      case LaundryStage.stored:
        bg = AppColors.statusEnough;
        fg = AppColors.statusEnoughText;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _stageLabel(stage),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _stageLabel(LaundryStage s) {
    switch (s) {
      case LaundryStage.washing:
        return 'Washing';
      case LaundryStage.drying:
        return 'Drying';
      case LaundryStage.folded:
        return 'Folded';
      case LaundryStage.stored:
        return 'Stored';
    }
  }
}

class _StageDots extends StatelessWidget {
  final LaundryStage current;
  const _StageDots({required this.current});

  @override
  Widget build(BuildContext context) {
    final idx = LaundryStage.values.indexOf(current);
    return Row(
      children: List.generate(LaundryStage.values.length, (i) {
        final done = i <= idx;
        final stage = LaundryStage.values[i];
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.primaryTeal : AppColors.divider,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _shortLabel(stage),
                      style: TextStyle(
                        fontSize: 8,
                        color: done
                            ? AppColors.primaryTeal
                            : AppColors.textHint,
                        fontWeight: i == idx
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < LaundryStage.values.length - 1)
                Container(
                  width: 14,
                  height: 1.5,
                  color: i < idx ? AppColors.primaryTeal : AppColors.divider,
                ),
            ],
          ),
        );
      }),
    );
  }

  String _shortLabel(LaundryStage s) {
    switch (s) {
      case LaundryStage.washing:
        return 'Wash';
      case LaundryStage.drying:
        return 'Dry';
      case LaundryStage.folded:
        return 'Fold';
      case LaundryStage.stored:
        return 'Store';
    }
  }
}

// ════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════

class _QuickStatBar extends StatelessWidget {
  final int active;
  final int loads;
  final int stored;
  const _QuickStatBar({
    required this.active,
    required this.loads,
    required this.stored,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(
                Icons.local_laundry_service_outlined,
                color: Colors.white,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Laundry at a glance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Track active loads, see what\'s stored, and keep the day moving.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCol(
                  label: 'Active',
                  value: '$active',
                  color: Colors.white,
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: _StatCol(
                  label: 'Loads',
                  value: '$loads',
                  color: Colors.white,
                ),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: _StatCol(
                  label: 'Stored',
                  value: '$stored',
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCol({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color == Colors.white
                ? Colors.white70
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String? helper;
  const _SectionLabel({required this.label, this.helper});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 3),
          Text(
            helper!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Active card with stepper ────────────────────────────────────
class _LaundryCard extends StatelessWidget {
  final LaundryItem item;
  const _LaundryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final laundry = context.read<LaundryProvider>();
    final auth = context.read<AuthProvider>();
    final stageIndex = LaundryStage.values.indexOf(item.stage);
    final timeLabel = DateFormat('h:mm a').format(item.createdAt);
    final age = item.age;
    final ageLabel = age.inHours >= 1
        ? '${age.inHours}h ${age.inMinutes % 60}m'
        : '${age.inMinutes}m';

    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.numberOfLoads} load${item.numberOfLoads > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
              const Spacer(),
              _stageChip(item.stage),
            ],
          ),
          const SizedBox(height: 6),
          // Date / time started
          Row(
            children: [
              const Icon(Icons.schedule, size: 12, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                'Started $timeLabel · $ageLabel ago',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stage stepper
          Row(
            children: List.generate(LaundryStage.values.length, (i) {
              final stage = LaundryStage.values[i];
              final isDone = i < stageIndex;
              final isCurrent = i == stageIndex;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => laundry.updateStage(
                          item.id,
                          stage,
                          auth.household!.id,
                        ),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? AppColors.primaryTeal
                                    : isCurrent
                                    ? AppColors.secondaryTeal
                                    : AppColors.surfaceLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDone || isCurrent
                                      ? AppColors.primaryTeal
                                      : AppColors.divider,
                                ),
                              ),
                              child: Icon(
                                isDone ? Icons.check : _stageIcon(stage),
                                size: 14,
                                color: isDone || isCurrent
                                    ? AppColors.white
                                    : AppColors.textHint,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _stageLabel(stage),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                color: isCurrent
                                    ? AppColors.primaryTeal
                                    : AppColors.textHint,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < LaundryStage.values.length - 1)
                      Container(
                        width: 16,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        color: i < stageIndex
                            ? AppColors.primaryTeal
                            : AppColors.divider,
                      ),
                  ],
                ),
              );
            }),
          ),
          // Quick advance
          if (item.nextStage != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    laundry.advanceStage(item.id, auth.household!.id),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text('Mark as ${_stageLabel(item.nextStage!)}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  side: const BorderSide(color: AppColors.primaryTeal),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageChip(LaundryStage stage) {
    Color bg;
    Color fg;
    switch (stage) {
      case LaundryStage.washing:
        bg = AppColors.accentOrange.withAlpha(30);
        fg = AppColors.accentOrange;
        break;
      case LaundryStage.drying:
        bg = AppColors.accentYellow.withAlpha(45);
        fg = AppColors.statusLowText;
        break;
      case LaundryStage.folded:
        bg = AppColors.primaryTeal.withAlpha(25);
        fg = AppColors.primaryTeal;
        break;
      case LaundryStage.stored:
        bg = AppColors.statusEnough;
        fg = AppColors.statusEnoughText;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _stageLabel(stage),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  String _stageLabel(LaundryStage s) {
    switch (s) {
      case LaundryStage.washing:
        return 'Washing';
      case LaundryStage.drying:
        return 'Drying';
      case LaundryStage.folded:
        return 'Folded';
      case LaundryStage.stored:
        return 'Stored';
    }
  }

  IconData _stageIcon(LaundryStage s) {
    switch (s) {
      case LaundryStage.washing:
        return Icons.local_laundry_service_outlined;
      case LaundryStage.drying:
        return Icons.air;
      case LaundryStage.folded:
        return Icons.layers_outlined;
      case LaundryStage.stored:
        return Icons.check_circle_outline;
    }
  }
}

// ─── Stored card ──────────────────────────────────────────────────
class _StoredCard extends StatelessWidget {
  final LaundryItem item;
  const _StoredCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final laundry = context.read<LaundryProvider>();
    final auth = context.read<AuthProvider>();
    final dateLabel = DateFormat('d MMM, h:mm a').format(item.createdAt);

    return HomeFlowCard(
      borderColor: AppColors.statusEnough,
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.statusEnoughText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.bedroom,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.numberOfLoads} load${item.numberOfLoads > 1 ? 's' : ''} · $dateLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
            tooltip: 'Remove',
            onPressed: () => laundry.removeItem(item.id, auth.household!.id),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ADD LAUNDRY SHEET
// ════════════════════════════════════════════════════════════════════

class _AddLaundrySheet extends StatefulWidget {
  const _AddLaundrySheet();

  @override
  State<_AddLaundrySheet> createState() => _AddLaundrySheetState();
}

class _AddLaundrySheetState extends State<_AddLaundrySheet> {
  String _selectedBedroom = bedroomOptions.first;
  int _numberOfLoads = 1;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final laundry = context.read<LaundryProvider>();

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
                    'Add Laundry Load',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track laundry by bedroom and number of loads.',
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
          const SizedBox(height: 16),

          Text('Select Bedroom', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bedroomOptions.map((bedroom) {
              final selected = _selectedBedroom == bedroom;
              return GestureDetector(
                onTap: () => setState(() => _selectedBedroom = bedroom),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primaryTeal.withAlpha(25)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primaryTeal
                          : AppColors.divider,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        bedroom == 'Whole House'
                            ? Icons.home_outlined
                            : bedroom.contains('Master')
                            ? Icons.king_bed_outlined
                            : bedroom.contains('Staff')
                            ? Icons.single_bed_outlined
                            : Icons.bed_outlined,
                        size: 16,
                        color: selected
                            ? AppColors.primaryTeal
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        bedroom,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.primaryTeal
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          Text(
            'Number of Loads',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LoadButton(
                icon: Icons.remove,
                onTap: _numberOfLoads > 1
                    ? () => setState(() => _numberOfLoads--)
                    : null,
              ),
              Container(
                width: 56,
                alignment: Alignment.center,
                child: Text(
                  '$_numberOfLoads',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _LoadButton(
                icon: Icons.add,
                onTap: _numberOfLoads < 20
                    ? () => setState(() => _numberOfLoads++)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                _numberOfLoads == 1 ? 'load' : 'loads',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
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
                const uuid = Uuid();
                final now = DateTime.now();
                final item = LaundryItem(
                  id: uuid.v4(),
                  householdId: auth.household!.id,
                  bedroom: _selectedBedroom,
                  numberOfLoads: _numberOfLoads,
                  stage: LaundryStage.washing,
                  createdByUserId: auth.currentUser!.id,
                  createdAt: now,
                  updatedAt: now,
                );
                laundry.addItem(item, auth.household!.id);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.local_laundry_service_outlined),
              label: const Text('Start Washing'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _LoadButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primaryTeal.withAlpha(25)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? AppColors.primaryTeal : AppColors.divider,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.primaryTeal : AppColors.textHint,
        ),
      ),
    );
  }
}
