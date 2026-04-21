import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/laundry_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/supply_provider.dart';
import '../../providers/utility_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/home_pro_intelligence.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/smart_tips_section.dart';

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

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Home Pro Intelligence',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _AnalyticsHero(
            report: report,
            householdName: auth.household?.householdName ?? 'Your Household',
          ),
          if (!auth.isHomePro) ...[
            const SizedBox(height: 16),
            PremiumAnalyticsEntryCard(
              title: 'Unlock Home Pro Intelligence',
              subtitle:
                  'Turn household data into weekly rhythm, pressure forecasts, and practical playbooks.',
              icon: Icons.workspace_premium_rounded,
              highlights: const <String>[
                'Home pulse score',
                '7-day pressure map',
                'Household archetype',
              ],
              isUnlocked: false,
              onPressed: () => openHomeProUpgrade(
                context,
                source: 'home_pro_intelligence_screen',
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'Household Operating Map'),
          const SizedBox(height: 12),
          HomeFlowCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Larger, brighter nodes show routines doing more work to keep the home calm.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _HomeOrbitBoard(
                  homePulse: report.homePulse,
                  modules: report.modules,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: '7-Day Pressure Map'),
          const SizedBox(height: 12),
          _PressureMapCard(
            dayLabels: report.dayLabels,
            rows: report.forecastRows,
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'This Week\'s Playbook'),
          const SizedBox(height: 12),
          ...report.recommendations.map(
            (recommendation) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecommendationCard(recommendation: recommendation),
            ),
          ),
          const SizedBox(height: 8),
          if (report.tips.isNotEmpty)
            SmartTipsSection(
              tips: report.tips,
              title: 'Live Smart Tips',
            )
          else
            HomeFlowCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Live Smart Tips',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No urgent household signals yet. Keep logging meals, refills, and routines to make this screen even sharper.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          if (report.supplyMonthlySpend.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Monthly Supply Spend'),
            const SizedBox(height: 12),
            _SupplySpendCard(rows: report.supplyMonthlySpend),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsHero extends StatelessWidget {
  const _AnalyticsHero({
    required this.report,
    required this.householdName,
  });

  final HomeProIntelligenceReport report;
  final String householdName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            AppColors.primaryTeal,
            AppColors.secondaryTeal,
            AppColors.cardBlue,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text(
                  'HOME PRO INTELLIGENCE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const Spacer(),
              _HeroTag(
                label: householdName,
                tone: AppColors.tagTint,
                textColor: AppColors.secondaryTeal,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            report.headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            report.summary,
            style: const TextStyle(
              color: AppColors.tagTint,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetricCard(
                label: 'Home pulse',
                value: '${report.homePulse}',
                note: report.personaTitle,
              ),
              _HeroMetricCard(
                label: 'Recovered this week',
                value: '${report.calmHoursRecovered.toStringAsFixed(1)}h',
                note: 'estimated calm',
              ),
              _HeroMetricCard(
                label: 'Surprise shield',
                value: '${report.surpriseShield}',
                note: '${report.watchpointCount} live signals',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.blur_on_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.personaTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.personaSummary,
                  style: const TextStyle(
                    color: AppColors.surfaceTinted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: report.signals
                      .map((signal) => _SignalCard(signal: signal))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({
    required this.label,
    required this.tone,
    required this.textColor,
  });

  final String label;
  final Color tone;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({
    required this.label,
    required this.value,
    required this.note,
  });

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.surfaceCard,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: const TextStyle(
              color: AppColors.tagTint,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});

  final HomeProSignalMetric signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 184,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            signal.label,
            style: const TextStyle(
              color: AppColors.surfaceCard,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${signal.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            signal.note,
            style: const TextStyle(
              color: AppColors.surfaceMuted,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeOrbitBoard extends StatelessWidget {
  const _HomeOrbitBoard({
    required this.homePulse,
    required this.modules,
  });

  final int homePulse;
  final List<HomeProModuleNode> modules;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primaryTeal, Color(0xFF0A2850)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _OrbitBackdropPainter(),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: <Color>[AppColors.uiBlue, AppColors.primaryTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.uiBlue.withValues(alpha: 0.24),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'HOME PULSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$homePulse',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...modules.map(
            (module) => Align(
              alignment: _alignmentForModule(module.label),
              child: _OrbitModuleBubble(module: module),
            ),
          ),
        ],
      ),
    );
  }

  Alignment _alignmentForModule(String label) {
    switch (label) {
      case 'Meals':
        return const Alignment(-0.72, -0.58);
      case 'Utilities':
        return const Alignment(0.72, -0.56);
      case 'Laundry':
        return const Alignment(-0.68, 0.62);
      case 'Supplies':
        return const Alignment(0.7, 0.6);
      default:
        return const Alignment(0, -0.74);
    }
  }
}

class _OrbitModuleBubble extends StatelessWidget {
  const _OrbitModuleBubble({required this.module});

  final HomeProModuleNode module;

  @override
  Widget build(BuildContext context) {
    final accent = _toneColor(module.tone);
    final bubbleSize = 88 + (module.score * 0.28);

    return Container(
      width: bubbleSize,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForModule(module.label),
                color: accent,
                size: 18,
              ),
              const Spacer(),
              Text(
                '${module.score}',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            module.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            module.subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.surfaceCard,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForModule(String label) {
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
        return Icons.auto_awesome_rounded;
    }
  }
}

class _OrbitBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.uiBlue.withValues(alpha: 0.18);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);

    for (final radius in <double>[60, 104, 148]) {
      canvas.drawCircle(center, radius, ringPaint);
    }

    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.2),
      center,
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.21),
      center,
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.79),
      center,
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.78),
      center,
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PressureMapCard extends StatelessWidget {
  const _PressureMapCard({
    required this.dayLabels,
    required this.rows,
  });

  final List<String> dayLabels;
  final List<HomeProForecastRow> rows;

  @override
  Widget build(BuildContext context) {
    return HomeFlowCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Soft cells mean a calmer day. Warmer cells show where the next seven days may ask more of you.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const SizedBox(width: 88),
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
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            row.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      ...row.values.map(
                        (value) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: _pressureColor(value),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                              child: value >= 78
                                  ? const Center(
                                      child: Icon(
                                        Icons.priority_high_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    )
                                  : value >= 58
                                      ? Center(
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        )
                                      : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 88),
                    child: Text(
                      row.summary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
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

  Color _pressureColor(int value) {
    if (value >= 78) {
      return AppColors.accentOrange;
    }
    if (value >= 58) {
      return AppColors.accentYellow;
    }
    if (value >= 30) {
      return AppColors.highlightBlue;
    }
    return AppColors.surfaceMuted;
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});

  final HomeProRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final accent = _toneColor(recommendation.tone);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        recommendation.badge,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      recommendation.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${recommendation.score}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

Color _toneColor(String tone) {
  switch (tone) {
    case 'strong':
      return AppColors.primaryTeal;
    case 'warning':
      return AppColors.accentOrange;
    default:
      return AppColors.warningAmber;
  }
}

class _SupplySpendCard extends StatelessWidget {
  const _SupplySpendCard({required this.rows});
  final List<SupplySpendRow> rows;

  @override
  Widget build(BuildContext context) {
    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Item',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Spacer(),
              SizedBox(
                width: 84,
                child: Text(
                  'This Month',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(
                width: 84,
                child: Text(
                  'Last Month',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
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
                    SizedBox(
                      width: 84,
                      child: Text(
                        'KES ${row.thisMonthSpend.toStringAsFixed(0)}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        row.lastMonthSpend > 0
                            ? 'KES ${row.lastMonthSpend.toStringAsFixed(0)}'
                            : '—',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}