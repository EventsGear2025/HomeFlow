import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/laundry_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/supply_provider.dart';
import '../../providers/utility_provider.dart';
import '../../models/utility_tracker.dart';
import '../../utils/app_colors.dart';
import '../../utils/home_pro_intelligence.dart';
import '../../utils/smart_tips_engine.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';

// ─────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────

class HomeProAnalyticsScreen extends StatelessWidget {
  const HomeProAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final meals = context.watch<MealProvider>();
    final laundry = context.watch<LaundryProvider>();
    final supply = context.watch<SupplyProvider>();
    final utilities = context.watch<UtilityProvider>();
    final children = context.watch<ChildProvider>().children;

    final visibleSupplies = supply.visibleSupplies(isOwner: auth.isOwner);
    final visibleUtilities = utilities.visibleItems(isOwner: auth.isOwner);
    final report = HomeProIntelligenceEngine.build(
      meals: meals.mealLogs,
      laundry: laundry.items,
      supplies: visibleSupplies,
      utilities: visibleUtilities,
      householdMembers: auth.householdMembers.length,
      childrenCount: children.length,
    );

    final urgentTips = report.tips
        .where((t) =>
            t.severity == TipSeverity.alert ||
            t.severity == TipSeverity.warning)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Home Intelligence',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 1. Home Status
          _HomeStatusCard(report: report),

          if (!auth.isHomePro) ...[
            const SizedBox(height: 16),
            PremiumAnalyticsEntryCard(
              title: 'Unlock Home Intelligence',
              subtitle:
                  'See what needs attention, get a weekly outlook, and know what to do next.',
              icon: Icons.workspace_premium_rounded,
              highlights: const <String>[
                'Home status overview',
                'This week\'s outlook',
                'Clear next actions',
              ],
              isUnlocked: false,
              onPressed: () => openHomeProUpgrade(
                context,
                source: 'home_pro_intelligence_screen',
              ),
            ),
          ],

