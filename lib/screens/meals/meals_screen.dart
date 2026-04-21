import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/meal_log.dart';
import '../../models/meal_timetable_entry.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_timetable_provider.dart';
import '../../providers/meal_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';
import '../dashboard/home_pro_analytics_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MEALS SCREEN — date navigator + log sheet + nutrition stats
// ─────────────────────────────────────────────────────────────────────────────

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  // Keep today normalised for comparisons
  final DateTime _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToDate(DateTime d) => setState(() => _selectedDate = d);

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryTeal,
            onPrimary: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) _goToDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Meals & Snacks'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          indicatorColor: AppColors.white,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Daily Log'),
            Tab(text: 'Timetable'),
            Tab(text: 'Nutrition Stats'),
          ],
        ),
      ),
      floatingActionButton: TabBuilder(
        controller: _tabController,
        builder: (index) => index == 0
            ? FloatingActionButton.extended(
                heroTag: 'meals_fab',
                backgroundColor: AppColors.primaryTeal,
                onPressed: () => _showLogSheet(context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Log Meal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── TAB 1: DAILY LOG ────────────────────────────────────────
          _DailyLogTab(
            selectedDate: _selectedDate,
            today: _today,
            onPickDate: _pickDate,
            onChangeDate: _goToDate,
          ),
          // ── TAB 2: TIMETABLE ─────────────────────────────────────────
          const _TimetableTab(),
          // ── TAB 3: NUTRITION STATS ──────────────────────────────────
          auth.isHomePro
              ? const _NutritionStatsTab()
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: PlanUpsellCard(
                    title: 'Meal analytics are available on Home Pro',
                    subtitle:
                        'Upgrade to unlock nutrition trends, top foods, and weekly and monthly meal insights for your household.',
                    onPressed: () =>
                        openHomeProUpgrade(context, source: 'meal_analytics'),
                  ),
                ),
        ],
      ),
    );
  }

  void _showLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogMealSheet(
        initialDate: _selectedDate,
        onLogged: (date) {
          setState(() => _selectedDate = date);
        },
      ),
    );
  }
}

/// Helper widget that rebuilds when the tab changes, used for the FAB.
class TabBuilder extends StatefulWidget {
  final TabController controller;
  final Widget Function(int index) builder;
  const TabBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  State<TabBuilder> createState() => _TabBuilderState();
}

class _TabBuilderState extends State<TabBuilder> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.controller.index);
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — DAILY LOG
// ─────────────────────────────────────────────────────────────────────────────

class _DailyLogTab extends StatelessWidget {
  final DateTime selectedDate;
  final DateTime today;
  final VoidCallback onPickDate;
  final ValueChanged<DateTime> onChangeDate;

  const _DailyLogTab({
    required this.selectedDate,
    required this.today,
    required this.onPickDate,
    required this.onChangeDate,
  });

