import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/utility_tracker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/laundry_provider.dart';
import '../../providers/utility_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/smart_tips_engine.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/smart_tips_section.dart';
import '../dashboard/home_pro_analytics_screen.dart';
import '../supplies/supplies_screen.dart';

class UtilitiesScreen extends StatelessWidget {
  const UtilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Utilities'),
      ),
      body: const UtilitiesBody(),
    );
  }
}

class UtilitiesAnalyticsScreen extends StatelessWidget {
  const UtilitiesAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final utilProv = context.watch<UtilityProvider>();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Utilities Analytics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.isHomePro)
            ...[
              PremiumAnalyticsEntryCard(
                title: 'Home Pro Intelligence',
                subtitle:
                    'See how utility deadlines, refills, and due-soon bills affect the calm of the whole home this week.',
                icon: Icons.auto_graph_rounded,
                highlights: const [
                  'Due-soon shield',
                  'Utility pressure map',
                  'Whole-home playbook',
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
              _UtilitiesAnalyticsPanel(
                utilProv: utilProv,
                isOwner: auth.isOwner,
              ),
            ]
          else
            _AnalyticsUpsellView(
              icon: Icons.bolt_outlined,
              title: 'Utilities Analytics',
              features: const [
                'Monthly bill forecasting',
                'Due-soon tracking',
                'Payment posture overview',
                'Refill & reorder insights',
              ],
              onUpgrade: () => openHomeProUpgrade(
                context,
                source: 'utilities_analytics_screen',
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class UtilitiesBody extends StatelessWidget {
  const UtilitiesBody({super.key});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.isOwner;
    final householdId = auth.household?.id ?? '';

    // Look up each tracker
    final gas = utilProv.gasItems.isNotEmpty ? utilProv.gasItems.first : null;
    final elec = utilProv.electricityItems.isNotEmpty
        ? utilProv.electricityItems.first
        : null;
    final water = utilProv.waterItems
        .where((i) => i.isDrinkingWater)
        .isNotEmpty
        ? utilProv.waterItems.where((i) => i.isDrinkingWater).first
        : null;
    final internet = utilProv.internetItems.isNotEmpty
        ? utilProv.internetItems.first
        : null;
    final waterBill = utilProv.waterBillItems.isNotEmpty
        ? utilProv.waterBillItems.first
        : null;
    final serviceCharge = utilProv.serviceChargeItems.isNotEmpty
        ? utilProv.serviceChargeItems.first
        : null;
    final rent =
        utilProv.rentItems.isNotEmpty ? utilProv.rentItems.first : null;
    final payTv =
        utilProv.payTvItems.isNotEmpty ? utilProv.payTvItems.first : null;

    // Build section entries — managers skip owner-only sections
    final sections = [
      _SectionEntry(
        icon: Icons.local_fire_department_outlined,
        title: 'Cooking Gas',
        tracker: gas,
        child: const GasTabSection(embedded: true),
      ),
      _SectionEntry(
        icon: Icons.bolt_outlined,
        title: 'Electricity',
        tracker: elec,
        child: const ElectricityTabSection(embedded: true),
      ),
      _SectionEntry(
        icon: Icons.water_drop_outlined,
        title: 'Drinking Water',
        tracker: water,
        child: const DrinkingWaterTabSection(embedded: true),
      ),
      _SectionEntry(
        icon: Icons.wifi_outlined,
        title: 'Internet',
        tracker: internet,
        child: const InternetTabSection(embedded: true),
      ),
      _SectionEntry(
        icon: Icons.water_outlined,
        title: 'Metered Water',
        tracker: waterBill,
        child: const MeteredWaterTabSection(embedded: true),
      ),
      _SectionEntry(
        icon: Icons.cleaning_services_outlined,
        title: 'Service Charge',
        tracker: serviceCharge,
        child: const ServiceChargeTabSection(embedded: true),
      ),
      _SectionEntry(
        icon: Icons.home_outlined,
        title: 'Rent',
        tracker: rent,
        child: const RentTabSection(embedded: true),
      ),
      _SectionEntry(
        icon: Icons.tv_outlined,
        title: 'Pay TV',
        tracker: payTv,
        child: const PayTvTabSection(embedded: true),
      ),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _UtilitiesAnalyticsSummary(
          utilProv: utilProv,
          isOwner: isOwner,
          isPro: auth.isHomePro,
        ),
        for (final entry in sections)
          // Managers: hide owner-only sections entirely
          if (isOwner || !(entry.tracker?.isOwnerOnly ?? false))
            _UtilSection(
              icon: entry.icon,
              title: entry.title,
              tracker: entry.tracker,
              isOwner: isOwner,
              householdId: householdId,
              child: entry.child,
            ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Compact analytics summary – sits at the top of the utilities list
// ─────────────────────────────────────────────────────────────────
class _UtilitiesAnalyticsSummary extends StatelessWidget {
  final UtilityProvider utilProv;
  final bool isOwner;
  final bool isPro;

  const _UtilitiesAnalyticsSummary({
    required this.utilProv,
    required this.isOwner,
    required this.isPro,
  });

  @override
  Widget build(BuildContext context) {
    final items = utilProv.visibleItems(isOwner: isOwner);
    final total = items.length;
    final alerts = items.where((i) => i.isLowAlert).length;
    final dueSoon = items.where((i) {
      final days = _daysUntilDue(i);
      return days != null && days <= 7;
    }).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isPro) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UtilitiesAnalyticsScreen(),
                ),
              );
            } else {
              openHomeProUpgrade(context, source: 'utilities_summary_strip');
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryTeal.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  size: 16,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: 10),
                _SummaryChip(
                  value: '$total',
                  label: 'bills',
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: 14),
                _SummaryChip(
                  value: '$dueSoon',
                  label: 'due soon',
                  color: dueSoon > 0
                      ? AppColors.accentOrange
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                _SummaryChip(
                  value: '$alerts',
                  label: alerts == 1 ? 'alert' : 'alerts',
                  color: alerts > 0
                      ? AppColors.statusVeryLowText
                      : AppColors.textSecondary,
                ),
                const Spacer(),
                if (!isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentOrange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                if (isPro)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int? _daysUntilDue(UtilityTracker item) {
    switch (item.type) {
      case UtilityType.electricity:
        return item.isPostpaid ? item.electricityDaysUntilDue : null;
      case UtilityType.internet:
        return item.internetDaysUntilDue;
      case UtilityType.waterBill:
        return item.waterBillDaysUntilDue;
      case UtilityType.serviceCharge:
        return item.serviceChargeDaysUntilDue;
      case UtilityType.rent:
        return item.rentDaysUntilDue;
      case UtilityType.payTv:
        return item.payTvDaysUntilDue;
      default:
        return null;
    }
  }
}

class _SummaryChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Clean upsell view for the analytics screen (replaces PlanUpsellCard)
// ─────────────────────────────────────────────────────────────────
class _AnalyticsUpsellView extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> features;
  final VoidCallback onUpgrade;

  const _AnalyticsUpsellView({
    required this.icon,
    required this.title,
    required this.features,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: AppColors.primaryTeal),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Available with Home Pro',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        ...features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.primaryTeal.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  f,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: onUpgrade,
            child: const Text('Upgrade to Home Pro'),
          ),
        ),
      ],
    );
  }
}

class _UtilitiesAnalyticsPanel extends StatelessWidget {
  final UtilityProvider utilProv;
  final bool isOwner;

  const _UtilitiesAnalyticsPanel({
    required this.utilProv,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final laundry = context.watch<LaundryProvider>();
    final visibleItems = utilProv.visibleItems(isOwner: isOwner);
    final alertCount = visibleItems.where((item) => item.isLowAlert).length;
    final paidCount = visibleItems.where(_isPaidUtility).length;
    final dueSoonItems = visibleItems.where((item) {
      final days = _daysUntilDue(item);
      return days != null && days <= 7 && !_isPaidUtility(item);
    }).toList()
      ..sort((a, b) => (_daysUntilDue(a) ?? 999).compareTo(_daysUntilDue(b) ?? 999));

    final monthlyDueTotal = visibleItems.fold<double>(0, (sum, item) {
      return sum + _monthlyExposure(item);
    });

    final unpaidWithValue = visibleItems.where((item) {
      return !_isPaidUtility(item) && _monthlyExposure(item) > 0;
    }).length;

    final gas = utilProv.gasItems.where((item) => isOwner || !item.isOwnerOnly).cast<UtilityTracker?>().firstWhere(
          (item) => item != null,
          orElse: () => null,
        );
    final drinkingWater = utilProv.waterItems
        .where((item) => item.isDrinkingWater && (isOwner || !item.isOwnerOnly))
        .cast<UtilityTracker?>()
        .firstWhere((item) => item != null, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Utilities Analytics'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _UtilityMetricCard(
                label: 'Expected Bills',
                value: 'KSh ${monthlyDueTotal.toStringAsFixed(0)}',
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _UtilityMetricCard(
                label: 'Due Soon',
                value: '${dueSoonItems.length}',
                icon: Icons.schedule_outlined,
                color: AppColors.accentOrange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _UtilityMetricCard(
                label: 'Alerts',
                value: '$alertCount',
                icon: Icons.warning_amber_rounded,
                color: AppColors.statusVeryLowText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _UtilityMetricCard(
                label: 'Paid',
                value: '$paidCount/${visibleItems.length}',
                icon: Icons.check_circle_outline,
                color: AppColors.statusEnoughText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HomeFlowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upcoming Obligations',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (dueSoonItems.isEmpty)
                      const Text(
                        'No unpaid utilities are due in the next 7 days.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      )
                    else
                      ...dueSoonItems.take(4).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _UpcomingUtilityRow(
                            label: item.label,
                            detail: _dueLabel(item),
                            amount: _monthlyExposure(item),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeFlowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Posture',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _UtilityStatRow(
                      label: 'Tracked utilities',
                      value: '${visibleItems.length}',
                    ),
                    _UtilityStatRow(
                      label: 'Unpaid with amount',
                      value: '$unpaidWithValue',
                    ),
                    _UtilityStatRow(
                      label: 'Active alerts',
                      value: '$alertCount',
                    ),
                    _UtilityStatRow(
                      label: 'Payment complete',
                      value: '$paidCount',
                      highlight: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        HomeFlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Forecast Insights',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (gas != null)
                _ForecastInsightRow(
                  icon: Icons.local_fire_department_outlined,
                  title: gas.label,
                  detail: gas.gasStatusMessage,
                ),
              if (gas != null && drinkingWater != null)
                const SizedBox(height: 10),
              if (drinkingWater != null)
                _ForecastInsightRow(
                  icon: Icons.water_drop_outlined,
                  title: drinkingWater.label,
                  detail:
                      '${drinkingWater.drinkingWaterDaysRemaining} day${drinkingWater.drinkingWaterDaysRemaining == 1 ? '' : 's'} estimated before reorder pressure. ${drinkingWater.drinkingWaterStatusMessage}',
                ),
              if (gas == null && drinkingWater == null)
                const Text(
                  'Set up gas or drinking water tracking to unlock refill and reorder forecasting here.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        Builder(builder: (ctx) {
          final utilTips = [
            ...SmartTipsEngine.analyzeUtilities(visibleItems),
            ...SmartTipsEngine.analyzeLaundry(laundry.items),
          ];
          if (utilTips.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SmartTipsSection(
              tips: utilTips,
              title: 'Smart Insights',
            ),
          );
        }),
      ],
    );
  }

  bool _isPaidUtility(UtilityTracker item) {
    switch (item.type) {
      case UtilityType.electricity:
        return item.isPostpaid
            ? item.electricityPaymentStatus == UtilityPaymentStatus.paid
            : !item.isLowAlert;
      case UtilityType.internet:
        return item.internetPaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.water:
        return item.isDrinkingWater
            ? item.paymentStatus == UtilityPaymentStatus.paid
            : !item.isLowAlert;
      case UtilityType.waterBill:
        return item.waterBillPaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.serviceCharge:
        return item.serviceChargePaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.rent:
        return item.rentPaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.payTv:
        return item.payTvPaymentStatus == UtilityPaymentStatus.paid;
      case UtilityType.cookingGas:
        return !item.isLowAlert;
      case UtilityType.other:
        return !item.isLowAlert;
    }
  }

  int? _daysUntilDue(UtilityTracker item) {
    switch (item.type) {
      case UtilityType.electricity:
        return item.isPostpaid ? item.electricityDaysUntilDue : null;
      case UtilityType.internet:
        return item.internetDaysUntilDue;
      case UtilityType.waterBill:
        return item.waterBillDaysUntilDue;
      case UtilityType.serviceCharge:
        return item.serviceChargeDaysUntilDue;
      case UtilityType.rent:
        return item.rentDaysUntilDue;
      case UtilityType.payTv:
        return item.payTvDaysUntilDue;
      default:
        return null;
    }
  }

  double _monthlyExposure(UtilityTracker item) {
    switch (item.type) {
      case UtilityType.electricity:
        if (item.isPostpaid) return item.lastBillAmount ?? 0;
        return item.typicalTokenAmount ?? 0;
      case UtilityType.internet:
        return item.internetMonthlyAmount ?? 0;
      case UtilityType.water:
        if (item.isDrinkingWater) {
          final price = item.pricePerContainer ?? 0;
          final quantity = item.typicalOrderQuantity ?? 0;
          final frequency = item.reorderFrequencyDays ?? 0;
          if (price <= 0 || quantity <= 0 || frequency <= 0) return 0;
          return price * quantity * (30 / frequency);
        }
        return 0;
      case UtilityType.waterBill:
        return item.waterBillAmount ?? 0;
      case UtilityType.serviceCharge:
        return item.serviceChargeAmount ?? 0;
      case UtilityType.rent:
        return item.rentAmount ?? 0;
      case UtilityType.payTv:
        return item.payTvMonthlyAmount ?? 0;
      default:
        return 0;
    }
  }

  String _dueLabel(UtilityTracker item) {
    final days = _daysUntilDue(item);
    final amount = _monthlyExposure(item);
    final amountLabel = amount > 0 ? ' · KSh ${amount.toStringAsFixed(0)}' : '';
    if (days == null) return 'Needs setup or manual tracking$amountLabel';
    if (days <= 0) return 'Due today$amountLabel';
    if (days == 1) return 'Due in 1 day$amountLabel';
    return 'Due in $days days$amountLabel';
  }
}

class _UtilityMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _UtilityMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return HomeFlowCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingUtilityRow extends StatelessWidget {
  final String label;
  final String detail;
  final double amount;

  const _UpcomingUtilityRow({
    required this.label,
    required this.detail,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.accentOrange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UtilityStatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _UtilityStatRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.primaryTeal : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastInsightRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _ForecastInsightRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryTeal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simple data holder for a utility section entry.
class _SectionEntry {
  final IconData icon;
  final String title;
  final UtilityTracker? tracker;
  final Widget child;
  const _SectionEntry(
      {required this.icon,
      required this.title,
      required this.tracker,
      required this.child});
}

class _UtilSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final UtilityTracker? tracker;
  final bool isOwner;
  final String householdId;

  const _UtilSection({
    required this.icon,
    required this.title,
    required this.child,
    required this.isOwner,
    required this.householdId,
    this.tracker,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnerOnly = tracker?.isOwnerOnly ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // Visibility toggle — owner only
              if (isOwner && tracker != null)
                GestureDetector(
                  onTap: () {
                    context
                        .read<UtilityProvider>()
                        .toggleOwnerOnly(tracker!.id, householdId);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOwnerOnly
                          ? AppColors.accentOrange.withValues(alpha: 0.12)
                          : AppColors.primaryTeal.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOwnerOnly
                            ? AppColors.accentOrange.withValues(alpha: 0.35)
                            : AppColors.primaryTeal.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOwnerOnly
                              ? Icons.lock_outline_rounded
                              : Icons.visibility_outlined,
                          size: 12,
                          color: isOwnerOnly
                              ? AppColors.accentOrange
                              : AppColors.primaryTeal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOwnerOnly ? 'Owner only' : 'All can see',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOwnerOnly
                                ? AppColors.accentOrange
                                : AppColors.primaryTeal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        child,
        // Log amount used — for consumption-type utilities only
        if (tracker != null &&
            (tracker!.type == UtilityType.cookingGas ||
                tracker!.type == UtilityType.electricity ||
                tracker!.type == UtilityType.water ||
                tracker!.type == UtilityType.waterBill))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _LogUtilityUsageSheet(
                  tracker: tracker!,
                  householdId: householdId,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note_rounded,
                      size: 14, color: AppColors.primaryTeal),
                  const SizedBox(width: 4),
                  Text(
                    tracker!.usageLogs.isEmpty
                        ? 'Log amount used'
                        : 'Log amount used · ${tracker!.usageLogs.length} entr${tracker!.usageLogs.length == 1 ? 'y' : 'ies'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// LOG UTILITY USAGE SHEET
// ─────────────────────────────────────────────────────────────────
class _LogUtilityUsageSheet extends StatefulWidget {
  final UtilityTracker tracker;
  final String householdId;

  const _LogUtilityUsageSheet({
    required this.tracker,
    required this.householdId,
  });

  @override
  State<_LogUtilityUsageSheet> createState() =>
      _LogUtilityUsageSheetState();
}

class _LogUtilityUsageSheetState extends State<_LogUtilityUsageSheet> {
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  String get _unitLabel {
    switch (widget.tracker.type) {
      case UtilityType.cookingGas:
        return 'kg';
      case UtilityType.electricity:
        return widget.tracker.isPostpaid ? 'kWh' : 'units';
      case UtilityType.water:
        return widget.tracker.containerSizeLitres != null
            ? 'containers'
            : 'litres';
      case UtilityType.waterBill:
        return 'm³';
      default:
        return 'units';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qtyText = _qtyCtrl.text.trim();
    if (qtyText.isEmpty) return;
    final qty = double.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a valid amount greater than zero.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<UtilityProvider>().logUtilityUsage(
            widget.tracker.id,
            qty,
            widget.householdId,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to log usage. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentLogs = widget.tracker.usageLogs.reversed.take(5).toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Log amount used',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          Text(
            widget.tracker.label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount used',
              suffixText: _unitLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
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
                  : const Text(
                      'Save entry',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          if (recentLogs.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Recent entries',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...recentLogs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      '${_fmtDate(log.date)}: ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${log.quantity % 1 == 0 ? log.quantity.toInt() : log.quantity} $_unitLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (log.notes != null && log.notes!.isNotEmpty) ...[
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          log.notes!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${d.day}/${d.month}/${d.year}';
  }
}