          // 2. Needs Attention
          if (urgentTips.isNotEmpty) ...[
            const SizedBox(height: 16),
            _FoldableSection(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.accentOrange,
              title: 'Needs Attention',
              summary: '${urgentTips.length} item${urgentTips.length == 1 ? '' : 's'} need attention',
              summaryColor: AppColors.accentOrange,
              initiallyExpanded: true,
              child: Column(
                children: urgentTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AttentionCard(tip: tip),
                  ),
                ).toList(),
              ),
            ),
          ],

          // 3. Module Health
          const SizedBox(height: 12),
          _FoldableSection(
            icon: Icons.dashboard_outlined,
            title: 'Module Health',
            summary: () {
              final onTrack = report.modules.where((m) => m.score >= 70).length;
              return '$onTrack/${report.modules.length} modules on track';
            }(),
            child: _ModuleHealthList(modules: report.modules),
          ),

          // 4. This Week
          const SizedBox(height: 12),
          _FoldableSection(
            icon: Icons.calendar_today_outlined,
            title: 'This Week',
            summary: () {
              final busy = report.forecastRows
                  .expand((r) => r.values)
                  .fold(0, (a, b) => a + b);
              return busy == 0 ? 'Quiet week ahead' : 'Activity forecast ready';
            }(),
            child: _WeeklyTimelineCard(
              dayLabels: report.dayLabels,
              forecastRows: report.forecastRows,
            ),
          ),

          // 5. What to Do Next
          const SizedBox(height: 12),
          _FoldableSection(
            icon: Icons.checklist_rounded,
            title: 'What to Do Next',
            summary: '${report.recommendations.take(3).length} action${report.recommendations.take(3).length == 1 ? '' : 's'} pending',
            child: Column(
              children: report.recommendations.take(3).map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionCard(recommendation: rec),
                ),
              ).toList(),
            ),
          ),

          // 6. Household Rhythm
          const SizedBox(height: 12),
          _FoldableSection(
            icon: Icons.loop_rounded,
            title: 'Household Rhythm',
            summary: () {
              final score = report.rhythmScore;
              if (score >= 70) return 'Rhythm score: $score — great consistency';
              if (score >= 50) return 'Rhythm score: $score — steady';
              return 'Rhythm score: $score — needs attention';
            }(),
            summaryColor: report.rhythmScore >= 70
                ? AppColors.success
                : report.rhythmScore >= 50
                    ? AppColors.warningAmber
                    : AppColors.accentOrange,
            child: _RhythmCard(modules: report.modules),
          ),

          // 7. Deeper Insights
          const SizedBox(height: 12),
          _FoldableSection(
            icon: Icons.analytics_outlined,
            title: 'Deeper Insights',
            summary: 'Weekly outlook · Supply spend · Profile',
            child: _DeepInsightsContent(report: report, utilities: visibleUtilities),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared: foldable section wrapper
// ─────────────────────────────────────────────

class _FoldableSection extends StatefulWidget {
  const _FoldableSection({
    required this.title,
    required this.summary,
    required this.child,
    this.icon,
    this.iconColor,
    this.summaryColor,
    this.initiallyExpanded = false,
  });

  final String title;
  final String summary;
  final Widget child;
  final IconData? icon;
  final Color? iconColor;
  final Color? summaryColor;
  final bool initiallyExpanded;

  @override
  State<_FoldableSection> createState() => _FoldableSectionState();
}

class _FoldableSectionState extends State<_FoldableSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ribbon ──────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(14))
                  : BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon,
                      size: 17,
                      color: widget.iconColor ?? AppColors.primaryTeal),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.summary,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.summaryColor ?? AppColors.textSecondary,
                          fontWeight: widget.summaryColor != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        // ── Expanded content ─────────────────────────────────────
        if (_expanded)
          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border(
                left: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
                right: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
                bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
              child: widget.child,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shared: section label
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.accentOrange,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Section 1: Home Status card
// ─────────────────────────────────────────────

class _ChipData {
  const _ChipData({
    required this.label,
    required this.color,
    required this.bg,
  });
  final String label;
  final Color color;
  final Color bg;
}

class _HomeStatusCard extends StatelessWidget {
  const _HomeStatusCard({required this.report});

  final HomeProIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(report.homePulse);
    final statusColor = _statusColor(report.homePulse);
    final chips = _quickChips(report);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.home_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Home status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            report.summary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (chip) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: chip.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      chip.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: chip.color,
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

  String _statusLabel(int pulse) {
    if (pulse >= 75) return 'Good';
    if (pulse >= 55) return 'Fair';
    return 'Needs attention';
  }

  Color _statusColor(int pulse) {
    if (pulse >= 75) return AppColors.success;
    if (pulse >= 55) return AppColors.warningAmber;
    return AppColors.accentOrange;
  }

  List<_ChipData> _quickChips(HomeProIntelligenceReport r) {
    final chips = <_ChipData>[];

    // Chip 1: areas needing attention
    final attnCount = r.modules.where((m) => m.score < 55).length;
    if (attnCount > 0) {
      chips.add(_ChipData(
        label: '$attnCount area${attnCount == 1 ? '' : 's'} need attention',
        color: AppColors.accentOrange,
        bg: AppColors.accentOrange.withValues(alpha: 0.09),
      ));
    } else {
      chips.add(_ChipData(
        label: 'All areas okay',
        color: AppColors.success,
        bg: AppColors.success.withValues(alpha: 0.08),
      ));
    }

    // Chip 2: supply status
    final supplyModule =
        r.modules.where((m) => m.label == 'Supplies').firstOrNull;
    if (supplyModule != null) {
      if (supplyModule.score < 55) {
        final label = supplyModule.subtitle.length > 28
            ? 'Supplies low'
            : supplyModule.subtitle;
        chips.add(_ChipData(
          label: label,
          color: AppColors.warningAmber,
          bg: AppColors.warningAmber.withValues(alpha: 0.09),
        ));
      } else {
        chips.add(_ChipData(
          label: 'Supplies okay',
          color: AppColors.success,
          bg: AppColors.success.withValues(alpha: 0.08),
        ));
      }
    }

    // Chip 3: utilities status
    final utilModule =
        r.modules.where((m) => m.label == 'Utilities').firstOrNull;
    if (utilModule != null) {
      if (utilModule.score < 55) {
        chips.add(_ChipData(
          label: 'Utilities need attention',
          color: AppColors.accentOrange,
          bg: AppColors.accentOrange.withValues(alpha: 0.09),
        ));
      } else {
        chips.add(_ChipData(
          label: 'Utilities okay',
          color: AppColors.primaryTeal,
          bg: AppColors.primaryTeal.withValues(alpha: 0.07),
        ));
      }
    }

    return chips;
  }
}

// ─────────────────────────────────────────────
// Section 2: Needs Attention
// ─────────────────────────────────────────────

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.tip});

  final SmartTip tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tip.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tip.bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(tip.icon, color: tip.color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section 3: Module Health
// ─────────────────────────────────────────────

class _ModuleHealthList extends StatelessWidget {
  const _ModuleHealthList({required this.modules});

  final List<HomeProModuleNode> modules;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: modules.asMap().entries.map((entry) {
          final isLast = entry.key == modules.length - 1;
          return Column(
            children: [
              _ModuleHealthRow(module: entry.value),
              if (!isLast)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ModuleHealthRow extends StatelessWidget {
  const _ModuleHealthRow({required this.module});

  final HomeProModuleNode module;

  @override
  Widget build(BuildContext context) {
    final statusColor = _scoreColor(module.score);
    final statusLabel = _scoreLabel(module.score);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _moduleIcon(module.label),
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      module.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: module.score / 100,
                    minHeight: 4,
                    backgroundColor: statusColor.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  module.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${module.score}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 70) return AppColors.success;
    if (score >= 50) return AppColors.warningAmber;
    return AppColors.accentOrange;
  }

  String _scoreLabel(int score) {
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Needs attention';
  }

  IconData _moduleIcon(String label) {
    switch (label) {
      case 'Meals':
        return Icons.restaurant_rounded;
      case 'Laundry':
        return Icons.local_laundry_service_rounded;
      case 'Supplies':
        return Icons.inventory_2_rounded;
      case 'Utilities':
        return Icons.bolt_rounded;
      default:
        return Icons.home_rounded;
    }
  }
}

// ─────────────────────────────────────────────
// Section 4: This Week — 7-day readiness strip
// ─────────────────────────────────────────────

class _WeeklyTimelineCard extends StatelessWidget {
  const _WeeklyTimelineCard({
    required this.dayLabels,
    required this.forecastRows,
  });

  final List<String> dayLabels;
  final List<HomeProForecastRow> forecastRows;

  int _dayPressure(int dayIdx) {
    if (forecastRows.isEmpty) return 0;
    return forecastRows
        .map((r) => dayIdx < r.values.length ? r.values[dayIdx] : 0)
        .reduce(math.max);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              dayLabels.length,
              (i) => Expanded(
                child: _DayCell(
                  label: dayLabels[i],
                  pressure: _dayPressure(i),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              _LegendDot(color: AppColors.highlightBlue, label: 'Calm'),
              SizedBox(width: 14),
              _LegendDot(color: AppColors.warningAmber, label: 'Watch'),
              SizedBox(width: 14),
              _LegendDot(color: AppColors.accentOrange, label: 'Attention'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.label, required this.pressure});

  final String label;
  final int pressure;

  Color _pressureColor(int v) {
    if (v >= 75) return AppColors.accentOrange;
    if (v >= 50) return AppColors.warningAmber;
    return AppColors.highlightBlue;
  }

  String _pressureLabel(int v) {
    if (v >= 75) return 'Attention';
    if (v >= 50) return 'Watch';
    return 'Calm';
  }

  @override
  Widget build(BuildContext context) {
    final color = _pressureColor(pressure);
    final statusText = _pressureLabel(pressure);

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: pressure >= 50
              ? Icon(
                  pressure >= 75
                      ? Icons.priority_high_rounded
                      : Icons.remove_rounded,
                  size: 14,
                  color: color,
                )
              : Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 5),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Section 5: What to Do Next
// ─────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.recommendation});

  final HomeProRecommendation recommendation;

  String _typeLabel(String tone) {
    switch (tone) {
      case 'warning':
        return 'Urgent now';
      case 'strong':
        return 'Keep doing this';
      default:
        return 'Do today';
    }
  }

  Color _typeColor(String tone) {
    switch (tone) {
      case 'warning':
        return AppColors.accentOrange;
      case 'strong':
        return AppColors.success;
      default:
        return AppColors.warningAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _typeLabel(recommendation.tone);
    final typeColor = _typeColor(recommendation.tone);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                color: typeColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            recommendation.body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section 6: Household Rhythm
// ─────────────────────────────────────────────

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({required this.modules});

  final List<HomeProModuleNode> modules;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: modules.asMap().entries.map((entry) {
          final isLast = entry.key == modules.length - 1;
          return Column(
            children: [
              _RhythmRow(module: entry.value),
              if (!isLast)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _RhythmRow extends StatelessWidget {
  const _RhythmRow({required this.module});

  final HomeProModuleNode module;

  String get _trendLabel {
    if (module.score >= 70) return '${module.label} consistency ↑ this week';
    if (module.score >= 50) return '${module.label} is steady';
    return '${module.label} needs more attention';
  }

  String get _trendBadge {
    if (module.score >= 70) return 'On track';
    if (module.score >= 50) return 'Steady';
    return 'Behind';
  }

  IconData get _trendIcon {
    if (module.score >= 70) return Icons.trending_up_rounded;
    if (module.score >= 50) return Icons.trending_flat_rounded;
    return Icons.trending_down_rounded;
  }

  Color get _trendColor {
    if (module.score >= 70) return AppColors.success;
    if (module.score >= 50) return AppColors.warningAmber;
    return AppColors.accentOrange;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trendLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  module.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _trendColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_trendIcon, size: 14, color: _trendColor),
                const SizedBox(width: 4),
                Text(
                  _trendBadge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _trendColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section 7: Deeper Insights content
// ─────────────────────────────────────────────

class _DeepInsightsContent extends StatelessWidget {
  const _DeepInsightsContent({required this.report, required this.utilities});

  final HomeProIntelligenceReport report;
  final List<UtilityTracker> utilities;

  @override
  Widget build(BuildContext context) {
    final waterItems = utilities.where(
      (u) => u.type == UtilityType.waterBill && u.waterBillUnitsUsed != null,
    ).toList();
    final electricityItems = utilities
        .where((u) => u.type == UtilityType.electricity && !u.isPostpaid)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (waterItems.isNotEmpty) ...[            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SectionLabel(title: 'Water Usage'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _WaterUsageTile(items: waterItems),
            ),
            const SizedBox(height: 20),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SectionLabel(title: 'Weekly Outlook'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _OutlookCard(
              dayLabels: report.dayLabels,
              rows: report.forecastRows,
            ),
          ),
          if (report.supplyMonthlySpend.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SectionLabel(title: 'Monthly Supply Spend'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SupplySpendCard(rows: report.supplyMonthlySpend),
            ),
          ],
          if (electricityItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SectionLabel(title: 'Electricity Tokens'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ElectricityTokenInsightsCard(items: electricityItems),
            ),
          ],
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _SectionLabel(title: 'Household Profile'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.personaTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.personaSummary,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
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

// ─────────────────────────────────────────────
// Water usage tile (analytics)
// ─────────────────────────────────────────────

class _WaterUsageTile extends StatelessWidget {
  const _WaterUsageTile({required this.items});

  final List<UtilityTracker> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop_outlined, size: 18, color: AppColors.primaryTeal),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Metered Water',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Units consumed this billing cycle',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) {
            final units = item.waterBillUnitsUsed!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (units / 50.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${units.toStringAsFixed(1)} m³',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 2),
          Text(
            items.length == 1
                ? 'Tip: track units monthly to spot usage spikes early.'
                : '${items.length} meters tracked.',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ElectricityTokenInsightsCard extends StatelessWidget {
  const _ElectricityTokenInsightsCard({required this.items});

  final List<UtilityTracker> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_outlined,
                  size: 18,
                  color: AppColors.statusLowText,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prepaid Electricity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Spend, units, and estimated runway from recent top-ups',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) {
            final latest = item.latestElectricityTokenPurchase;
            final monthSpend = item.electricityTokenSpendThisMonth;
            final monthUnits = item.electricityTokenUnitsThisMonth;
            final avgCost = item.electricityAverageCostPerUnit;
            final avgDaily = item.electricityAverageDailyConsumption;
            final daysLeft = item.electricityEstimatedDaysRemaining;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.divider.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last top-up: KSh ${latest.amountSpent.toStringAsFixed(0)} for ${latest.unitsBought.toStringAsFixed(1)} kWh',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InsightMetricChip(
                        label: 'This month',
                        value: 'KSh ${monthSpend.toStringAsFixed(0)}',
                      ),
                      _InsightMetricChip(
                        label: 'Units bought',
                        value: '${monthUnits.toStringAsFixed(1)} kWh',
                      ),
                      if (avgCost != null)
                        _InsightMetricChip(
                          label: 'Avg cost',
                          value: 'KSh ${avgCost.toStringAsFixed(1)}/kWh',
                        ),
                      if (avgDaily != null)
                        _InsightMetricChip(
                          label: 'Avg use',
                          value: '${avgDaily.toStringAsFixed(1)} kWh/day',
                        ),
                      if (daysLeft != null)
                        _InsightMetricChip(
                          label: 'Estimated left',
                          value: '$daysLeft day${daysLeft == 1 ? '' : 's'}',
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InsightMetricChip extends StatelessWidget {
  const _InsightMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlookCard extends StatelessWidget {
  const _OutlookCard({required this.dayLabels, required this.rows});

  final List<String> dayLabels;
  final List<HomeProForecastRow> rows;

  Color _heatColor(int value) {
    if (value >= 78) return AppColors.accentOrange;
    if (value >= 58) return AppColors.accentYellow;
    if (value >= 30) return AppColors.highlightBlue;
    return AppColors.surfaceMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 72),
              ...dayLabels.map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  ...row.values.map(
                    (value) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: _heatColor(value),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: const [
              _LegendDot(color: AppColors.surfaceMuted, label: 'Quiet'),
              SizedBox(width: 10),
              _LegendDot(color: AppColors.highlightBlue, label: 'Active'),
              SizedBox(width: 10),
              _LegendDot(color: AppColors.accentYellow, label: 'Watch'),
              SizedBox(width: 10),
              _LegendDot(color: AppColors.accentOrange, label: 'Urgent'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupplySpendCard extends StatelessWidget {
  const _SupplySpendCard({required this.rows});

  final List<SupplySpendRow> rows;

  static const _categoryIcons = <String, IconData>{
    'Food & Groceries': Icons.shopping_basket_outlined,
    'Cleaning': Icons.cleaning_services_outlined,
    'Personal Care': Icons.self_improvement_outlined,
    'Baby & Kids': Icons.child_care_outlined,
    'Pet Supplies': Icons.pets_outlined,
    'Kitchen': Icons.kitchen_outlined,
    'Beverages': Icons.local_cafe_outlined,
    'Health': Icons.medication_outlined,
  };

  Color _trendColor(double thisM, double lastM) {
    if (lastM <= 0) return AppColors.textSecondary;
    return thisM > lastM ? AppColors.accentOrange : AppColors.success;
  }

  IconData _trendIcon(double thisM, double lastM) {
    if (lastM <= 0) return Icons.fiber_new_outlined;
    return thisM > lastM ? Icons.trending_up_rounded : Icons.trending_down_rounded;
  }

  String _trendLabel(double thisM, double lastM) {
    if (lastM <= 0) return 'First month';
    final pct = ((thisM - lastM) / lastM * 100).round();
    return pct == 0 ? 'Same as last' : '${pct > 0 ? '+' : ''}$pct% vs last';
  }

  @override
  Widget build(BuildContext context) {
    final totalThis = rows.fold<double>(0, (s, r) => s + r.thisMonthSpend);
    final totalLast = rows.fold<double>(0, (s, r) => s + r.lastMonthSpend);
    final maxSpend = rows.fold<double>(0, (s, r) => r.thisMonthSpend > s ? r.thisMonthSpend : s);
    final now = DateTime.now();
    final monthLabel = _monthName(now.month);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: AppColors.primaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$monthLabel supply spend',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'KES ${_fmt(totalThis)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // ── Rows ────────────────────────────────────────────────
          ...rows.map((row) {
            final barFraction = maxSpend > 0 ? row.thisMonthSpend / maxSpend : 0.0;
            final trendColor = _trendColor(row.thisMonthSpend, row.lastMonthSpend);
            final trendIcon = _trendIcon(row.thisMonthSpend, row.lastMonthSpend);
            final trendText = _trendLabel(row.thisMonthSpend, row.lastMonthSpend);
            final catIcon = _categoryIcons[row.category] ?? Icons.inventory_2_outlined;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category icon chip
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(catIcon,
                            size: 18, color: AppColors.primaryTeal),
                      ),
                      const SizedBox(width: 12),
                      // Name + category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.itemName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              row.category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // This month amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'KES ${_fmt(row.thisMonthSpend)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryTeal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(trendIcon, size: 12, color: trendColor),
                              const SizedBox(width: 2),
                              Text(
                                trendText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: trendColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Spend bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barFraction,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryTeal.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (row != rows.last)
                    const Divider(height: 1, color: AppColors.divider),
                ],
              ),
            );
          }),
          // ── Totals footer ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                const Icon(Icons.summarize_outlined,
                    size: 16, color: AppColors.primaryTeal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Total this month',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                if (totalLast > 0) ...[
                  Text(
                    'Last: KES ${_fmt(totalLast)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  'KES ${_fmt(totalThis)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.truncateToDouble() ? '${k.toInt()}k' : '${k.toStringAsFixed(1)}k';
    }
    return v.toStringAsFixed(0);
  }

  String _monthName(int m) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[m];
  }

}