  @override
  Widget build(BuildContext context) {
    final meals = context.watch<MealProvider>();
    final dayMeals = meals.getMealsForDate(selectedDate);

    final selDay = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final isToday = selDay == today;
    final isYesterday = selDay == today.subtract(const Duration(days: 1));

    return Column(
      children: [
        // ── DATE NAVIGATOR ────────────────────────────────────────────
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                onPressed: () => onChangeDate(
                  selectedDate.subtract(const Duration(days: 1)),
                ),
                color: AppColors.textSecondary,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onPickDate,
                  child: Column(
                    children: [
                      Text(
                        isToday
                            ? 'Today'
                            : isYesterday
                            ? 'Yesterday'
                            : _weekday(selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formatFull(selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.primaryTeal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                onPressed: selDay.isBefore(today)
                    ? () => onChangeDate(
                        selectedDate.add(const Duration(days: 1)),
                      )
                    : null,
                color: selDay.isBefore(today)
                    ? AppColors.textSecondary
                    : AppColors.divider,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── MEAL PERIOD PROGRESS STRIP ────────────────────────────────
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: AppConstants.mealPeriods.map((p) {
              final done = dayMeals.any((m) => m.mealPeriod == p);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: done
                              ? AppColors.primaryTeal
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _shortPeriod(p),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: done
                              ? AppColors.primaryTeal
                              : AppColors.textHint,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),

        // ── MEAL CARDS ────────────────────────────────────────────────
        Expanded(
          child: meals.isLoading
              ? const Center(child: CircularProgressIndicator())
              : dayMeals.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.restaurant_outlined,
                  title: 'No meals logged',
                  subtitle: 'Tap "Log Meal" to record what was eaten',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: dayMeals.length,
                  itemBuilder: (_, i) {
                    final log = dayMeals[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MealCard(log: log),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _shortPeriod(String p) {
    switch (p) {
      case 'School Snack':
        return 'Sch.Snack';
      case 'After-school Snack':
        return 'Aft.Snack';
      default:
        return p;
    }
  }

  String _weekday(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[d.weekday - 1];
  }

  String _formatFull(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEAL CARD (with swipe-to-delete)
// ─────────────────────────────────────────────────────────────────────────────

class _MealCard extends StatelessWidget {
  final MealLog log;
  const _MealCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final meals = context.read<MealProvider>();

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: AppColors.accentOrange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Delete meal log?'),
            content: Text(
              'Remove "${log.mealPeriod}" on ${log.date.day}/${log.date.month}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => meals.deleteMealLog(log.id, auth.household!.id),
      child: HomeFlowCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Period badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _periodColor(log.mealPeriod).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _periodIcon(log.mealPeriod),
                        size: 12,
                        color: _periodColor(log.mealPeriod),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log.mealPeriod,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _periodColor(log.mealPeriod),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _timeLabel(log.date),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Food chips
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: log.selectedFoods
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (log.nutritionTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: log.nutritionTags
                    .map(
                      (t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _tagColor(t).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _tagColor(t),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (log.packedForSchool) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    size: 13,
                    color: AppColors.primaryTeal,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Packed for ${log.childName ?? 'school'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _periodColor(String p) {
    switch (p) {
      case 'Breakfast':
        return AppColors.accentYellow; // amber
      case 'School Snack':
        return AppColors.primaryTeal;
      case 'Lunch':
        return AppColors.accentOrange;
      case 'After-school Snack':
        return AppColors.accentOrange; // purple
      case 'Dinner':
        return AppColors.primaryTeal; // deep blue
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _periodIcon(String p) {
    switch (p) {
      case 'Breakfast':
        return Icons.wb_sunny_outlined;
      case 'School Snack':
        return Icons.school_outlined;
      case 'Lunch':
        return Icons.restaurant_outlined;
      case 'After-school Snack':
        return Icons.apple_outlined;
      case 'Dinner':
        return Icons.nights_stay_outlined;
      default:
        return Icons.fastfood_outlined;
    }
  }

  Color _tagColor(String t) {
    switch (t) {
      case 'Carbs':
        return AppColors.accentYellow;
      case 'Protein':
        return AppColors.accentOrange;
      case 'Vegetables':
        return AppColors.nutritionGreen;
      case 'Fruit':
        return AppColors.accentOrange;
      case 'Dairy':
        return AppColors.primaryTeal;
      case 'Hydration':
        return AppColors.secondaryTeal;
      default:
        return AppColors.textSecondary;
    }
  }

  String _timeLabel(DateTime d) {
    final hour = d.hour;
    final min = d.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$min $suffix';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — NUTRITION STATS
// ─────────────────────────────────────────────────────────────────────────────

class _NutritionStatsTab extends StatefulWidget {
  const _NutritionStatsTab();

  @override
  State<_NutritionStatsTab> createState() => _NutritionStatsTabState();
}

class _NutritionStatsTabState extends State<_NutritionStatsTab> {
  // 'week' | 'month'
  String _period = 'week';

  @override
  Widget build(BuildContext context) {
    final meals = context.watch<MealProvider>();

    final freq = _period == 'week'
        ? meals.weeklyNutritionFrequency
        : meals.monthlyNutritionFrequency;
    final topFoods = _period == 'week'
        ? meals.weeklyTopFoods
        : meals.monthlyTopFoods;
    final totalMeals = _period == 'week'
        ? meals.logsInLastDays(7).length
        : meals.logsInMonth(DateTime.now()).length;
    final totalProtein = freq['Protein'] ?? 0;
    final totalVeg = freq['Vegetables'] ?? 0;

    final tagOrder = [
      'Carbs',
      'Protein',
      'Vegetables',
      'Fruit',
      'Dairy',
      'Hydration',
    ];
    final maxCount = freq.values.isEmpty
        ? 1
        : freq.values.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        PremiumAnalyticsEntryCard(
          title: 'Home Pro Intelligence',
          subtitle:
              'Meals do more than count servings here. See how food rhythm shapes your whole household pulse and weekly calm.',
          icon: Icons.insights_rounded,
          highlights: const [
            'Meal rhythm score',
            'Household archetype',
            'Cross-home guidance',
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
        // ── PERIOD TOGGLE ─────────────────────────────────────────────
        Row(
          children: ['week', 'month'].map((p) {
            final sel = _period == p;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => setState(() => _period = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primaryTeal : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.primaryTeal : AppColors.divider,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    p == 'week' ? 'This Week' : 'This Month',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppColors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ── SUMMARY CARDS ─────────────────────────────────────────────
        Row(
          children: [
            _StatSummaryCard(
              label: 'Meals Logged',
              value: '$totalMeals',
              icon: Icons.restaurant_outlined,
              color: AppColors.primaryTeal,
            ),
            const SizedBox(width: 10),
            _StatSummaryCard(
              label: 'Protein Servings',
              value: '$totalProtein',
              icon: Icons.fitness_center_outlined,
              color: AppColors.accentOrange,
            ),
            const SizedBox(width: 10),
            _StatSummaryCard(
              label: 'Veg Servings',
              value: '$totalVeg',
              icon: Icons.eco_outlined,
              color: AppColors.nutritionGreen,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── BAR CHART — NUTRITION FREQUENCY ──────────────────────────
        SectionHeader(
          title: _period == 'week'
              ? 'Nutrition This Week'
              : 'Nutrition This Month',
        ),
        const SizedBox(height: 12),
        HomeFlowCard(
          child: Column(
            children: [
              if (freq.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No meals logged yet',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ...tagOrder.where((t) => freq.containsKey(t)).map((tag) {
                  final count = freq[tag] ?? 0;
                  final ratio = maxCount > 0 ? count / maxCount : 0.0;
                  final color = _tagColorStatic(tag);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$count ${count == 1 ? 'serving' : 'servings'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 8,
                            backgroundColor: AppColors.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── TOP FOODS ─────────────────────────────────────────────────
        SectionHeader(
          title: _period == 'week'
              ? 'Most Eaten This Week'
              : 'Most Eaten This Month',
        ),
        const SizedBox(height: 12),
        HomeFlowCard(
          child: topFoods.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No data yet',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              : Column(
                  children: topFoods.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    final food = e.value.key;
                    final count = e.value.value;
                    final maxF = topFoods.first.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '$rank',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: rank <= 3
                                    ? AppColors.primaryTeal
                                    : AppColors.textHint,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: maxF > 0 ? count / maxF : 0,
                                    minHeight: 5,
                                    backgroundColor: AppColors.divider,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.primaryTeal,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '×$count',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 20),

        // ── 7-DAY DAILY BREAKDOWN ─────────────────────────────────────
        if (_period == 'week') ...[
          const SectionHeader(title: 'Daily Breakdown (Last 7 Days)'),
          const SizedBox(height: 12),
          _DailyBreakdownChart(data: meals.dailyNutritionBreakdown(7)),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  static Color _tagColorStatic(String t) {
    switch (t) {
      case 'Carbs':
        return AppColors.accentYellow;
      case 'Protein':
        return AppColors.accentOrange;
      case 'Vegetables':
        return AppColors.nutritionGreen;
      case 'Fruit':
        return AppColors.accentOrange;
      case 'Dairy':
        return AppColors.primaryTeal;
      case 'Hydration':
        return AppColors.secondaryTeal;
      default:
        return AppColors.textSecondary;
    }
  }
}

/// Mini stat card
class _StatSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 7-day stacked bar chart showing nutrition tag frequency each day
class _DailyBreakdownChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DailyBreakdownChart({required this.data});

  static const _tags = ['Carbs', 'Protein', 'Vegetables', 'Fruit', 'Dairy'];
  static const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _barHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    // Find the max total count across any day (for scaling)
    final maxTotal = data
        .map((d) {
          final m = d['counts'] as Map<String, int>;
          return _tags.fold(0, (sum, t) => sum + (m[t] ?? 0));
        })
        .fold<int>(0, (prev, v) => v > prev ? v : prev);
    final chartMax = maxTotal < 4 ? 4 : maxTotal;

    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: _tags
                .map(
                  (t) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _tagColor(t),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          // Chart row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((dayData) {
              final date = dayData['date'] as DateTime;
              final counts = dayData['counts'] as Map<String, int>;
              final now = DateTime.now();
              final isToday =
                  date.year == now.year &&
                  date.month == now.month &&
                  date.day == now.day;

              // Build segments from bottom: largest contrast first
              final segments = _tags.where((t) => (counts[t] ?? 0) > 0).map((
                t,
              ) {
                final h = ((counts[t]! / chartMax) * _barHeight).clamp(
                  2.0,
                  _barHeight,
                );
                return _BarSegment(color: _tagColor(t), height: h);
              }).toList();

              final totalH = segments.fold(0.0, (s, e) => s + e.height);

              return Expanded(
                child: Column(
                  children: [
                    // Fixed height zone so all bars share the same baseline
                    SizedBox(
                      height: _barHeight,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: totalH == 0
                            ? Container(
                                height: 3,
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.divider,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: totalH,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        for (final seg in segments.reversed)
                                          Container(
                                            height: seg.height,
                                            color: seg.color,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _dayAbbr[date.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                        color: isToday
                            ? AppColors.primaryTeal
                            : AppColors.textHint,
                      ),
                    ),
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          // Y-axis hint
          const SizedBox(height: 4),
          Text(
            'Each segment = 1 serving',
            style: const TextStyle(fontSize: 9, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  static Color _tagColor(String t) {
    switch (t) {
      case 'Carbs':
        return AppColors.accentYellow;
      case 'Protein':
        return AppColors.accentOrange;
      case 'Vegetables':
        return AppColors.nutritionGreen;
      case 'Fruit':
        return AppColors.accentOrange;
      case 'Dairy':
        return AppColors.primaryTeal;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _BarSegment {
  final Color color;
  final double height;
  const _BarSegment({required this.color, required this.height});
}

// ─────────────────────────────────────────────────────────────────────────────
// LOG MEAL SHEET — pick-only, no typing
// ─────────────────────────────────────────────────────────────────────────────

class _LogMealSheet extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onLogged;

  const _LogMealSheet({required this.initialDate, required this.onLogged});

  @override
  State<_LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends State<_LogMealSheet> {
  late DateTime _logDate;
  String _period = AppConstants.mealPeriods.first;
  final Set<String> _selectedFoods = {};
  final Set<String> _customFoods = {};
  bool _packedForSchool = false;
  String? _expandedCategory;

  @override
  void initState() {
    super.initState();
    _logDate = widget.initialDate;
  }

  void _showAddCustomItemDialog() {
    showDialog<String>(
      context: context,
      builder: (_) => _CustomFoodDialog(),
    ).then((foodName) {
      if (foodName != null && foodName.trim().isNotEmpty) {
        setState(() {
          _customFoods.add(foodName.trim());
          _selectedFoods.add(foodName.trim());
        });
      }
    });
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _logDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryTeal,
            onPrimary: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _logDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final meals = context.read<MealProvider>();
    final children = context.read<ChildProvider>().children;

    final today = DateTime.now();
    final isToday =
        _logDate.year == today.year &&
        _logDate.month == today.month &&
        _logDate.day == today.day;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Column(
          children: [
            // ── SHEET HANDLE ────────────────────────────────────────
            const SizedBox(height: 10),
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
            const SizedBox(height: 12),

            // ── HEADER ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Log a Meal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── DATE SELECTOR ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppColors.primaryTeal,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                          Text(
                            isToday
                                ? 'Today — ${_formatDate(_logDate)}'
                                : _formatDate(_logDate),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── MEAL PERIOD PILLS ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConstants.mealPeriods.map((p) {
                    final sel = _period == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _period = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primaryTeal
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? AppColors.primaryTeal
                                  : AppColors.divider,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sel) ...[
                                const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: AppColors.white,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                p,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: sel
                                      ? AppColors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── SELECTED FOODS TRAY ───────────────────────────────────
            if (_selectedFoods.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                color: AppColors.primaryTeal.withValues(alpha: 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedFoods.length} item${_selectedFoods.length == 1 ? '' : 's'} selected',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _selectedFoods
                          .map(
                            (f) => GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedFoods.remove(f)),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryTeal.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primaryTeal.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      f,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primaryTeal,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: AppColors.primaryTeal,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // ── FOOD CATEGORY LIST ────────────────────────────────────
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // Auto-expand the category that matches the selected period
                  ...AppConstants.commonFoods.entries.map((entry) {
                    final isExpanded = _expandedCategory == entry.key;
                    // Count how many items from this category are selected
                    final selectedCount = entry.value
                        .where((f) => _selectedFoods.contains(f))
                        .length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category header row
                        GestureDetector(
                          onTap: () => setState(
                            () => _expandedCategory = isExpanded
                                ? null
                                : entry.key,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                if (selectedCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryTeal,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$selectedCount',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: AppColors.textHint,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Food chips grid (expanded)
                        if (isExpanded) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((food) {
                              final sel = _selectedFoods.contains(food);
                              return GestureDetector(
                                onTap: () => setState(
                                  () => sel
                                      ? _selectedFoods.remove(food)
                                      : _selectedFoods.add(food),
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primaryTeal
                                        : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: sel
                                          ? AppColors.primaryTeal
                                          : AppColors.divider,
                                    ),
                                    boxShadow: sel
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primaryTeal
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (sel) ...[
                                        const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: AppColors.white,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        food,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: sel
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: sel
                                              ? AppColors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const Divider(height: 1),
                      ],
                    );
                  }),

                  // ── ADD CUSTOM ITEM ────────────────────────────────
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _showAddCustomItemDialog,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryTeal.withValues(alpha: 0.3),
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(
                                alpha: 0.1,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 16,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add item not listed',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryTeal,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Type any food — we\'ll detect its nutrition category',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.primaryTeal,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── PACK FOR SCHOOL TOGGLE ─────────────────────────
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            color: AppColors.primaryTeal,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Pack for school?',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Switch(
                            value: _packedForSchool,
                            onChanged: (v) =>
                                setState(() => _packedForSchool = v),
                            activeColor: AppColors.primaryTeal,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),

            // ── LOG BUTTON ────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    12,
              ),
              color: AppColors.white,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedFoods.isEmpty
                      ? null
                      : () {
                          const uuid = Uuid();
                          final now = DateTime.now();
                          // Use the selected date but with current time
                          final logDateTime = DateTime(
                            _logDate.year,
                            _logDate.month,
                            _logDate.day,
                            now.hour,
                            now.minute,
                          );
                          final tags = MealLog.deriveNutritionTags(
                            _selectedFoods.toList(),
                          );
                          final log = MealLog(
                            id: uuid.v4(),
                            householdId: auth.household!.id,
                            date: logDateTime,
                            mealPeriod: _period,
                            selectedFoods: _selectedFoods.toList(),
                            packedForSchool: _packedForSchool,
                            nutritionTags: tags,
                            createdByUserId: auth.currentUser!.id,
                          );
                          meals.addMealLog(log, auth.household!.id);
                          widget.onLogged(_logDate);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_period logged — ${_selectedFoods.length} items',
                                  ),
                                ],
                              ),
                              backgroundColor: AppColors.primaryTeal,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _selectedFoods.isEmpty
                          ? 'Select items to log'
                          : 'Log ${_selectedFoods.length} item${_selectedFoods.length == 1 ? '' : 's'} — $_period',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — MEALS TIMETABLE
// ═════════════════════════════════════════════════════════════════════════════

class _TimetableTab extends StatefulWidget {
  const _TimetableTab();

  @override
  State<_TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<_TimetableTab> {
  late DateTime _weekStart; // always a Monday
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = _todayNorm();
    _weekStart = _mondayOf(today);
    _selectedDay = today;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _todayNorm() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  String _weekKeyOf(DateTime monday) =>
      '${monday.year}-${monday.month.toString().padLeft(2, '0')}-'
      '${monday.day.toString().padLeft(2, '0')}';

  bool get _isCurrentWeek => _weekStart == _mondayOf(_todayNorm());

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  String _weekRangeLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (_weekStart.month == end.month && _weekStart.year == end.year) {
      return '${_weekStart.day}–${end.day} ${m[end.month - 1]} ${end.year}';
    }
    return '${_weekStart.day} ${m[_weekStart.month - 1]}'
        ' – ${end.day} ${m[end.month - 1]} ${end.year}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final timetable = context.watch<MealTimetableProvider>();
    final auth = context.read<AuthProvider>();
    final weekKey = _weekKeyOf(_weekStart);
    final today = _todayNorm();
    final days = _weekDays;

    final weekEntries = timetable.getEntriesForWeek(weekKey);
    const totalPossible = 5 * 7; // 5 periods × 7 days = 35
    final plannedCount = weekEntries.length;

    return Column(
      children: [
        // ── WEEK NAVIGATOR ─────────────────────────────────────────────
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                color: AppColors.textSecondary,
                onPressed: () => setState(() {
                  _weekStart = _weekStart.subtract(const Duration(days: 7));
                  final newDays = List.generate(
                    7,
                    (i) => _weekStart.add(Duration(days: i)),
                  );
                  if (!newDays.contains(_selectedDay)) {
                    _selectedDay = _weekStart;
                  }
                }),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _weekRangeLabel(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: plannedCount > 0
                                ? AppColors.primaryTeal.withAlpha(20)
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$plannedCount / $totalPossible meals planned',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: plannedCount > 0
                                  ? AppColors.primaryTeal
                                  : AppColors.textHint,
                            ),
                          ),
                        ),
                        if (!_isCurrentWeek) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() {
                              _weekStart = _mondayOf(_todayNorm());
                              _selectedDay = _todayNorm();
                            }),
                            child: const Text(
                              '↩ Today',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                color: AppColors.textSecondary,
                onPressed: () => setState(() {
                  _weekStart = _weekStart.add(const Duration(days: 7));
                  final newDays = List.generate(
                    7,
                    (i) => _weekStart.add(Duration(days: i)),
                  );
                  if (!newDays.contains(_selectedDay)) {
                    _selectedDay = _weekStart;
                  }
                }),
              ),
            ],
          ),
        ),

        // ── DAY SELECTOR CHIPS ─────────────────────────────────────────
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
          child: Row(
            children: days.map((day) {
              final isSel = day == _selectedDay;
              final isToday = day == today;
              final hasEntries = timetable.hasAnyForDay(weekKey, day.weekday);
              const abbrs = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Column(
                    children: [
                      Text(
                        abbrs[day.weekday - 1],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSel
                              ? AppColors.primaryTeal
                              : AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primaryTeal
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSel
                              ? Border.all(
                                  color: AppColors.primaryTeal,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? Colors.white
                                  : isToday
                                  ? AppColors.primaryTeal
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: hasEntries
                              ? AppColors.primaryTeal
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),

        // ── DAY CONTENT ────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [
              // Day header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDayLabel(_selectedDay, today),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_selectedDay == today)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Day completion bar
              _DayCompletionBar(
                planned: timetable
                    .getEntriesForDay(weekKey, _selectedDay.weekday)
                    .length,
                total: AppConstants.mealPeriods.length,
              ),
              const SizedBox(height: 16),

              // One card per meal period
              ...AppConstants.mealPeriods.map((period) {
                final entry = timetable.getEntry(
                  weekKey,
                  _selectedDay.weekday,
                  period,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MealPlanCard(
                    period: period,
                    entry: entry,
                    onTap: () => _showEntrySheet(
                      context,
                      weekKey: weekKey,
                      dayOfWeek: _selectedDay.weekday,
                      period: period,
                      existingEntry: entry,
                    ),
                    onDelete: entry != null
                        ? () => timetable.removeEntry(
                            entry.id,
                            auth.household!.id,
                          )
                        : null,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sheet ──────────────────────────────────────────────────────────────────

  void _showEntrySheet(
    BuildContext context, {
    required String weekKey,
    required int dayOfWeek,
    required String period,
    MealTimetableEntry? existingEntry,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimetableEntrySheet(
        dayDate: _selectedDay,
        weekKey: weekKey,
        dayOfWeek: dayOfWeek,
        mealPeriod: period,
        existingEntry: existingEntry,
      ),
    );
  }

  String _formatDayLabel(DateTime day, DateTime today) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final prefix = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : day == today.add(const Duration(days: 1))
        ? 'Tomorrow'
        : weekdays[day.weekday - 1];
    return '$prefix, ${day.day} ${months[day.month - 1]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAY COMPLETION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _DayCompletionBar extends StatelessWidget {
  final int planned;
  final int total;
  const _DayCompletionBar({required this.planned, required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final allDone = planned == total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allDone ? AppColors.statusEnough : AppColors.divider,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone
                      ? 'All meals planned for today'
                      : '$planned of $total meal periods planned',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: allDone
                        ? AppColors.statusEnoughText
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? planned / total : 0,
                    minHeight: 6,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allDone
                          ? AppColors.statusEnoughText
                          : AppColors.primaryTeal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: allDone
                  ? AppColors.statusEnough
                  : AppColors.primaryTeal.withAlpha(15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              allDone ? '✓ All set!' : '${total - planned} to plan',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: allDone
                    ? AppColors.statusEnoughText
                    : AppColors.primaryTeal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEAL PLAN CARD (filled or empty)
// ─────────────────────────────────────────────────────────────────────────────

class _MealPlanCard extends StatelessWidget {
  final String period;
  final MealTimetableEntry? entry;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _MealPlanCard({
    required this.period,
    required this.entry,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) =>
      entry != null ? _filled(context) : _empty(context);

  Widget _filled(BuildContext context) {
    final color = _periodColor(period);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Coloured left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: Icon(_periodIcon(period), size: 16, color: color),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry!.mealLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (entry!.notes != null && entry!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry!.notes!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: AppColors.textHint,
                  tooltip: 'Edit',
                  onPressed: onTap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  constraints: const BoxConstraints(),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: AppColors.textHint,
                    tooltip: 'Remove',
                    onPressed: onDelete,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final color = _periodColor(period);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _periodIcon(period),
                size: 17,
                color: color.withAlpha(180),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    period,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Nothing planned — tap to add',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.add_circle_outline,
              size: 20,
              color: AppColors.primaryTeal,
            ),
          ],
        ),
      ),
    );
  }

  static Color _periodColor(String p) {
    switch (p) {
      case 'Breakfast':
        return const Color(0xFFF59E0B);
      case 'School Snack':
        return AppColors.primaryTeal;
      case 'Lunch':
        return AppColors.accentOrange;
      case 'After-school Snack':
        return const Color(0xFF8B5CF6);
      case 'Dinner':
        return const Color(0xFF1D4ED8);
      default:
        return AppColors.textSecondary;
    }
  }

  static IconData _periodIcon(String p) {
    switch (p) {
      case 'Breakfast':
        return Icons.wb_sunny_outlined;
      case 'School Snack':
        return Icons.school_outlined;
      case 'Lunch':
        return Icons.restaurant_outlined;
      case 'After-school Snack':
        return Icons.apple_outlined;
      case 'Dinner':
        return Icons.nights_stay_outlined;
      default:
        return Icons.fastfood_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMETABLE ENTRY SHEET (add / edit)
// ─────────────────────────────────────────────────────────────────────────────

class _TimetableEntrySheet extends StatefulWidget {
  final DateTime dayDate;
  final String weekKey;
  final int dayOfWeek;
  final String mealPeriod;
  final MealTimetableEntry? existingEntry;

  const _TimetableEntrySheet({
    required this.dayDate,
    required this.weekKey,
    required this.dayOfWeek,
    required this.mealPeriod,
    this.existingEntry,
  });

  @override
  State<_TimetableEntrySheet> createState() => _TimetableEntrySheetState();
}

class _TimetableEntrySheetState extends State<_TimetableEntrySheet> {
  final _customCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<String> _selectedItems = [];
  String _filterInput = '';
  bool _saving = false;

  // Map each meal period to relevant food categories for quick-suggest
  static const Map<String, List<String>> _periodCategories = {
    'Breakfast': ['Breakfast', 'Dairy & Drinks'],
    'School Snack': ['Snacks', 'Fruits'],
    'Lunch': [
      'Ugali Meals',
      'Rice Meals',
      'Chapati Meals',
      'Other Staples',
      'Proteins & Sides',
      'Vegetables',
    ],
    'After-school Snack': ['Snacks', 'Fruits'],
    'Dinner': [
      'Ugali Meals',
      'Rice Meals',
      'Chapati Meals',
      'Other Staples',
      'Proteins & Sides',
      'Vegetables',
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _selectedItems.addAll(widget.existingEntry!.mealItems);
      _notesCtrl.text = widget.existingEntry!.notes ?? '';
    }
    _customCtrl.addListener(() => setState(() => _filterInput = _customCtrl.text));
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  List<String> get _suggestions {
    final cats = _periodCategories[widget.mealPeriod] ?? [];
    final pool = <String>[];
    for (final cat in cats) {
      pool.addAll(AppConstants.commonFoods[cat] ?? []);
    }
    if (_filterInput.isEmpty) {
      final seen = <String>{};
      return pool.where(seen.add).take(24).toList();
    }
    final q = _filterInput.toLowerCase();
    return pool
        .where((f) => f.toLowerCase().contains(q))
        .toSet()
        .take(18)
        .toList();
  }

  void _toggleItem(String item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  void _addCustomItem() {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    if (!_selectedItems.contains(text)) {
      setState(() => _selectedItems.add(text));
    }
    _customCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final timetable = context.read<MealTimetableProvider>();
    final auth = context.read<AuthProvider>();
    final isEdit = widget.existingEntry != null;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayLabel =
        '${weekdays[widget.dayDate.weekday - 1]}, '
        '${widget.dayDate.day} ${months[widget.dayDate.month - 1]}';

    final periodColor = _MealPlanCard._periodColor(widget.mealPeriod);
    final periodIcon = _MealPlanCard._periodIcon(widget.mealPeriod);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              // Handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 14),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: periodColor.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(periodIcon, color: periodColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? 'Edit ${widget.mealPeriod}'
                              : 'Plan ${widget.mealPeriod}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: AppColors.textHint,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 18),

              // ── SELECTED ITEMS ────────────────────────────────────
              const Text(
                "What's being prepared?",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedItems.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedItems.map((item) {
                    return Chip(
                      label: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: AppColors.primaryTeal.withAlpha(18),
                      side: const BorderSide(color: AppColors.primaryTeal),
                      deleteIconColor: AppColors.primaryTeal,
                      onDeleted: () => _toggleItem(item),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Text(
                    'Tap suggestions below or type a custom item to add',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // ── CUSTOM ITEM INPUT ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customCtrl,
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _addCustomItem(),
                      decoration: InputDecoration(
                        hintText: 'Add custom item…',
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: AppColors.primaryTeal,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _addCustomItem,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),

              // ── QUICK SUGGESTIONS ─────────────────────────────────
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Quick suggestions — tap to add / remove',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _suggestions.map((s) {
                    final isSelected = _selectedItems.contains(s);
                    return GestureDetector(
                      onTap: () => _toggleItem(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryTeal.withAlpha(20)
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryTeal
                                : AppColors.divider,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.check,
                                size: 12,
                                color: AppColors.primaryTeal,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              s,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.primaryTeal
                                    : AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // ── NOTES FIELD ───────────────────────────────────────
              const SizedBox(height: 18),
              const Text(
                'Notes (optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. no onions for the kids, make extra rice',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.primaryTeal,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── SAVE BUTTON ───────────────────────────────────────
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
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isEdit
                              ? Icons.check_circle_outline
                              : Icons.bookmark_add_outlined,
                        ),
                  label: Text(
                    isEdit ? 'Update Plan' : 'Save to Timetable',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                          if (_selectedItems.isEmpty) return;
                          setState(() => _saving = true);
                          await timetable.setEntry(
                            householdId: auth.household!.id,
                            weekKey: widget.weekKey,
                            dayOfWeek: widget.dayOfWeek,
                            mealPeriod: widget.mealPeriod,
                            mealItems: List<String>.from(_selectedItems),
                            notes: _notesCtrl.text.trim().isEmpty
                                ? null
                                : _notesCtrl.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
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
// CUSTOM FOOD DIALOG — type any food name, see live nutrition detection
// ─────────────────────────────────────────────────────────────────────────────

class _CustomFoodDialog extends StatefulWidget {
  const _CustomFoodDialog();

  @override
  State<_CustomFoodDialog> createState() => _CustomFoodDialogState();
}

class _CustomFoodDialogState extends State<_CustomFoodDialog> {
  final _ctrl = TextEditingController();
  List<String> _detectedTags = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final tags = value.trim().isEmpty
        ? <String>[]
        : MealLog.deriveNutritionTags([value.trim()]);
    setState(() => _detectedTags = tags);
  }

  Color _tagColor(String t) {
    switch (t) {
      case 'Carbs':
        return AppColors.accentYellow;
      case 'Protein':
        return AppColors.accentOrange;
      case 'Vegetables':
        return AppColors.nutritionGreen;
      case 'Fruit':
        return AppColors.accentOrange;
      case 'Dairy':
        return AppColors.primaryTeal;
      case 'Hydration':
        return AppColors.secondaryTeal;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _ctrl.text.trim().isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Custom Food Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type the food name. We\'ll automatically detect its nutrition category.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Food name',
              hintText: 'e.g. Ostrich Meat, Pork Ribs, Pawpaw…',
              prefixIcon: const Icon(Icons.fastfood_outlined, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primaryTeal, width: 1.5),
              ),
            ),
            onChanged: _onChanged,
            onSubmitted: (_) {
              if (hasText) Navigator.pop(context, _ctrl.text.trim());
            },
          ),
          const SizedBox(height: 14),
          // ── LIVE NUTRITION PREVIEW ─────────────────────────────────
          if (_ctrl.text.trim().isNotEmpty) ...[
            const Text(
              'Detected nutrition category:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _detectedTags.isEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help_outline,
                          size: 13,
                          color: AppColors.textHint,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Unknown — will log without category',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _detectedTags.map((tag) {
                      final color = _tagColor(tag);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 12, color: color),
                            const SizedBox(width: 5),
                            Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
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
            elevation: 0,
          ),
          onPressed: hasText
              ? () => Navigator.pop(context, _ctrl.text.trim())
              : null,
          child: const Text('Add Item'),
        ),
      ],
    );
  }
}
