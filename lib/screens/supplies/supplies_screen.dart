import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/supply_item.dart';
import '../../models/shopping_request.dart';
import '../../models/utility_tracker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/supply_provider.dart';
import '../../providers/utility_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_constants.dart';
import '../../utils/smart_tips_engine.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/smart_tips_section.dart';
import '../../widgets/status_chips.dart';
import '../dashboard/home_pro_analytics_screen.dart';
import '../utilities/utilities_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

class SuppliesScreen extends StatefulWidget {
  const SuppliesScreen({super.key});

  @override
  State<SuppliesScreen> createState() => _SuppliesScreenState();
}

class _SuppliesScreenState extends State<SuppliesScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Categories that have their own dedicated tab — exclude from the
  // Supplies tab filter chips to avoid duplication.
  static const _utilityCategories = {
    'Cooking Gas',
    'Drinking Water',
    'Electricity',
    'Internet',
    'Metered Water',
    'Service Charge',
    'Rent',
    'Pay TV',
  };

  List<String> get _categories {
    final auth = context.read<AuthProvider>();
    final cats = context
        .read<SupplyProvider>()
        .visibleSupplies(isOwner: auth.isOwner)
        .map((s) => s.category)
        .where((c) => !_utilityCategories.contains(c))
        .toSet()
        .toList();
    cats.sort();
    return ['All', ...cats];
  }

  /// Returns utility tracker items that match the current search query.
  List<UtilityTracker> get _utilitySearchResults {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return [];
    final auth = context.read<AuthProvider>();
    final utilProv = context.read<UtilityProvider>();
    return utilProv.visibleItems(isOwner: auth.isOwner).where((u) {
      return u.label.toLowerCase().contains(q) ||
          u.type.name.toLowerCase().contains(q) ||
          _utilityTypeName(u.type).toLowerCase().contains(q) ||
          (u.ispName?.toLowerCase().contains(q) ?? false) ||
          (u.payTvProvider?.toLowerCase().contains(q) ?? false) ||
          (u.rentLandlordName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Maps a UtilityType to its tab index in the TabController.
  // (Retained so UtilitiesScreen embedded sections still compile.
  //  SuppliesScreen no longer uses tabs — see UtilitiesScreen.)

  /// Human-readable tab name for a utility type.
  String _utilityTypeName(UtilityType type) {
    switch (type) {
      case UtilityType.cookingGas: return 'Cooking Gas';
      case UtilityType.water: return 'Drinking Water';
      case UtilityType.electricity: return 'Electricity';
      case UtilityType.internet: return 'Internet';
      case UtilityType.waterBill: return 'Metered Water';
      case UtilityType.serviceCharge: return 'Service Charge';
      case UtilityType.rent: return 'Rent';
      case UtilityType.payTv: return 'Pay TV';
      default: return 'Other';
    }
  }

  /// Icon for a utility type (used in search results).
  IconData _utilityTypeIcon(UtilityType type) {
    switch (type) {
      case UtilityType.cookingGas: return Icons.local_fire_department_outlined;
      case UtilityType.water: return Icons.water_drop_outlined;
      case UtilityType.electricity: return Icons.bolt_outlined;
      case UtilityType.internet: return Icons.wifi_outlined;
      case UtilityType.waterBill: return Icons.water_outlined;
      case UtilityType.serviceCharge: return Icons.apartment_outlined;
      case UtilityType.rent: return Icons.home_outlined;
      case UtilityType.payTv: return Icons.tv_outlined;
      default: return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final supply = context.watch<SupplyProvider>();
    final auth = context.watch<AuthProvider>();
    context.watch<UtilityProvider>(); // rebuild on utility changes for search

    final filtered = _selectedCategory == 'All'
        ? supply.visibleSupplies(isOwner: auth.isOwner)
        : supply.visibleSupplies(isOwner: auth.isOwner)
            .where((s) => s.category == _selectedCategory)
            .toList();

  final searched = _searchQuery.trim().isEmpty
    ? filtered
    : filtered.where((s) {
      final q = _searchQuery.trim().toLowerCase();
      return s.name.toLowerCase().contains(q) ||
        s.category.toLowerCase().contains(q) ||
        s.unitType.toLowerCase().contains(q);
      }).toList();

  searched.sort((a, b) {
      final aScore = _statusScore(a.status);
      final bScore = _statusScore(b.status);
      return bScore.compareTo(aScore);
    });

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Supplies'),
      ),
      floatingActionButton: (auth.isOwner && _tabController.index == 0)
          ? FloatingActionButton.extended(
              heroTag: 'supplies_fab',
              backgroundColor: AppColors.primaryTeal,
              onPressed: () => _showAddSupplySheet(context),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Add Supply',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
      body: Column(
        children: [
          // ── Pill segment switcher ─────────────────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      _buildPillTab(
                        icon: Icons.inventory_2_outlined,
                        label: 'Supplies',
                        selected: _tabController.index == 0,
                        onTap: () => _tabController.animateTo(0),
                      ),
                      _buildPillTab(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Utilities',
                        selected: _tabController.index == 1,
                        onTap: () => _tabController.animateTo(1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
          // ── Tab 0: Supplies ───────────────────────────────────
          Column(
            children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search supplies and utilities…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Container(
            color: AppColors.white,
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              primary: false,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
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
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: supply.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_utilitySearchResults.isEmpty && searched.isEmpty)
                    ? const EmptyStateWidget(
                        icon: Icons.inventory_2_outlined,
                        title: 'No matching supplies',
                        subtitle:
                            'Try a different name, category, or unit type',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // ── Analytics summary strip ─────────────
                          _SuppliesAnalyticsSummary(
                            supply: supply,
                            isOwner: auth.isOwner,
                            isPro: auth.isHomePro,
                          ),
                          const SizedBox(height: 12),
                          // ── Utility search results ─────────────
                          if (_utilitySearchResults.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.flash_on_outlined,
                                      size: 14, color: AppColors.primaryTeal),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Utilities',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryTeal,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(child: Divider(height: 1)),
                                ],
                              ),
                            ),
                            ..._utilitySearchResults.map((u) => _UtilitySearchResultTile(
                              item: u,
                              tabName: _utilityTypeName(u.type),
                              icon: _utilityTypeIcon(u.type),
                              onTap: () => _tabController.animateTo(1),
                            )),
                            if (searched.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.inventory_2_outlined,
                                        size: 14, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Supplies',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Divider(height: 1)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          // ── Regular supply results ─────────────
                          ...searched.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _SupplyCard(
                                  item: s,
                                  isOwner: auth.isOwner,
                                ),
                              )),
                          const SizedBox(height: 80),
                        ],
                      ),
          ),
            ],
          ),
          // ── Tab 1: Utilities ──────────────────────────────────
          const UtilitiesBody(),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildPillTab({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _statusScore(SupplyStatus s) {
    switch (s) {
      case SupplyStatus.finished:
        return 4;
      case SupplyStatus.veryLow:
        return 3;
      case SupplyStatus.runningLow:
        return 2;
      case SupplyStatus.enough:
        return 1;
    }
  }

  void _showAddSupplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddSupplySheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Compact analytics summary – sits at the top of the supply list
// ─────────────────────────────────────────────────────────────────
class _SuppliesAnalyticsSummary extends StatelessWidget {
  final SupplyProvider supply;
  final bool isOwner;
  final bool isPro;

  const _SuppliesAnalyticsSummary({
    required this.supply,
    required this.isOwner,
    required this.isPro,
  });

  @override
  Widget build(BuildContext context) {
    final items = supply.visibleSupplies(isOwner: isOwner);
    final tracked = items.length;
    final needAction = items.where((i) => i.needsAttention).length;
    final finished =
        items.where((i) => i.status == SupplyStatus.finished).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isPro) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SuppliesAnalyticsScreen(),
              ),
            );
          } else {
            openHomeProUpgrade(context, source: 'supplies_summary_strip');
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primaryTeal.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.query_stats_rounded,
                size: 16,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(width: 10),
              _SummaryChip(
                value: '$tracked',
                label: 'tracked',
                color: AppColors.primaryTeal,
              ),
              const SizedBox(width: 14),
              _SummaryChip(
                value: '$needAction',
                label: 'need action',
                color: needAction > 0
                    ? AppColors.accentOrange
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              _SummaryChip(
                value: '$finished',
                label: 'finished',
                color: finished > 0
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
    );
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
// Clean upsell view for analytics screens (replaces big PlanUpsellCard)
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

// ════════════════════════════════════════════════════════════════
// USAGE TRENDS CARD (Pro-gated)
// ════════════════════════════════════════════════════════════════

class _UsageTrendsCard extends StatelessWidget {
  final List<SupplyItem> supplies;

  const _UsageTrendsCard({required this.supplies});

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final usageTotals = <String, double>{};
    final usageItemNames = <String, String>{};
    int totalEntriesLast30 = 0;
    double totalUnitsLast30 = 0;

    for (final item in supplies) {
      double total = 0;
      for (final log in item.usageLogs) {
        if (log.date.isAfter(cutoff)) {
          total += log.quantity;
          totalUnitsLast30 += log.quantity;
          totalEntriesLast30++;
        }
      }
      if (total > 0) {
        usageTotals[item.id] = total;
        usageItemNames[item.id] = item.name;
      }
    }

    final topItems = usageTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Usage Trends',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Last 30 days',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Consumption logged by your household — tap any supply card to add an entry.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (topItems.isEmpty)
            const Text(
              'No usage has been logged in the last 30 days. Tap "Log amount used" on any supply to start tracking.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _FlowStatRow(
                    label: 'Entries logged',
                    value: '$totalEntriesLast30',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FlowStatRow(
                    label: 'Unique items',
                    value: '${topItems.length}',
                    highlight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Top consumed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...topItems.take(5).map((entry) {
              final name = usageItemNames[entry.key] ?? entry.key;
              final supply = supplies.firstWhere(
                (s) => s.id == entry.key,
                orElse: () => supplies.first,
              );
              final displayQty = entry.value % 1 == 0
                  ? entry.value.toInt().toString()
                  : entry.value.toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$displayQty ${supply.unitType}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryTeal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ANALYTICS PANEL
// ════════════════════════════════════════════════════════════════

class _SuppliesAnalyticsPanel extends StatelessWidget {
  final SupplyProvider supply;
  final bool isOwner;

  const _SuppliesAnalyticsPanel({
    required this.supply,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSupplies = supply.visibleSupplies(isOwner: isOwner);
    final trackedCount = visibleSupplies.length;
    final attentionItems = visibleSupplies.where((item) => item.needsAttention);
    final attentionCount = attentionItems.length;
    final finishedCount = visibleSupplies
        .where((item) => item.status == SupplyStatus.finished)
        .length;
    final gasRefillRisk = visibleSupplies.where((item) => item.isGasLowAlert).length;

    final categoryCounts = <String, int>{};
    final categoryAttentionCounts = <String, int>{};
    for (final item in visibleSupplies) {
      categoryCounts.update(item.category, (value) => value + 1, ifAbsent: () => 1);
      if (item.needsAttention || item.isGasLowAlert) {
        categoryAttentionCounts.update(
          item.category,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) {
        final aAttention = categoryAttentionCounts[a.key] ?? 0;
        final bAttention = categoryAttentionCounts[b.key] ?? 0;
        if (aAttention != bAttention) {
          return bAttention.compareTo(aAttention);
        }
        return b.value.compareTo(a.value);
      });

    final requestCategoryCounts = <String, int>{};
    for (final request in supply.shoppingRequests) {
      requestCategoryCounts.update(
        request.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final topRequestCategories = requestCategoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final priorityItems = visibleSupplies.where((item) {
      return item.needsAttention || item.isGasLowAlert;
    }).toList()
      ..sort((a, b) => _priorityScore(b).compareTo(_priorityScore(a)));

    final meal = context.watch<MealProvider>();
    final supplyTips = [
      ...SmartTipsEngine.analyzeSupplies(visibleSupplies),
      ...SmartTipsEngine.analyzeMeals(meal.mealLogs),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Supplies Analytics'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AnalyticsMetricCard(
                label: 'Tracked',
                value: '$trackedCount',
                icon: Icons.inventory_2_outlined,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AnalyticsMetricCard(
                label: 'Need Action',
                value: '$attentionCount',
                icon: Icons.warning_amber_rounded,
                color: AppColors.accentOrange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AnalyticsMetricCard(
                label: 'Finished',
                value: '$finishedCount',
                icon: Icons.remove_shopping_cart_outlined,
                color: AppColors.statusVeryLowText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AnalyticsMetricCard(
                label: 'Gas Risk',
                value: '$gasRefillRisk',
                icon: Icons.local_fire_department_outlined,
                color: AppColors.statusLowText,
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
                'Category Pressure',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Which supply categories are carrying the most restocking pressure right now.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              if (sortedCategories.isEmpty)
                const Text(
                  'Add your first supply items to start seeing category-level analytics.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                )
              else
                ...sortedCategories.take(4).map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AnalyticsCategoryRow(
                      label: entry.key,
                      totalCount: entry.value,
                      alertCount: categoryAttentionCounts[entry.key] ?? 0,
                      maxCount: sortedCategories.first.value,
                    ),
                  ),
                ),
            ],
          ),
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
                      'Shopping Flow',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FlowStatRow(
                      label: 'Pending approval',
                      value: '${supply.pendingRequests.length}',
                    ),
                    _FlowStatRow(
                      label: 'Approved to buy',
                      value: '${supply.approvedRequests.length}',
                    ),
                    _FlowStatRow(
                      label: 'Deferred',
                      value: '${supply.deferredRequests.length}',
                    ),
                    _FlowStatRow(
                      label: 'History logged',
                      value: '${supply.historyRequests.length}',
                      highlight: true,
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
                      'Repeat Demand',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (topRequestCategories.isEmpty)
                      const Text(
                        'Shopping requests will reveal your busiest categories here.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      ...topRequestCategories.take(3).map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RankedInsightRow(
                            label: entry.key,
                            detail: '${entry.value} request${entry.value == 1 ? '' : 's'} logged',
                          ),
                        ),
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
                'Priority This Week',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                priorityItems.isEmpty
                    ? 'No immediate supply pressure. Everything currently looks stable.'
                    : 'Items most likely to need attention first based on status and refill risk.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              if (priorityItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...priorityItems.take(4).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PrioritySupplyRow(item: item),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (supplyTips.isNotEmpty) ...[
          const SizedBox(height: 16),
          SmartTipsSection(
            tips: supplyTips,
            title: 'Smart Insights',
          ),
        ],
        const SizedBox(height: 16),
        _UsageTrendsCard(supplies: visibleSupplies),
      ],
    );
  }

  int _priorityScore(SupplyItem item) {
    if (item.status == SupplyStatus.finished) return 100;
    if (item.status == SupplyStatus.veryLow) return 80;
    if (item.isGasLowAlert) return 70;
    if (item.status == SupplyStatus.runningLow) return 60;
    return 0;
  }
}

class SuppliesAnalyticsScreen extends StatelessWidget {
  const SuppliesAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final supply = context.watch<SupplyProvider>();

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Supplies Analytics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (auth.isHomePro)
            ...[
              PremiumAnalyticsEntryCard(
                title: 'Home Pro Intelligence',
                subtitle:
                    'See whether supplies are protecting the week or quietly creating pressure across the whole household.',
                icon: Icons.auto_awesome_mosaic_rounded,
                highlights: const [
                  'Pressure map',
                  'Restock watchpoints',
                  'Cross-home recommendations',
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
              _SuppliesAnalyticsPanel(
                supply: supply,
                isOwner: auth.isOwner,
              ),
            ]
          else
            _AnalyticsUpsellView(
              icon: Icons.inventory_2_outlined,
              title: 'Supplies Analytics',
              features: const [
                'Stock health overview',
                'Category pressure tracking',
                'Shopping flow insights',
                'Priority items forecast',
              ],
              onUpgrade: () => openHomeProUpgrade(
                context,
                source: 'supplies_analytics_screen',
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AnalyticsMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsMetricCard({
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
              fontSize: 20,
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

class _AnalyticsCategoryRow extends StatelessWidget {
  final String label;
  final int totalCount;
  final int alertCount;
  final int maxCount;

  const _AnalyticsCategoryRow({
    required this.label,
    required this.totalCount,
    required this.alertCount,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final fill = maxCount == 0 ? 0.0 : totalCount / maxCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$totalCount tracked',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (alertCount > 0) ...[
              const SizedBox(width: 8),
              Text(
                '$alertCount alert${alertCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentOrange,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fill,
            minHeight: 8,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(
              alertCount > 0 ? AppColors.accentOrange : AppColors.primaryTeal,
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowStatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _FlowStatRow({
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

class _RankedInsightRow extends StatelessWidget {
  final String label;
  final String detail;

  const _RankedInsightRow({required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: AppColors.primaryTeal,
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

class _PrioritySupplyRow extends StatelessWidget {
  final SupplyItem item;

  const _PrioritySupplyRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final subtitle = item.isGasLowAlert
        ? 'Gas refill forecast says reorder soon'
        : item.category;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.statusVeryLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isGas ? Icons.local_fire_department_outlined : Icons.inventory_2_outlined,
              size: 16,
              color: item.isGas ? AppColors.statusLowText : AppColors.accentOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          StatusChip.fromSupplyStatus(item.status),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// COOKING GAS TAB
// ═══════════════════════════════════════════════════════════════════════

class GasTabSection extends StatelessWidget {
  final bool embedded;
  const GasTabSection({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();

    // Find the primary gas tracker
    final gasItems = utilProv.gasItems;
    final gas = gasItems.isNotEmpty ? gasItems.first : null;

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        if (gas == null) ...[
          _GasSetupCard(
            onSetup: () => _showSetupSheet(context, null, auth),
            isOwner: auth.isOwner || auth.isHouseManager,
          ),
        ] else if (!gas.gasSetupDone) ...[
          _GasSetupCard(
            onSetup: () => _showSetupSheet(context, gas, auth),
            isOwner: auth.isOwner || auth.isHouseManager,
          ),
        ] else ...[
          _GasStatusCard(gas: gas, auth: auth),
          const SizedBox(height: 16),
          _GasActionsRow(gas: gas, auth: auth),
          const SizedBox(height: 20),
          _GasTimelineCard(gas: gas),
          const SizedBox(height: 20),
          _GasSuppliersCard(gas: gas, auth: auth),
        ],
      ],
    );
  }

  void _showSetupSheet(
      BuildContext context, UtilityTracker? existing, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GasSetupSheet(existing: existing),
    );
  }
}

class DrinkingWaterTabSection extends StatelessWidget {
  final bool embedded;
  const DrinkingWaterTabSection({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();
    final waterItems =
        utilProv.waterItems.where((i) => i.isDrinkingWater).toList();
    final water = waterItems.isNotEmpty ? waterItems.first : null;
    final canManage = auth.isOwner || auth.isHouseManager;

    // ── No tracker at all ─────────────────────────────────────────
    if (water == null) {
      return ListView(
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _WaterSetupCard(
            onSetup: canManage
                ? () => _showSetupSheet(context, null, auth)
                : null,
            isOwner: canManage,
          ),
        ],
      );
    }

    // ── Tracker exists but not configured yet ─────────────────────
    if (!water.waterSetupDone) {
      return ListView(
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          _WaterSetupCard(
            onSetup: canManage
                ? () => _showSetupSheet(context, water, auth)
                : null,
            isOwner: canManage,
          ),
        ],
      );
    }

    // ── Fully configured ─────────────────────────────────────────
    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        _WaterStatusCard(water: water, auth: auth),
        const SizedBox(height: 16),
        _WaterActionsRow(water: water, auth: auth),
        const SizedBox(height: 20),
        _WaterSupplierCard(water: water, auth: auth),
      ],
    );
  }

  void _showSetupSheet(
      BuildContext context, UtilityTracker? existing, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WaterSetupSheet(existing: existing),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ELECTRICITY TAB
// ═══════════════════════════════════════════════════════════════════════

class ElectricityTabSection extends StatelessWidget {
  final bool embedded;
  const ElectricityTabSection({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();
    final elecItems = utilProv.electricityItems;
    final elec = elecItems.isNotEmpty ? elecItems.first : null;
    final canManage = auth.isOwner || auth.isHouseManager;

    if (elec == null) {
      return ListView(
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [_ElecSetupPrompt(item: null, canManage: canManage)],
      );
    }

    if (!elec.electricitySetupDone) {
      return ListView(
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [_ElecSetupPrompt(item: elec, canManage: canManage)],
      );
    }

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        if (elec.isPostpaid)
          _ElecPostpaidCard(elec: elec, canManage: canManage)
        else
          _ElecPrepaidCard(elec: elec, canManage: canManage),
      ],
    );
  }
}

// ── Electricity: setup prompt ─────────────────────────────────────────

class _ElecSetupPrompt extends StatelessWidget {
  final UtilityTracker? item;
  final bool canManage;
  const _ElecSetupPrompt({required this.item, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentYellow.withValues(alpha: 0.25),
            AppColors.accentYellow.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentYellow.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentYellow.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_outlined,
                    color: AppColors.statusLowText, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Electricity',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Token or monthly bill tracking',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Track prepaid token balance and get low-balance alerts, or get monthly bill reminders for postpaid connections.',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.bolt_outlined,
                    color: Colors.white, size: 18),
                label: const Text('Set Up Electricity',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                onPressed: () => _showSetupSheet(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSetupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ElecSetupSheet(item: item),
    );
  }
}

// ── Electricity: prepaid status card ─────────────────────────────────

class _ElecPrepaidCard extends StatelessWidget {
  final UtilityTracker elec;
  final bool canManage;
  const _ElecPrepaidCard({required this.elec, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final units = elec.unitsRemaining ?? 0;
    final isAlert = elec.isLowAlert;
    final lowAlertSent = elec.electricityLowAlertSent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Status header card ─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAlert
                  ? [
                      AppColors.statusVeryLow,
                      AppColors.statusVeryLow.withValues(alpha: 0.4),
                    ]
                  : [
                      AppColors.accentYellow.withValues(alpha: 0.18),
                      AppColors.accentYellow.withValues(alpha: 0.04),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAlert
                  ? AppColors.accentOrange.withValues(alpha: 0.4)
                  : AppColors.accentYellow.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isAlert
                          ? AppColors.statusVeryLow
                          : AppColors.accentYellow.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.bolt_outlined,
                        color: isAlert
                            ? AppColors.accentOrange
                            : AppColors.statusLowText,
                        size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(elec.label,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const Text('Prepaid Tokens',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isAlert
                          ? AppColors.statusVeryLow
                          : AppColors.statusEnough,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isAlert ? 'Running Low' : 'OK',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAlert
                              ? AppColors.statusVeryLowText
                              : AppColors.statusEnoughText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Low alert banner
              if (lowAlertSent) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.statusVeryLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.accentOrange.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.accentOrange, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Manager has flagged tokens as running low — top up now!',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.accentOrange,
                              fontWeight: FontWeight.w600,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Big units display
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    units.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: isAlert
                          ? AppColors.accentOrange
                          : AppColors.statusLowText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('kWh',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isAlert
                                ? AppColors.accentOrange
                                : AppColors.textSecondary)),
                  ),
                ],
              ),

              // Meta chips
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (elec.lastToppedUpAt != null)
                    _InfoChip(
                      icon: Icons.history_outlined,
                      label:
                          'Topped up ${_supplyDaysAgo(elec.lastToppedUpAt!)}',
                    ),
                  if (elec.typicalTokenAmount != null)
                    _InfoChip(
                      icon: Icons.payments_outlined,
                      label:
                          'Usual top-up KSh ${elec.typicalTokenAmount!.toStringAsFixed(0)}',
                    ),
                  if (elec.electricityPaybill != null)
                    _InfoChip(
                      icon: Icons.phone_android_outlined,
                      label:
                          'Paybill ${elec.electricityPaybill}${elec.electricityAccountRef != null ? ' · ${elec.electricityAccountRef}' : ''}',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Actions ────────────────────────────────────────────
        if (canManage) ...[
          Row(
            children: [
              if (!lowAlertSent)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentOrange,
                      side: const BorderSide(color: AppColors.accentOrange),
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: const Text('Alert: Low Tokens',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final auth = context.read<AuthProvider>();
                      await context
                          .read<UtilityProvider>()
                          .alertElectricityLow(elec.id, auth.household!.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Low token alert recorded'),
                            backgroundColor: AppColors.accentOrange,
                          ),
                        );
                      }
                    },
                  ),
                ),
              if (!lowAlertSent) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bolt_outlined,
                      size: 16, color: Colors.white),
                  label: const Text('Mark Refilled',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  onPressed: () => _showRefilledSheet(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Edit Setup',
                style: TextStyle(fontSize: 13)),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _ElecSetupSheet(item: elec),
            ),
          ),
        ],
      ],
    );
  }

  void _showRefilledSheet(BuildContext context) {
    final ctrl = TextEditingController(
        text: elec.typicalTokenAmount?.toStringAsFixed(0) ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Token Top-Up',
                    style: Theme.of(ctx).textTheme.titleMedium),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Text('Enter the new token balance after purchase.',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New balance (kWh)',
                suffixText: 'kWh',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(ctrl.text.trim());
                  if (val == null || val < 0) return;
                  final auth = ctx.read<AuthProvider>();
                  ctx.read<UtilityProvider>().markTokensRefilled(
                      elec.id, auth.household!.id, val);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Tokens updated to ${val.toStringAsFixed(0)} kWh'),
                      backgroundColor: AppColors.primaryTeal,
                    ),
                  );
                },
                child: const Text('Confirm Top-Up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Electricity: postpaid status card ────────────────────────────────

class _ElecPostpaidCard extends StatelessWidget {
  final UtilityTracker elec;
  final bool canManage;
  const _ElecPostpaidCard({required this.elec, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final isAlert = elec.isLowAlert;
    final status = elec.electricityPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final isPaid = status == UtilityPaymentStatus.paid;
    final days = elec.electricityDaysUntilDue;
    final hasBill = elec.lastBillAmount != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAlert && !isPaid
                  ? [
                      AppColors.statusVeryLow,
                      AppColors.statusVeryLow.withValues(alpha: 0.4),
                    ]
                  : isPaid
                      ? [
                          AppColors.statusEnough,
                          AppColors.statusEnough.withValues(alpha: 0.4),
                        ]
                      : [
                          AppColors.accentYellow.withValues(alpha: 0.18),
                          AppColors.accentYellow.withValues(alpha: 0.04),
                        ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAlert && !isPaid
                  ? AppColors.accentOrange.withValues(alpha: 0.4)
                  : isPaid
                      ? AppColors.secondaryTeal.withValues(alpha: 0.4)
                      : AppColors.accentYellow.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentYellow.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: AppColors.statusLowText, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(elec.label,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const Text('Postpaid (Monthly Bill)',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? AppColors.statusEnough
                          : isAlert
                              ? AppColors.statusVeryLow
                              : AppColors.statusLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPaid
                          ? 'Paid ✓'
                          : isAlert
                              ? 'Due Soon'
                              : 'Pending',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? AppColors.statusEnoughText
                              : isAlert
                                  ? AppColors.statusVeryLowText
                                  : AppColors.statusLowText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Bill amount',
                      value: hasBill
                          ? 'KSh ${elec.lastBillAmount!.toStringAsFixed(0)}'
                          : '—',
                      highlight: !isPaid && hasBill,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Due day',
                      value: elec.electricityBillDueDayOfMonth != null
                          ? _supplyOrdinal(elec.electricityBillDueDayOfMonth!)
                          : '—',
                      highlight: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Days left',
                      value: days != null ? '$days' : '—',
                      highlight: isAlert && !isPaid,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                elec.electricityStatusMessage,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isAlert && !isPaid
                      ? AppColors.accentOrange
                      : isPaid
                          ? AppColors.statusEnoughText
                          : AppColors.textSecondary,
                  fontWeight: isAlert || isPaid
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),

              if (elec.electricityPaybill != null) ...[
                const SizedBox(height: 10),
                _InfoChip(
                  icon: Icons.phone_android_outlined,
                  label:
                      'Paybill ${elec.electricityPaybill}${elec.electricityAccountRef != null ? ' · ${elec.electricityAccountRef}' : ''}',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (canManage) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.receipt_outlined, size: 16),
                  label: const Text('Record Bill',
                      style: TextStyle(fontSize: 13)),
                  onPressed: () => _showRecordBillSheet(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isPaid ? AppColors.textHint : AppColors.accentOrange,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(
                    isPaid
                        ? Icons.check_circle_outline
                        : Icons.payments_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isPaid ? 'Paid ✓' : 'Mark Paid',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  onPressed: isPaid
                      ? null
                      : () async {
                          final auth = context.read<AuthProvider>();
                          await context
                              .read<UtilityProvider>()
                              .markElectricityBillPaid(
                                  elec.id, auth.household!.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Electricity bill marked as paid'),
                                backgroundColor: AppColors.primaryTeal,
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Edit Setup', style: TextStyle(fontSize: 13)),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _ElecSetupSheet(item: elec),
            ),
          ),
        ],
      ],
    );
  }

  void _showRecordBillSheet(BuildContext context) {
    final ctrl = TextEditingController(
        text: elec.lastBillAmount?.toStringAsFixed(0) ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Record Electricity Bill',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Text(
              'Enter the current monthly bill amount before marking it paid.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bill amount',
                prefixText: 'KSh ',
                hintText: 'e.g. 3500',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final value = double.tryParse(ctrl.text.trim());
                  if (value == null || value < 0) {
                    return;
                  }
                  final auth = ctx.read<AuthProvider>();
                  await ctx.read<UtilityProvider>().recordElectricityBill(
                        elec.id,
                        auth.household!.id,
                        value,
                      );
                  if (!ctx.mounted) {
                    return;
                  }
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Electricity bill recorded at KSh ${value.toStringAsFixed(0)}',
                      ),
                      backgroundColor: AppColors.primaryTeal,
                    ),
                  );
                },
                child: const Text('Save Bill Amount'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Electricity setup sheet ───────────────────────────────────────────

class _ElecSetupSheet extends StatefulWidget {
  final UtilityTracker? item;
  const _ElecSetupSheet({required this.item});

  @override
  State<_ElecSetupSheet> createState() => _ElecSetupSheetState();
}

class _ElecSetupSheetState extends State<_ElecSetupSheet> {
  bool _isPostpaid = false;
  final _unitsCtrl = TextEditingController();
  final _typicalAmtCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController();
  final _paybillCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    if (i != null) {
      _isPostpaid = i.isPostpaid;
      _unitsCtrl.text = i.unitsRemaining?.toStringAsFixed(0) ?? '';
      _typicalAmtCtrl.text = i.typicalTokenAmount?.toStringAsFixed(0) ?? '';
      _dueDayCtrl.text = i.electricityBillDueDayOfMonth?.toString() ?? '';
      _paybillCtrl.text = i.electricityPaybill ?? '';
      _accountCtrl.text = i.electricityAccountRef ?? '';
    }
  }

  @override
  void dispose() {
    _unitsCtrl.dispose();
    _typicalAmtCtrl.dispose();
    _dueDayCtrl.dispose();
    _paybillCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Electricity Setup',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Meter type',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Prepaid Tokens',
                    icon: Icons.bolt_outlined,
                    selected: !_isPostpaid,
                    onTap: () => setState(() => _isPostpaid = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleChip(
                    label: 'Postpaid Bill',
                    icon: Icons.receipt_long_outlined,
                    selected: _isPostpaid,
                    onTap: () => setState(() => _isPostpaid = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_isPostpaid) ...[
              TextFormField(
                controller: _unitsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Current token balance (kWh)',
                  suffixText: 'kWh',
                  hintText: 'e.g. 85',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _typicalAmtCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Typical top-up amount (KSh)',
                  prefixText: 'KSh ',
                  hintText: 'e.g. 1000',
                ),
              ),
            ] else ...[
              TextFormField(
                controller: _dueDayCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bill due day of month',
                  hintText: 'e.g. 20',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _paybillCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Paybill / Till number',
                hintText: 'e.g. 888880',
                helperText: 'KPLC Paybill: 888880',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountCtrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'Account / meter number',
                hintText: 'e.g. 123456789',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() async {
    final auth = context.read<AuthProvider>();
    final utilProv = context.read<UtilityProvider>();
    final householdId = auth.household!.id;

    String itemId;
    if (widget.item != null) {
      itemId = widget.item!.id;
    } else {
      // No existing tracker — create one now
      const uuid = Uuid();
      final newItem = UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.electricity,
        label: 'Main Electricity',
        electricitySetupDone: false,
        isPostpaid: false,
        updatedAt: DateTime.now(),
      );
      await utilProv.addItem(newItem, householdId);
      itemId = newItem.id;
    }

    utilProv.setupElectricity(
      itemId: itemId,
      householdId: householdId,
      isPostpaid: _isPostpaid,
      currentUnits:
          !_isPostpaid ? double.tryParse(_unitsCtrl.text.trim()) : null,
      typicalTokenAmount:
          !_isPostpaid ? double.tryParse(_typicalAmtCtrl.text.trim()) : null,
      billDueDayOfMonth:
          _isPostpaid ? int.tryParse(_dueDayCtrl.text.trim()) : null,
      electricityPaybill: _paybillCtrl.text.trim().isEmpty
          ? null
          : _paybillCtrl.text.trim(),
      electricityAccountRef: _accountCtrl.text.trim().isEmpty
          ? null
          : _accountCtrl.text.trim(),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Electricity set up'),
        backgroundColor: AppColors.primaryTeal,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// INTERNET TAB
// ═══════════════════════════════════════════════════════════════════════

class InternetTabSection extends StatelessWidget {
  final bool embedded;
  const InternetTabSection({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();
    final internetItems = utilProv.internetItems;
    final net = internetItems.isNotEmpty ? internetItems.first : null;
    final canManage = auth.isOwner || auth.isHouseManager;

    if (net == null || !net.internetSetupDone) {
      return ListView(
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [_NetSetupPrompt(item: net, canManage: canManage)],
      );
    }

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [_NetStatusCard(net: net, canManage: canManage)],
    );
  }
}

// ── Internet: setup prompt ────────────────────────────────────────────

class _NetSetupPrompt extends StatelessWidget {
  final UtilityTracker? item;
  final bool canManage;
  const _NetSetupPrompt({required this.item, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryTeal.withValues(alpha: 0.15),
            AppColors.secondaryTeal.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryTeal.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryTeal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi_outlined,
                    color: AppColors.primaryTeal, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Home Internet',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Monthly payment reminder',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Set your ISP, monthly due date and amount. Get a reminder when payment is approaching and track when it\'s been paid.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.wifi_outlined,
                    color: Colors.white, size: 18),
                label: const Text('Set Up Internet',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _NetSetupSheet(item: item),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Internet: status card ─────────────────────────────────────────────

class _NetStatusCard extends StatelessWidget {
  final UtilityTracker net;
  final bool canManage;
  const _NetStatusCard({required this.net, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final isAlert = net.isLowAlert;
    final status = net.internetPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final isPaid = status == UtilityPaymentStatus.paid;
    final days = net.internetDaysUntilDue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAlert && !isPaid
                  ? [
                      AppColors.statusVeryLow,
                      AppColors.statusVeryLow.withValues(alpha: 0.4),
                    ]
                  : isPaid
                      ? [
                          AppColors.statusEnough,
                          AppColors.statusEnough.withValues(alpha: 0.4),
                        ]
                      : [
                          AppColors.secondaryTeal.withValues(alpha: 0.12),
                          AppColors.secondaryTeal.withValues(alpha: 0.03),
                        ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAlert && !isPaid
                  ? AppColors.accentOrange.withValues(alpha: 0.4)
                  : isPaid
                      ? AppColors.secondaryTeal.withValues(alpha: 0.4)
                      : AppColors.primaryTeal.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.wifi_outlined,
                        color: AppColors.primaryTeal, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(net.label,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        if (net.ispName != null)
                          Text(net.ispName!,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? AppColors.statusEnough
                          : isAlert
                              ? AppColors.statusVeryLow
                              : AppColors.statusLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPaid
                          ? 'Paid ✓'
                          : isAlert
                              ? 'Due Soon'
                              : 'Pending',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isPaid
                              ? AppColors.statusEnoughText
                              : isAlert
                                  ? AppColors.statusVeryLowText
                                  : AppColors.statusLowText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats row
              Row(
                children: [
                  if (net.internetMonthlyAmount != null) ...[
                    Expanded(
                      child: _StatBox(
                        label: 'Monthly',
                        value:
                            'KSh ${net.internetMonthlyAmount!.toStringAsFixed(0)}',
                        highlight: !isPaid && isAlert,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _StatBox(
                      label: 'Due day',
                      value: net.internetDueDayOfMonth != null
                          ? _supplyOrdinal(net.internetDueDayOfMonth!)
                          : '—',
                      highlight: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Days left',
                      value: days != null ? '$days' : '—',
                      highlight: isAlert && !isPaid,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Text(
                net.internetStatusMessage,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: isAlert && !isPaid
                      ? AppColors.accentOrange
                      : isPaid
                          ? AppColors.statusEnoughText
                          : AppColors.textSecondary,
                  fontWeight:
                      isAlert || isPaid ? FontWeight.w600 : FontWeight.w400,
                ),
              ),

              if (net.internetMpesaTill != null) ...[
                const SizedBox(height: 10),
                _InfoChip(
                  icon: Icons.phone_android_outlined,
                  label:
                      '${net.internetIsPaybill ? 'Paybill' : 'Till'} ${net.internetMpesaTill}${net.internetMpesaAccountRef != null ? ' · ${net.internetMpesaAccountRef}' : ''}',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (canManage) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isPaid ? AppColors.textHint : AppColors.accentOrange,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(
                    isPaid
                        ? Icons.check_circle_outline
                        : Icons.payments_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isPaid ? 'Paid ✓' : 'Mark Paid',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  onPressed: isPaid
                      ? null
                      : () async {
                          final auth = context.read<AuthProvider>();
                          await context
                              .read<UtilityProvider>()
                              .markInternetPaid(net.id, auth.household!.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Internet payment marked as paid'),
                                backgroundColor: AppColors.primaryTeal,
                              ),
                            );
                          }
                        },
                ),
              ),
              if (isPaid) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.divider),
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.refresh_outlined, size: 16),
                    label: const Text('New Cycle',
                        style: TextStyle(fontSize: 13)),
                    onPressed: () async {
                      final auth = context.read<AuthProvider>();
                      await context
                          .read<UtilityProvider>()
                          .resetInternetPayment(net.id, auth.household!.id);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: const Text('Edit Setup', style: TextStyle(fontSize: 13)),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _NetSetupSheet(item: net),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Internet setup sheet ──────────────────────────────────────────────

class _NetSetupSheet extends StatefulWidget {
  final UtilityTracker? item;
  const _NetSetupSheet({required this.item});

  @override
  State<_NetSetupSheet> createState() => _NetSetupSheetState();
}

class _NetSetupSheetState extends State<_NetSetupSheet> {
  final _ispCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _tillCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  bool _isPaybill = false;

  static const _isps = [
    'Safaricom Home',
    'Zuku',
    'JTL Faiba',
    'Airtel Home',
    'Telkom',
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    if (i != null) {
      _ispCtrl.text = i.ispName ?? '';
      _dueDayCtrl.text = i.internetDueDayOfMonth?.toString() ?? '';
      _amountCtrl.text = i.internetMonthlyAmount?.toStringAsFixed(0) ?? '';
      _tillCtrl.text = i.internetMpesaTill ?? '';
      _accountCtrl.text = i.internetMpesaAccountRef ?? '';
      _isPaybill = i.internetIsPaybill;
    }
  }

  @override
  void dispose() {
    _ispCtrl.dispose();
    _dueDayCtrl.dispose();
    _amountCtrl.dispose();
    _tillCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Internet Setup',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Internet provider',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _isps.map((isp) {
                final selected = _ispCtrl.text == isp;
                return GestureDetector(
                  onTap: () => setState(() => _ispCtrl.text = isp),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
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
                              : AppColors.divider),
                    ),
                    child: Text(isp,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ispCtrl,
              decoration: const InputDecoration(
                labelText: 'Provider name',
                hintText: 'e.g. Safaricom Home',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dueDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Due day',
                      hintText: 'e.g. 5',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly (KSh)',
                      prefixText: 'KSh ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('M-Pesa payment',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Buy Goods',
                    icon: Icons.storefront_outlined,
                    selected: !_isPaybill,
                    onTap: () => setState(() => _isPaybill = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleChip(
                    label: 'Paybill',
                    icon: Icons.account_balance_outlined,
                    selected: _isPaybill,
                    onTap: () => setState(() => _isPaybill = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tillCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _isPaybill ? 'Paybill number' : 'Till number',
                hintText: 'e.g. 400200',
              ),
            ),
            if (_isPaybill) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Account reference',
                  hintText: 'e.g. your account number',
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final isp = _ispCtrl.text.trim();
    final dueDay = int.tryParse(_dueDayCtrl.text.trim());
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (isp.isEmpty || dueDay == null || amount == null) return;

    final auth = context.read<AuthProvider>();
    final utilProv = context.read<UtilityProvider>();
    final itemId = widget.item?.id;
    if (itemId == null) {
      Navigator.pop(context);
      return;
    }

    utilProv.setupInternet(
      itemId: itemId,
      householdId: auth.household!.id,
      ispName: isp,
      dueDayOfMonth: dueDay,
      monthlyAmount: amount,
      mpesaTill: _tillCtrl.text.trim().isEmpty ? null : _tillCtrl.text.trim(),
      isPaybill: _isPaybill,
      mpesaAccountRef: _accountCtrl.text.trim().isEmpty
          ? null
          : _accountCtrl.text.trim(),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$isp internet set up'),
        backgroundColor: AppColors.primaryTeal,
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _StatBox(
      {required this.label, required this.value, required this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.accentOrange.withValues(alpha: 0.08)
            : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: highlight
                      ? AppColors.accentOrange
                      : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTeal : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  selected ? AppColors.primaryTeal : AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color:
                    selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

String _supplyDaysAgo(DateTime d) {
  final diff = DateTime.now().difference(d).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'yesterday';
  return '$diff days ago';
}

String _supplyOrdinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  switch (n % 10) {
    case 1: return '${n}st';
    case 2: return '${n}nd';
    case 3: return '${n}rd';
    default: return '${n}th';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WATER SETUP PROMPT CARD
// ═══════════════════════════════════════════════════════════════════════

class _WaterSetupCard extends StatelessWidget {
  final VoidCallback? onSetup;
  final bool isOwner;

  const _WaterSetupCard({required this.onSetup, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryTeal.withValues(alpha: 0.08),
            AppColors.primaryTeal.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primaryTeal.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop_outlined,
                    color: AppColors.primaryTeal, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Drinking Water',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Not yet configured',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Set up your household water supply to track bottle levels, '
            'reorder automatically, and pay your Jibu or other supplier easily.',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              _SetupFeatureChip(label: 'Bottle tracking'),
              _SetupFeatureChip(label: 'Reorder alerts'),
              _SetupFeatureChip(label: 'Supplier contact'),
              _SetupFeatureChip(label: 'M-Pesa payment'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: onSetup,
              icon: const Icon(Icons.tune_outlined, size: 18),
              label: Text(
                isOwner ? 'Set Up Drinking Water' : 'View only — ask an owner to set up',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupFeatureChip extends StatelessWidget {
  final String label;
  const _SetupFeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryTeal)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WATER STATUS CARD
// ═══════════════════════════════════════════════════════════════════════

class _WaterStatusCard extends StatelessWidget {
  final UtilityTracker water;
  final AuthProvider auth;

  const _WaterStatusCard({required this.water, required this.auth});

  @override
  Widget build(BuildContext context) {
    final full = water.fullContainers ?? 0;
    final empty = water.emptyContainers ?? 0;
    final total = water.totalContainers ?? 0;
    final size = water.containerSizeLitres ?? 18.5;
    final isAlert = water.isLowAlert;
    final status = water.paymentStatus ?? UtilityPaymentStatus.unpaid;
    final canManage = auth.isOwner || auth.isHouseManager;

    final payColor = switch (status) {
      UtilityPaymentStatus.paid => AppColors.mpesaGreen,
      UtilityPaymentStatus.pending => AppColors.statusLowText,
      UtilityPaymentStatus.unpaid => AppColors.accentOrange,
    };
    final payBg = switch (status) {
      UtilityPaymentStatus.paid =>
        AppColors.mpesaGreen.withValues(alpha: 0.1),
      UtilityPaymentStatus.pending =>
        AppColors.statusLow,
      UtilityPaymentStatus.unpaid =>
        AppColors.statusVeryLow,
    };
    final payLabel = switch (status) {
      UtilityPaymentStatus.paid => '✓ Paid',
      UtilityPaymentStatus.pending => '⏳ Pending',
      UtilityPaymentStatus.unpaid => '! Unpaid',
    };

    return HomeFlowCard(
      borderColor: isAlert
          ? AppColors.accentOrange.withValues(alpha: 0.35)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop_outlined,
                    color: AppColors.primaryTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(water.label,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                      '$total bottle${total == 1 ? '' : 's'} · '
                      '${size.toStringAsFixed(size % 1 == 0 ? 0 : 1)}L each',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isAlert
                      ? AppColors.statusVeryLow
                      : AppColors.statusEnough,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isAlert ? '⚠ Refill soon' : '✓ Stable',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isAlert
                        ? AppColors.statusVeryLowText
                        : AppColors.statusEnoughText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Bottle stat row ───────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _WaterSupplyMiniStat(
                  label: 'Full',
                  value: '$full',
                  icon: Icons.water_drop,
                  iconColor: full > 0
                      ? AppColors.primaryTeal
                      : AppColors.textHint,
                  highlight: full > 0 && !isAlert,
                  alert: isAlert && full == 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WaterSupplyMiniStat(
                  label: 'Empty',
                  value: '$empty',
                  icon: Icons.water_drop_outlined,
                  iconColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WaterSupplyMiniStat(
                  label: 'Every',
                  value: '${water.reorderFrequencyDays ?? 14}d',
                  icon: Icons.calendar_today_outlined,
                  iconColor: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Status message ────────────────────────────────────
          Text(
            water.drinkingWaterStatusMessage,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isAlert
                  ? AppColors.accentOrange
                  : AppColors.textSecondary,
              fontWeight:
                  isAlert ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),

          // ── Info chips row ────────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (water.supplier1 != null)
                _WaterInfoChip(
                    icon: Icons.storefront_outlined,
                    label: water.supplier1!.name),
              if (water.pricePerContainer != null)
                _WaterInfoChip(
                  icon: Icons.payments_outlined,
                  label:
                      'KSh ${water.pricePerContainer!.toStringAsFixed(0)} / bottle',
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: payBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(payLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: payColor)),
              ),
            ],
          ),

          // ── Last delivery ─────────────────────────────────────
          if (water.lastDeliveredAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Last delivered: ${_fmtDate(water.lastDeliveredAt!)}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textHint),
            ),
          ],

          // ── Edit button (owner) ───────────────────────────────
          if (canManage) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _WaterSetupSheet(existing: water),
                ),
                icon:
                    const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit setup',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${m[d.month - 1]}';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WATER ACTIONS ROW
// ═══════════════════════════════════════════════════════════════════════

class _WaterActionsRow extends StatelessWidget {
  final UtilityTracker water;
  final AuthProvider auth;

  const _WaterActionsRow({required this.water, required this.auth});

  @override
  Widget build(BuildContext context) {
    final canManage = auth.isOwner || auth.isHouseManager;
    final full = water.fullContainers ?? 0;
    final status = water.paymentStatus ?? UtilityPaymentStatus.unpaid;

    if (!canManage) return const SizedBox.shrink();

    return Column(
      children: [
        // ── Primary: Order Water + Record Delivery ─────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryTeal,
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: AppColors.primaryTeal),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: water.supplier1 != null
                    ? () => _orderWater(context)
                    : null,
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Order Water',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => _confirmDelivery(context),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Delivered',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ── Secondary: Mark Empty + Pay Supplier ───────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: full > 0 ? () => _markEmpty(context) : null,
                icon: const Icon(Icons.local_drink_outlined, size: 16),
                label: const Text('Mark Empty',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: status != UtilityPaymentStatus.paid
                      ? AppColors.mpesaGreen
                      : AppColors.textHint,
                  minimumSize: const Size(0, 44),
                  side: BorderSide(
                    color: status != UtilityPaymentStatus.paid
                        ? AppColors.mpesaGreen
                        : AppColors.divider,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: status != UtilityPaymentStatus.paid
                    ? () => _markPaid(context)
                    : null,
                icon: const Icon(Icons.payments_outlined, size: 16),
                label: Text(
                  status == UtilityPaymentStatus.paid
                      ? 'Paid ✓'
                      : 'Pay Supplier',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _orderWater(BuildContext context) {
    final supplier = water.supplier1!;
    final qty = water.typicalOrderQuantity ?? 2;
    final size = water.containerSizeLitres ?? 18.5;
    final sizeFmt =
        size % 1 == 0 ? '${size.toInt()}L' : '${size}L';
    final msg =
        'Hi, please deliver $qty × $sizeFmt water bottle${qty == 1 ? '' : 's'}. '
        'Please confirm when ready. Thank you.';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _WaterOrderSheet(
        supplier: supplier,
        message: msg,
        water: water,
      ),
    );
  }

  void _confirmDelivery(BuildContext context) {
    final qty = water.typicalOrderQuantity ?? water.totalContainers ?? 2;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Record Delivery'),
        content: Text(
          'Record delivery of $qty bottle${qty == 1 ? '' : 's'}? '
          'This will reset your full-bottle count and mark payment as unpaid.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              minimumSize: const Size(0, 40),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<UtilityProvider>().recordDrinkingWaterDelivery(
                    itemId: water.id,
                    householdId: auth.household!.id,
                    quantityDelivered: qty,
                    paymentStatus: UtilityPaymentStatus.unpaid,
                  );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delivery recorded — remember to pay supplier'),
                  backgroundColor: AppColors.primaryTeal,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _markEmpty(BuildContext context) {
    context
        .read<UtilityProvider>()
        .markDrinkingWaterBottleEmpty(water.id, auth.household!.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('One bottle marked as empty'),
        backgroundColor: AppColors.primaryTeal,
      ),
    );
  }

  void _markPaid(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Mark as Paid'),
        content: Text(
          water.pricePerContainer != null && water.typicalOrderQuantity != null
              ? 'Mark KSh ${(water.pricePerContainer! * water.typicalOrderQuantity!).toStringAsFixed(0)} '
                'to ${water.supplier1?.name ?? 'supplier'} as paid?'
              : 'Mark water delivery payment as paid?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mpesaGreen,
              minimumSize: const Size(0, 40),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<UtilityProvider>()
                  .markDrinkingWaterPaid(water.id, auth.household!.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment marked as paid ✓'),
                  backgroundColor: AppColors.mpesaGreen,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WATER SUPPLIER CARD
// ═══════════════════════════════════════════════════════════════════════

class _WaterSupplierCard extends StatelessWidget {
  final UtilityTracker water;
  final AuthProvider auth;

  const _WaterSupplierCard({required this.water, required this.auth});

  @override
  Widget build(BuildContext context) {
    final canManage = auth.isOwner || auth.isHouseManager;
    final supplier = water.supplier1;

    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    size: 16, color: AppColors.primaryTeal),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water Supplier',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Call, WhatsApp or copy M-Pesa details',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (canManage)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTeal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _WaterSetupSheet(existing: water),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: Text(supplier != null ? 'Edit' : 'Add',
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Supplier tile or empty ─────────────────────────────
          if (supplier == null)
            const Text('No supplier added yet.',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary))
          else
            _WaterSupplierTile(supplier: supplier, water: water),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// WATER SUPPLIER TILE — call / WhatsApp / M-Pesa
// ─────────────────────────────────────────────────────────────────────

class _WaterSupplierTile extends StatelessWidget {
  final GasSupplier supplier;
  final UtilityTracker water;

  const _WaterSupplierTile(
      {required this.supplier, required this.water});

  String _orderMessage() {
    final qty = water.typicalOrderQuantity ?? 2;
    final size = water.containerSizeLitres ?? 18.5;
    final sizeFmt =
        size % 1 == 0 ? '${size.toInt()}L' : '${size}L';
    final addr = water.deliveryAddress?.trim();
    final addrStr = (addr != null && addr.isNotEmpty) ? ' to $addr' : '';
    return 'Hi! I\'d like to order $qty × $sizeFmt drinking water ${qty == 1 ? 'bottle' : 'bottles'}$addrStr. '
        'Kindly confirm when you can deliver and let me know the total cost. Thank you! 🙏';
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: supplier.phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _whatsapp(BuildContext context) async {
    final phone =
        supplier.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final intlPhone = phone.startsWith('07')
        ? '254${phone.substring(1)}'
        : phone.startsWith('0')
            ? '254${phone.substring(1)}'
            : phone;
    final msg = Uri.encodeComponent(_orderMessage());
    final waUri = Uri.parse('https://wa.me/$intlPhone?text=$msg');
    if (await canLaunchUrl(waUri)) {
      launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: _orderMessage()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Message copied — WhatsApp not available'),
              backgroundColor: AppColors.primaryTeal),
        );
      }
    }
  }

  Future<void> _sms(BuildContext context) async {
    final uri = Uri(
        scheme: 'sms',
        path: supplier.phone,
        queryParameters: {'body': _orderMessage()});
    if (await canLaunchUrl(uri)) {
      launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: _orderMessage()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Message copied to clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMpesa =
        supplier.mpesaTill != null && supplier.mpesaTill!.isNotEmpty;
    final accountRef = supplier.isPaybill && supplier.mpesaAccountRef != null
        ? ' Acc: ${supplier.mpesaAccountRef}'
        : '';
    final paymentText = '${supplier.mpesaName ?? supplier.name} — '
        '${supplier.isPaybill ? 'Paybill' : 'Buy Goods'} '
        '${supplier.mpesaTill ?? ''}$accountRef';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusEnough,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.primaryTeal.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name/phone ───────────────────────────────
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTeal
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primaryTeal
                                    .withValues(alpha: 0.18)),
                          ),
                          child: const Text('Primary',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryTeal)),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            supplier.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(supplier.phone,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Action buttons ────────────────────────────────────
          Row(
            children: [
              _ActionButton(
                icon: Icons.call_outlined,
                label: 'Call',
                color: AppColors.mpesaGreen,
                onTap: _call,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                color: AppColors.whatsappGreen,
                onTap: () => _whatsapp(context),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.sms_outlined,
                label: 'SMS',
                color: AppColors.smsBlue,
                onTap: () => _sms(context),
              ),
            ],
          ),

          // ── M-Pesa section ────────────────────────────────────
          if (hasMpesa) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        AppColors.mpesaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('M-Pesa',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mpesaGreen)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.isPaybill
                            ? 'Paybill ${supplier.mpesaTill}'
                            : 'Buy Goods ${supplier.mpesaTill}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      if (supplier.isPaybill &&
                          supplier.mpesaAccountRef != null &&
                          supplier.mpesaAccountRef!.isNotEmpty)
                        Text('Account: ${supplier.mpesaAccountRef!}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      if (supplier.mpesaName != null &&
                          supplier.mpesaName!.isNotEmpty)
                        Text(supplier.mpesaName!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: paymentText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Payment details copied ✓'),
                            backgroundColor: AppColors.primaryTeal,
                            duration: Duration(seconds: 2)),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_outlined,
                            size: 12, color: AppColors.primaryTeal),
                        SizedBox(width: 4),
                        Text('Copy',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTeal)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ── Expected amount ──────────────────────────────
            if (water.pricePerContainer != null &&
                water.typicalOrderQuantity != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.mpesaGreen.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.mpesaGreen
                          .withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 13, color: AppColors.mpesaGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Send KSh ${(water.pricePerContainer! * water.typicalOrderQuantity!).toStringAsFixed(0)} '
                        'for ${water.typicalOrderQuantity} bottle${water.typicalOrderQuantity == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mpesaGreen,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WATER ORDER SHEET — quick contact sheet shown on "Order Water"
// ═══════════════════════════════════════════════════════════════════════

class _WaterOrderSheet extends StatelessWidget {
  final GasSupplier supplier;
  final String message;
  final UtilityTracker water;

  const _WaterOrderSheet({
    required this.supplier,
    required this.message,
    required this.water,
  });

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: supplier.phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _whatsapp(BuildContext context) async {
    final phone = supplier.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final intlPhone = phone.startsWith('07')
        ? '254${phone.substring(1)}'
        : phone.startsWith('0')
            ? '254${phone.substring(1)}'
            : phone;
    final msg = Uri.encodeComponent(message);
    final waUri = Uri.parse('https://wa.me/$intlPhone?text=$msg');
    if (await canLaunchUrl(waUri)) {
      launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Message copied — WhatsApp not available'),
              backgroundColor: AppColors.primaryTeal),
        );
      }
    }
  }

  Future<void> _sms(BuildContext context) async {
    final uri = Uri(
        scheme: 'sms',
        path: supplier.phone,
        queryParameters: {'body': message});
    if (await canLaunchUrl(uri)) {
      launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Message copied to clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(supplier.phone,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  color: AppColors.mpesaGreen,
                  onTap: _call,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  color: AppColors.whatsappGreen,
                  onTap: () => _whatsapp(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  color: AppColors.smsBlue,
                  onTap: () => _sms(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WATER SETUP SHEET — multi-step configuration
// ═══════════════════════════════════════════════════════════════════════

class _WaterSetupSheet extends StatefulWidget {
  final UtilityTracker? existing;
  const _WaterSetupSheet({this.existing});

  @override
  State<_WaterSetupSheet> createState() => _WaterSetupSheetState();
}

class _WaterSetupSheetState extends State<_WaterSetupSheet> {
  // Step 0: bottle size  1: bottle count  2: frequency/price  3: supplier
  int _step = 0;

  static const _sizeOptions = [10.0, 18.5, 20.0, 25.0];
  static const _countOptions = [1, 2, 3, 4];
  static const _freqOptions = [7, 10, 14, 21, 30];
  static const _thresholdOptions = [1, 2];

  double? _selectedSize;
  int? _selectedCount;
  int _fullCount = 1;
  int? _selectedFreq;
  int? _selectedThreshold;
  final _priceCtrl = TextEditingController();

  // Supplier
  final _supplierNameCtrl = TextEditingController();
  final _supplierPhoneCtrl = TextEditingController();
  final _mpesaTillCtrl = TextEditingController();
  final _mpesaNameCtrl = TextEditingController();
  final _mpesaAccountRefCtrl = TextEditingController();
  final _deliveryAddrCtrl = TextEditingController();
  bool _isPaybill = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _selectedSize = ex.containerSizeLitres;
      _selectedCount = ex.totalContainers;
      _fullCount = ex.fullContainers ?? 1;
      _selectedFreq = ex.reorderFrequencyDays;
      _selectedThreshold = ex.reorderThreshold;
      if (ex.pricePerContainer != null) {
        _priceCtrl.text = ex.pricePerContainer!.toStringAsFixed(0);
      }
      _deliveryAddrCtrl.text = ex.deliveryAddress ?? '';
      if (ex.supplier1 != null) {
        _supplierNameCtrl.text = ex.supplier1!.name;
        _supplierPhoneCtrl.text = ex.supplier1!.phone;
        _mpesaTillCtrl.text = ex.supplier1!.mpesaTill ?? '';
        _mpesaNameCtrl.text = ex.supplier1!.mpesaName ?? '';
        _mpesaAccountRefCtrl.text = ex.supplier1!.mpesaAccountRef ?? '';
        _isPaybill = ex.supplier1!.isPaybill;
      }
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierPhoneCtrl.dispose();
    _mpesaTillCtrl.dispose();
    _mpesaNameCtrl.dispose();
    _mpesaAccountRefCtrl.dispose();
    _deliveryAddrCtrl.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _selectedSize != null;
      case 1:
        return _selectedCount != null;
      case 2:
        return _selectedFreq != null &&
            _selectedThreshold != null &&
            _priceCtrl.text.trim().isNotEmpty;
      case 3:
        return true; // supplier is optional
    }
    return true;
  }

  void _proceed() async {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    // Save
    final auth = context.read<AuthProvider>();
    final utilProv = context.read<UtilityProvider>();

    GasSupplier? supplier;
    final name = _supplierNameCtrl.text.trim();
    final phone = _supplierPhoneCtrl.text.trim();
    if (name.isNotEmpty || phone.isNotEmpty) {
      supplier = GasSupplier(
        name: name,
        phone: phone,
        mpesaTill: _mpesaTillCtrl.text.trim().isEmpty
            ? null
            : _mpesaTillCtrl.text.trim(),
        mpesaName: _mpesaNameCtrl.text.trim().isEmpty
            ? null
            : _mpesaNameCtrl.text.trim(),
        isPaybill: _isPaybill,
        mpesaAccountRef: (_isPaybill && _mpesaAccountRefCtrl.text.trim().isNotEmpty)
            ? _mpesaAccountRefCtrl.text.trim()
            : null,
      );
    }

    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final count = _selectedCount ?? 2;
    final full = _fullCount.clamp(0, count);

    UtilityTracker? target = widget.existing;
    if (target == null) {
      final existing =
          utilProv.waterItems.where((i) => i.isDrinkingWater).toList();
      if (existing.isNotEmpty) {
        target = existing.first;
      } else {
        // No seeded item — create a new one
        const uuid = Uuid();
        final newItem = UtilityTracker(
          id: uuid.v4(),
          householdId: auth.household!.id,
          type: UtilityType.water,
          label: 'Drinking Water',
          isDrinkingWater: true,
          updatedAt: DateTime.now(),
        );
        await utilProv.addItem(newItem, auth.household!.id);
        target = newItem;
      }
    }

    final deliveryAddr = _deliveryAddrCtrl.text.trim();
    await utilProv.setupDrinkingWater(
      itemId: target.id,
      householdId: auth.household!.id,
      containerSizeLitres: _selectedSize ?? 18.5,
      totalContainers: count,
      fullContainers: full,
      reorderThreshold: _selectedThreshold ?? 1,
      typicalOrderQuantity: count,
      reorderFrequencyDays: _selectedFreq ?? 14,
      pricePerContainer: price,
      supplier1: supplier,
      deliveryAddress: deliveryAddr.isEmpty ? null : deliveryAddr,
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Drinking water set up ✓'),
        backgroundColor: AppColors.primaryTeal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Step indicator
            Row(
              children: List.generate(4, (i) {
                final done = i < _step;
                final active = i == _step;
                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: done || active
                                ? AppColors.primaryTeal
                                : AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i < 3) const SizedBox(width: 4),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            if (_step == 0) _buildStepSize(),
            if (_step == 1) _buildStepCount(),
            if (_step == 2) _buildStepFrequency(),
            if (_step == 3) _buildStepSupplier(),

            const SizedBox(height: 24),

            // Navigation
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _canProceed() ? _proceed : null,
                    child: Text(
                      _step == 3 ? 'Save Setup' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 0: Bottle size ─────────────────────────────────────────

  Widget _buildStepSize() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What size water bottles do you use?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text(
            'Most Kenyan households use 18.5L or 20L bottles for their dispenser.',
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _sizeOptions.map((s) {
            final sel = _selectedSize == s;
            final label = s % 1 == 0 ? '${s.toInt()}L' : '${s}L';
            return GestureDetector(
              onTap: () => setState(() => _selectedSize = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryTeal
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? AppColors.primaryTeal
                        : AppColors.divider,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? Colors.white
                            : AppColors.textPrimary)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Step 1: Bottle count ────────────────────────────────────────

  Widget _buildStepCount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How many bottles does your household own?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text(
            'Usually 2: one in use on the dispenser, one spare.',
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _countOptions.map((c) {
            final sel = _selectedCount == c;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCount = c;
                  if (_fullCount > c) _fullCount = c;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryTeal
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? AppColors.primaryTeal
                        : AppColors.divider,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Text('$c',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: sel
                            ? Colors.white
                            : AppColors.textPrimary)),
              ),
            );
          }).toList(),
        ),
        if (_selectedCount != null) ...[
          const SizedBox(height: 20),
          Text('How many are currently full?',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: _fullCount > 0
                    ? () => setState(() => _fullCount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.primaryTeal,
              ),
              Expanded(
                child: Center(
                  child: Text('$_fullCount full',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
              ),
              IconButton(
                onPressed: _fullCount < (_selectedCount ?? 0)
                    ? () => setState(() => _fullCount++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primaryTeal,
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Step 2: Frequency + price ───────────────────────────────────

  Widget _buildStepFrequency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How often do you typically reorder?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text(
            'Most families with 2 × 18.5L refill every 2 weeks.',
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _freqOptions.map((f) {
            final sel = _selectedFreq == f;
            final label = f == 7
                ? 'Weekly'
                : f == 14
                    ? 'Every 2 wks'
                    : f == 21
                        ? 'Every 3 wks'
                        : f == 30
                            ? 'Monthly'
                            : 'Every ${f}d';
            return GestureDetector(
              onTap: () => setState(() => _selectedFreq = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryTeal
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? AppColors.primaryTeal
                        : AppColors.divider,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? Colors.white
                            : AppColors.textPrimary)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text('Reorder when full bottles reach:',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: _thresholdOptions.map((t) {
            final sel = _selectedThreshold == t;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selectedThreshold = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primaryTeal
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel
                          ? AppColors.primaryTeal
                          : AppColors.divider,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '$t bottle${t == 1 ? '' : 's'} or fewer',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? Colors.white
                            : AppColors.textPrimary),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _priceCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Price per bottle (KSh)',
            hintText: 'e.g. 450',
            prefixText: 'KSh ',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ── Step 3: Supplier ────────────────────────────────────────────

  Widget _buildStepSupplier() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who is your water supplier?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        const Text(
            'Optional — add now for one-tap ordering and M-Pesa payment.',
            style:
                TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deliveryAddrCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Delivery address',
            hintText: 'e.g. Davice Apartments, Apt B7, Kileleshwa',
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            helperText: 'Added to your order message when contacting supplier',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _supplierNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Supplier name',
            hintText: 'e.g. Jibu, Aquamist…',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _supplierPhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Phone number',
            hintText: '07xx xxx xxx',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 18),
        const Text('M-Pesa payment details (optional)',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPaybill = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_isPaybill
                        ? AppColors.mpesaGreen.withValues(alpha: 0.1)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !_isPaybill
                          ? AppColors.mpesaGreen
                          : AppColors.divider,
                      width: !_isPaybill ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text('Buy Goods',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: !_isPaybill
                                ? AppColors.mpesaGreen
                                : AppColors.textSecondary)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPaybill = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _isPaybill
                        ? AppColors.mpesaGreen.withValues(alpha: 0.1)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isPaybill
                          ? AppColors.mpesaGreen
                          : AppColors.divider,
                      width: _isPaybill ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text('Paybill',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isPaybill
                                ? AppColors.mpesaGreen
                                : AppColors.textSecondary)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _mpesaTillCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _isPaybill ? 'Paybill number' : 'Buy Goods till number',
            hintText: 'e.g. 530530',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_isPaybill) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _mpesaAccountRefCtrl,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'Account number / reference',
              hintText: 'e.g. your phone number or account name',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _mpesaNameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'M-Pesa display name (optional)',
            hintText: 'Name shown when you pay',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WATER HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _WaterSupplyMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final bool highlight;
  final bool alert;

  const _WaterSupplyMiniStat({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.highlight = false,
    this.alert = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = alert
        ? AppColors.statusVeryLow
        : highlight
            ? AppColors.primaryTeal.withValues(alpha: 0.08)
            : AppColors.surfaceLight;
    final textColor = alert
        ? AppColors.statusVeryLowText
        : highlight
            ? AppColors.primaryTeal
            : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? AppColors.textHint),
            const SizedBox(height: 4),
          ],
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
        ],
      ),
    );
  }
}

class _WaterInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WaterInfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────
// SETUP PROMPT CARD (shown before first setup)
// ─────────────────────────────────────────────────────────────────────

class _GasSetupCard extends StatelessWidget {
  final VoidCallback onSetup;
  final bool isOwner;

  const _GasSetupCard({required this.onSetup, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentOrange.withValues(alpha: 0.08),
            AppColors.accentOrange.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department_outlined,
                color: AppColors.accentOrange, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'Set Up Gas Tracking',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us your cylinder size and how long it usually lasts — we\'ll track it and alert you before it runs out.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (isOwner)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: onSetup,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Set Up Now',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            )
          else
            const Text(
              'Ask the household owner or manager to set this up',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// GAS STATUS CARD (main display after setup)
// ─────────────────────────────────────────────────────────────────────

class _GasStatusCard extends StatelessWidget {
  final UtilityTracker gas;
  final AuthProvider auth;

  const _GasStatusCard({required this.gas, required this.auth});

  @override
  Widget build(BuildContext context) {
    final level = gas.gasAlertLevel;
    final pct = gas.gasPercentRemaining ?? 0;
    final rem = gas.estimatedDaysRemaining ?? 0;
    final runOut = gas.estimatedRunOutDate;
    final nextStep = _nextStep(level, auth);

    final (bgColor, barColor, iconColor, labelColor, levelLabel) =
        _levelStyle(level);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: barColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_fire_department_rounded,
                    color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gas.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${gas.cylinderKg ?? 13} kg · ${gas.brandName}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  levelLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 10,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pct% remaining',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              if (rem > 0)
                Text(
                  '$rem days left',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Status message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                level == GasAlertLevel.ok
                    ? Icons.info_outline
                    : Icons.warning_amber_rounded,
                size: 16,
                color: labelColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gas.gasStatusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: labelColor,
                    fontWeight: level == GasAlertLevel.ok
                        ? FontWeight.w400
                        : FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),

          // Refill + run-out dates
          if (gas.lastRefilledAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _DatePill(
                  icon: Icons.refresh_outlined,
                  label: 'Refilled',
                  date: gas.lastRefilledAt!,
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(width: 10),
                if (runOut != null)
                  _DatePill(
                    icon: Icons.event_outlined,
                    label: 'Est. run-out',
                    date: runOut,
                    color: barColor,
                  ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: barColor.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_circle_right_outlined,
                    size: 17, color: labelColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next best step',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        nextStep,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nextStep(GasAlertLevel level, AuthProvider auth) {
    switch (level) {
      case GasAlertLevel.overdue:
        return auth.isOwner
            ? 'Contact your supplier immediately and confirm M-Pesa payment details before dispatch.'
            : 'Call or message a supplier now, then notify the owner with the confirmed payment details.';
      case GasAlertLevel.critical:
        return auth.isOwner
            ? 'Reach your preferred supplier today so delivery is arranged before the cylinder runs out.'
            : 'Message the supplier now and ask the owner to prepare payment once details are confirmed.';
      case GasAlertLevel.warning:
        return 'Line up your preferred supplier this week so refill and payment are sorted early.';
      case GasAlertLevel.ok:
        return 'Everything looks okay. Keep supplier and payment details updated for a faster reorder later.';
    }
  }

  (Color, Color, Color, Color, String) _levelStyle(GasAlertLevel level) {
    switch (level) {
      case GasAlertLevel.overdue:
        return (
          AppColors.statusVeryLow,
          AppColors.accentOrange,
          AppColors.accentOrange,
          AppColors.statusVeryLowText,
          'Overdue!'
        );
      case GasAlertLevel.critical:
        return (
          AppColors.statusVeryLow,
          AppColors.accentOrange,
          AppColors.accentOrange,
          AppColors.statusVeryLowText,
          'Critical'
        );
      case GasAlertLevel.warning:
        return (
          AppColors.statusLow,
          AppColors.accentYellow,
          AppColors.accentYellow,
          AppColors.statusLowText,
          'Running Low'
        );
      case GasAlertLevel.ok:
        return (
          AppColors.statusEnough,
          AppColors.primaryTeal,
          AppColors.primaryTeal,
          AppColors.statusEnoughText,
          'OK'
        );
    }
  }
}

class _DatePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime date;
  final Color color;

  const _DatePill({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = _fmt(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      color: color,
                      fontWeight: FontWeight.w500)),
              Text(s,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────
// GAS ACTION BUTTONS (Refill Today / Edit Setup)
// ─────────────────────────────────────────────────────────────────────

class _GasActionsRow extends StatelessWidget {
  final UtilityTracker gas;
  final AuthProvider auth;

  const _GasActionsRow({required this.gas, required this.auth});

  @override
  Widget build(BuildContext context) {
    final canEdit = auth.isOwner || auth.isHouseManager;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: canEdit ? () => _confirmRefill(context) : null,
            icon: const Icon(Icons.refresh_outlined, size: 18),
            label: const Text('Refilled Today',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            minimumSize: const Size(0, 46),
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: canEdit
              ? () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _GasSetupSheet(existing: gas),
                  )
              : null,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Edit',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  void _confirmRefill(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Record Refill'),
        content: const Text(
            'Mark gas as refilled today? This resets the countdown to the estimated run-out date.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 20)),
            onPressed: () {
              Navigator.pop(ctx);
              final utilProv = context.read<UtilityProvider>();
              final auth = context.read<AuthProvider>();
              utilProv.recordRefill(gas.id, auth.household!.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Gas refill recorded ✓'),
                    backgroundColor: AppColors.primaryTeal),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// GAS SUPPLIERS CARD
// ─────────────────────────────────────────────────────────────────────

class _GasSuppliersCard extends StatelessWidget {
  final UtilityTracker gas;
  final AuthProvider auth;

  const _GasSuppliersCard({required this.gas, required this.auth});

  @override
  Widget build(BuildContext context) {
    final canEdit = auth.isOwner || auth.isHouseManager;
    final hasSuppliers = gas.supplier1 != null || gas.supplier2 != null;

    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    size: 16, color: AppColors.primaryTeal),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gas Suppliers',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('Tap Call or WhatsApp to order a refill',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (canEdit)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTeal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _showSupplierSheet(context, gas),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: Text(hasSuppliers ? 'Edit' : 'Add',
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),

          if (!hasSuppliers) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: canEdit ? () => _showSupplierSheet(context, gas) : null,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.divider, style: BorderStyle.solid),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        canEdit
                            ? 'Add your gas supplier contacts so you can order in one tap'
                            : 'No supplier contacts added yet',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            if (gas.supplier1 != null)
              _SupplierTile(
                supplier: gas.supplier1!,
                label: 'Supplier 1',
                helper: 'Primary supplier',
                gas: gas,
                isPrimary: true,
                auth: auth,
              ),
            if (gas.supplier1 != null && gas.supplier2 != null)
              const SizedBox(height: 12),
            if (gas.supplier2 != null)
              _SupplierTile(
                supplier: gas.supplier2!,
                label: 'Supplier 2',
                helper: 'Backup supplier',
                gas: gas,
                isPrimary: false,
                auth: auth,
              ),
          ],
        ],
      ),
    );
  }

  void _showSupplierSheet(BuildContext context, UtilityTracker gas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierSetupSheet(gas: gas),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SINGLE SUPPLIER TILE — call / WhatsApp / M-Pesa
// ─────────────────────────────────────────────────────────────────────

class _SupplierTile extends StatelessWidget {
  final GasSupplier supplier;
  final String label;
  final String helper;
  final UtilityTracker gas;
  final bool isPrimary;
  final AuthProvider auth;

  const _SupplierTile({
    required this.supplier,
    required this.label,
    required this.helper,
    required this.gas,
    required this.isPrimary,
    required this.auth,
  });

  String _orderMessage() {
    final kg = gas.cylinderKg ?? 13;
    final brand = gas.gasBrand == GasBrand.other
        ? (gas.gasBrandCustom ?? '')
        : (gas.gasBrand?.displayName ?? '');
    final brandStr = brand.isNotEmpty ? '$brand ' : '';
    final addr = gas.deliveryAddress?.trim();
    final addrStr = (addr != null && addr.isNotEmpty)
        ? ' to $addr'
        : '';
    return 'Hi! I\'d like to order $brandStr${kg}kg cooking gas$addrStr. '
        'Kindly confirm your availability and share payment details. Thank you! 🙏';
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: supplier.phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _whatsapp(BuildContext context) async {
    final phone = supplier.phone.replaceAll(RegExp(r'[^0-9]'), '');
    // Kenyan numbers: 07xx → 2547xx
    final intlPhone = phone.startsWith('07')
        ? '254${phone.substring(1)}'
        : phone.startsWith('0')
            ? '254${phone.substring(1)}'
            : phone;
    final msg = Uri.encodeComponent(_orderMessage());
    final waUri =
        Uri.parse('https://wa.me/$intlPhone?text=$msg');
    if (await canLaunchUrl(waUri)) {
      launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: _orderMessage()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Message copied — WhatsApp not available'),
              backgroundColor: AppColors.primaryTeal),
        );
      }
    }
  }

  Future<void> _sms(BuildContext context) async {
    final uri = Uri(
        scheme: 'sms', path: supplier.phone,
        queryParameters: {'body': _orderMessage()});
    if (await canLaunchUrl(uri)) {
      launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: _orderMessage()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message copied to clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMpesa =
        supplier.mpesaTill != null && supplier.mpesaTill!.isNotEmpty;
    final accountRef = supplier.isPaybill && supplier.mpesaAccountRef != null
        ? ' Acc: ${supplier.mpesaAccountRef}'
        : '';
    final paymentText = '${supplier.mpesaName ?? supplier.name} — '
        '${supplier.isPaybill ? 'Paybill' : 'Buy Goods'} '
        '${supplier.mpesaTill ?? ''}$accountRef';
    final ownerMessage = auth.isOwner
        ? 'Hi! Once ${supplier.name} confirms dispatch, kindly arrange payment via M-Pesa:\n$paymentText\nThank you! 🙏'
        : 'Hi! I have ordered cooking gas from ${supplier.name}. Kindly arrange payment once dispatch is confirmed.\nM-Pesa: $paymentText\nThank you! 🙏';
    final shouldShowOwnerPrompt = hasMpesa;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.statusEnough
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary
              ? AppColors.primaryTeal.withValues(alpha: 0.22)
              : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + phone ────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTeal),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPrimary
                                ? AppColors.primaryTeal.withValues(alpha: 0.1)
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPrimary
                                  ? AppColors.primaryTeal.withValues(alpha: 0.18)
                                  : AppColors.divider,
                            ),
                          ),
                          child: Text(
                            helper,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isPrimary
                                  ? AppColors.primaryTeal
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            supplier.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      supplier.phone,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Action buttons: Call / WhatsApp / SMS ───────────────
          Row(
            children: [
              _ActionButton(
                icon: Icons.call_outlined,
                label: 'Call',
                color: AppColors.mpesaGreen,
                onTap: _call,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                color: AppColors.whatsappGreen,
                onTap: () => _whatsapp(context),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.sms_outlined,
                label: 'SMS',
                color: AppColors.smsBlue,
                onTap: () => _sms(context),
              ),
            ],
          ),

          // ── M-Pesa payment pill ─────────────────────────────────
          if (hasMpesa) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.mpesaGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('M-Pesa',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mpesaGreen)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.isPaybill
                            ? 'Paybill ${supplier.mpesaTill}'
                            : 'Buy Goods ${supplier.mpesaTill}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                      if (supplier.isPaybill &&
                          supplier.mpesaAccountRef != null &&
                          supplier.mpesaAccountRef!.isNotEmpty)
                        Text(
                          'Account: ${supplier.mpesaAccountRef!}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      if (supplier.mpesaName != null &&
                          supplier.mpesaName!.isNotEmpty)
                        Text(
                          supplier.mpesaName!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                      await Clipboard.setData(ClipboardData(text: paymentText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Payment details copied ✓'),
                            backgroundColor: AppColors.primaryTeal,
                            duration: Duration(seconds: 2)),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_outlined,
                            size: 12, color: AppColors.primaryTeal),
                        SizedBox(width: 4),
                        Text('Copy',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTeal)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (shouldShowOwnerPrompt) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF7E8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accentYellow.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 15, color: AppColors.statusLowText),
                        const SizedBox(width: 6),
                        Text(
                          auth.isOwner
                              ? 'Payment reminder'
                              : 'Notify owner to pay',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.statusLowText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ownerMessage,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.statusLowText,
                        side: BorderSide(
                          color: AppColors.accentYellow.withValues(alpha: 0.35),
                        ),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: ownerMessage));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                auth.isOwner
                                    ? 'Payment reminder copied ✓'
                                    : 'Message copied — ready to send to owner ✓',
                              ),
                              backgroundColor: AppColors.primaryTeal,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined, size: 15),
                      label: Text(auth.isOwner ? 'Copy reminder' : 'Copy for owner'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// SUPPLIER SETUP BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────

class _SupplierSetupSheet extends StatefulWidget {
  final UtilityTracker gas;
  const _SupplierSetupSheet({required this.gas});

  @override
  State<_SupplierSetupSheet> createState() => _SupplierSetupSheetState();
}

class _SupplierSetupSheetState extends State<_SupplierSetupSheet> {
  // Supplier 1
  final _s1Name = TextEditingController();
  final _s1Phone = TextEditingController();
  final _s1MpesaName = TextEditingController();
  final _s1MpesaTill = TextEditingController();
  final _s1MpesaAccountRef = TextEditingController();
  bool _s1IsPaybill = false;

  // Supplier 2
  final _s2Name = TextEditingController();
  final _s2Phone = TextEditingController();
  final _s2MpesaName = TextEditingController();
  final _s2MpesaTill = TextEditingController();
  final _s2MpesaAccountRef = TextEditingController();
  bool _s2IsPaybill = false;

  // Delivery address
  final _addr = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s1 = widget.gas.supplier1;
    if (s1 != null) {
      _s1Name.text = s1.name;
      _s1Phone.text = s1.phone;
      _s1MpesaName.text = s1.mpesaName ?? '';
      _s1MpesaTill.text = s1.mpesaTill ?? '';
      _s1MpesaAccountRef.text = s1.mpesaAccountRef ?? '';
      _s1IsPaybill = s1.isPaybill;
    }
    final s2 = widget.gas.supplier2;
    if (s2 != null) {
      _s2Name.text = s2.name;
      _s2Phone.text = s2.phone;
      _s2MpesaName.text = s2.mpesaName ?? '';
      _s2MpesaTill.text = s2.mpesaTill ?? '';
      _s2MpesaAccountRef.text = s2.mpesaAccountRef ?? '';
      _s2IsPaybill = s2.isPaybill;
    }
    _addr.text = widget.gas.deliveryAddress ?? '';
  }

  @override
  void dispose() {
    _s1Name.dispose(); _s1Phone.dispose();
    _s1MpesaName.dispose(); _s1MpesaTill.dispose(); _s1MpesaAccountRef.dispose();
    _s2Name.dispose(); _s2Phone.dispose();
    _s2MpesaName.dispose(); _s2MpesaTill.dispose(); _s2MpesaAccountRef.dispose();
    _addr.dispose();
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
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Gas Supplier Details',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text(
              'Add up to 2 suppliers — we\'ll pre-fill the order message for you.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // ── Delivery Address ─────────────────────────────────
            _SectionHeader('Delivery Address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addr,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'e.g. Imara Gardens Estate, House 18A',
                prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // ── Supplier 1 ───────────────────────────────────────
            _buildSupplierSection(
              title: '🧑 Supplier 1',
              nameCtrl: _s1Name,
              phoneCtrl: _s1Phone,
              mpesaNameCtrl: _s1MpesaName,
              mpesaTillCtrl: _s1MpesaTill,
              mpesaAccountRefCtrl: _s1MpesaAccountRef,
              isPaybill: _s1IsPaybill,
              onPaybillChanged: (v) => setState(() => _s1IsPaybill = v),
            ),
            const SizedBox(height: 24),

            // ── Supplier 2 ───────────────────────────────────────
            _buildSupplierSection(
              title: '🧑 Supplier 2 (optional)',
              nameCtrl: _s2Name,
              phoneCtrl: _s2Phone,
              mpesaNameCtrl: _s2MpesaName,
              mpesaTillCtrl: _s2MpesaTill,
              mpesaAccountRefCtrl: _s2MpesaAccountRef,
              isPaybill: _s2IsPaybill,
              onPaybillChanged: (v) => setState(() => _s2IsPaybill = v),
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _save,
              child: const Text('Save Supplier Details',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierSection({
    required String title,
    required TextEditingController nameCtrl,
    required TextEditingController phoneCtrl,
    required TextEditingController mpesaNameCtrl,
    required TextEditingController mpesaTillCtrl,
    required TextEditingController mpesaAccountRefCtrl,
    required bool isPaybill,
    required ValueChanged<bool> onPaybillChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Supplier name',
                  hintText: 'e.g. Mwangi Gas',
                  prefixIcon:
                      const Icon(Icons.person_outline, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'e.g. 0722 000 000',
                  prefixIcon:
                      const Icon(Icons.phone_outlined, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // M-Pesa section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.mpesaGreen.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.mpesaGreen.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.mobile_friendly_outlined,
                      size: 14, color: AppColors.mpesaGreen),
                  SizedBox(width: 6),
                  Text('M-Pesa Payment (optional)',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mpesaGreen)),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: mpesaNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'M-Pesa name',
                  hintText: 'e.g. Mwangi Cooking Gas Supplies',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: mpesaTillCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isPaybill
                            ? 'Paybill number'
                            : 'Buy Goods till',
                        hintText: isPaybill ? '123456' : '12345',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Toggle: Buy Goods / Paybill
                  GestureDetector(
                    onTap: () => onPaybillChanged(!isPaybill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isPaybill
                            ? AppColors.mpesaGreen
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isPaybill
                                ? AppColors.mpesaGreen
                                : AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          Text(
                            isPaybill ? 'Paybill' : 'Buy Goods',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isPaybill
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'tap to switch',
                            style: TextStyle(
                              fontSize: 9,
                              color: isPaybill
                                  ? Colors.white70
                                  : AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (isPaybill) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: mpesaAccountRefCtrl,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Account number / reference',
                    hintText: 'e.g. your phone number or account name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _save() async {
    final utilProv = context.read<UtilityProvider>();
    final auth = context.read<AuthProvider>();

    GasSupplier? s1;
    if (_s1Name.text.trim().isNotEmpty || _s1Phone.text.trim().isNotEmpty) {
      s1 = GasSupplier(
        name: _s1Name.text.trim(),
        phone: _s1Phone.text.trim(),
        mpesaName: _s1MpesaName.text.trim().isEmpty
            ? null
            : _s1MpesaName.text.trim(),
        mpesaTill: _s1MpesaTill.text.trim().isEmpty
            ? null
            : _s1MpesaTill.text.trim(),
        isPaybill: _s1IsPaybill,
        mpesaAccountRef: (_s1IsPaybill && _s1MpesaAccountRef.text.trim().isNotEmpty)
            ? _s1MpesaAccountRef.text.trim()
            : null,
      );
    }
    GasSupplier? s2;
    if (_s2Name.text.trim().isNotEmpty || _s2Phone.text.trim().isNotEmpty) {
      s2 = GasSupplier(
        name: _s2Name.text.trim(),
        phone: _s2Phone.text.trim(),
        mpesaName: _s2MpesaName.text.trim().isEmpty
            ? null
            : _s2MpesaName.text.trim(),
        mpesaTill: _s2MpesaTill.text.trim().isEmpty
            ? null
            : _s2MpesaTill.text.trim(),
        isPaybill: _s2IsPaybill,
        mpesaAccountRef: (_s2IsPaybill && _s2MpesaAccountRef.text.trim().isNotEmpty)
            ? _s2MpesaAccountRef.text.trim()
            : null,
      );
    }

    await utilProv.saveSuppliers(
      itemId: widget.gas.id,
      householdId: auth.household!.id,
      supplier1: s1,
      supplier2: s2,
      deliveryAddress:
          _addr.text.trim().isEmpty ? null : _addr.text.trim(),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supplier details saved ✓'),
          backgroundColor: AppColors.primaryTeal,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// SECTION HEADER helper (used inside setup sheet)
// ─────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary));
  }
}

// ─────────────────────────────────────────────────────────────────────
// GAS TIMELINE CARD
// ─────────────────────────────────────────────────────────────────────

class _GasTimelineCard extends StatelessWidget {
  final UtilityTracker gas;

  const _GasTimelineCard({required this.gas});

  @override
  Widget build(BuildContext context) {
    final duration = gas.estimatedDurationDays ?? 0;
    final weeks = (duration / 7).round();
    final refilled = gas.lastRefilledAt;
    final runOut = gas.estimatedRunOutDate;
    final warnDate = refilled?.add(Duration(days: duration - 7));

    return HomeFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_outlined,
                  size: 16, color: AppColors.primaryTeal),
              SizedBox(width: 6),
              Text(
                'Gas Timeline',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TimelineRow(
            icon: Icons.refresh_outlined,
            color: AppColors.primaryTeal,
            label: 'Last refill',
            value: refilled != null ? _fmt(refilled) : '—',
          ),
          _TimelineRow(
            icon: Icons.access_time_outlined,
            color: AppColors.accentYellow,
            label: 'Expected duration',
            value: '$weeks week${weeks == 1 ? '' : 's'} ($duration days)',
          ),
          _TimelineRow(
            icon: Icons.notifications_outlined,
            color: AppColors.accentYellow,
            label: '1-week warning',
            value: warnDate != null ? _fmt(warnDate) : '—',
          ),
          _TimelineRow(
            icon: Icons.event_busy_outlined,
            color: AppColors.accentOrange,
            label: 'Estimated run-out',
            value: runOut != null ? _fmt(runOut) : '—',
            isLast: true,
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isLast;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// GAS SETUP BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────

class _GasSetupSheet extends StatefulWidget {
  final UtilityTracker? existing;
  const _GasSetupSheet({this.existing});

  @override
  State<_GasSetupSheet> createState() => _GasSetupSheetState();
}

class _GasSetupSheetState extends State<_GasSetupSheet> {
  // Step: 0 = brand, 1 = kg size, 2 = weeks, 3 = refill date
  int _step = 0;

  // Common Kenyan cylinder sizes
  static const _kgOptions = [6, 13, 35, 50];
  // Common week durations per typical household
  static const _weekOptions = [2, 3, 4, 5, 6, 7, 8, 10, 12];

  GasBrand? _selectedBrand;
  final _customBrandCtrl = TextEditingController();
  int? _selectedKg;
  int? _selectedWeeks;
  DateTime _lastRefillDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _selectedBrand = widget.existing!.gasBrand;
      _customBrandCtrl.text = widget.existing!.gasBrandCustom ?? '';
      _selectedKg = widget.existing!.cylinderKg;
      if (widget.existing!.estimatedDurationDays != null) {
        final w = (widget.existing!.estimatedDurationDays! / 7).round();
        if (_weekOptions.contains(w)) _selectedWeeks = w;
      }
      if (widget.existing!.lastRefilledAt != null) {
        _lastRefillDate = widget.existing!.lastRefilledAt!;
      }
    }
  }

  @override
  void dispose() {
    _customBrandCtrl.dispose();
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
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Step indicator
          Row(
            children: List.generate(4, (i) {
              final done = i < _step;
              final active = i == _step;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: done || active
                              ? AppColors.accentOrange
                              : AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 3) const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Step content
          if (_step == 0) _buildStepBrand(),
          if (_step == 1) _buildStepKg(),
          if (_step == 2) _buildStepWeeks(),
          if (_step == 3) _buildStepRefillDate(context),

          const SizedBox(height: 20),

          // Navigation buttons
          Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                flex: _step == 0 ? 1 : 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _canProceed() ? _proceed : null,
                  child: Text(
                    _step == 3 ? 'Save Setup' : 'Next',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepBrand() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What brand is your cooking gas cylinder?',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'This helps identify the right cylinder when ordering from your supplier.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: GasBrand.values.map((brand) {
            final sel = _selectedBrand == brand;
            return GestureDetector(
              onTap: () => setState(() => _selectedBrand = brand),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.accentOrange
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? AppColors.accentOrange
                        : AppColors.divider,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(brand.emoji,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      brand.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            sel ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedBrand == GasBrand.other) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customBrandCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Brand name',
              hintText: 'e.g. ProGas, Lake Gas...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_selectedBrand == null)
          const Text(
            'You can skip this step if you\'re not sure.',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _buildStepKg() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How many kilograms is your cooking gas cylinder?',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Common sizes in Kenya: 6 kg, 13 kg, 35 kg, 50 kg',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _kgOptions.map((kg) {
            final sel = _selectedKg == kg;
            return GestureDetector(
              onTap: () => setState(() => _selectedKg = kg),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.accentOrange
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel
                        ? AppColors.accentOrange
                        : AppColors.divider,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$kg',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: sel ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 12,
                        color: sel ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Custom kg input
        TextFormField(
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Or enter custom size (kg)',
            suffixText: 'kg',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) setState(() => _selectedKg = n);
          },
        ),
      ],
    );
  }

  Widget _buildStepWeeks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How many weeks does your ${_selectedKg}kg cylinder usually last?',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Based on your household\'s typical cooking — be honest for accurate alerts!',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _weekOptions.map((w) {
            final sel = _selectedWeeks == w;
            return GestureDetector(
              onTap: () => setState(() => _selectedWeeks = w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.accentOrange
                      : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel
                        ? AppColors.accentOrange
                        : AppColors.divider,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Text(
                  '$w wks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStepRefillDate(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'When was the gas last refilled?',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'This sets the countdown start date. If you just refilled, tap "Today".',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        // Quick options
        Row(
          children: [
            _QuickDateChip(
              label: 'Today',
              selected: _isToday(_lastRefillDate),
              onTap: () => setState(() => _lastRefillDate = DateTime.now()),
            ),
            const SizedBox(width: 8),
            _QuickDateChip(
              label: 'Yesterday',
              selected: _isYesterday(_lastRefillDate),
              onTap: () => setState(() => _lastRefillDate =
                  DateTime.now().subtract(const Duration(days: 1))),
            ),
            const SizedBox(width: 8),
            _QuickDateChip(
              label: 'Pick date',
              selected: !_isToday(_lastRefillDate) &&
                  !_isYesterday(_lastRefillDate),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _lastRefillDate,
                  firstDate: DateTime.now()
                      .subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.accentOrange,
                        onPrimary: Colors.white,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _lastRefillDate = picked);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Summary
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentOrange.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.accentOrange.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Cylinder', value: '${_selectedKg}kg'),
              const SizedBox(height: 6),
              _SummaryRow(
                  label: 'Expected duration',
                  value: '$_selectedWeeks weeks'),
              const SizedBox(height: 6),
              _SummaryRow(
                  label: 'Last refilled',
                  value: _fmtDate(_lastRefillDate)),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'Est. run-out',
                value: _fmtDate(_lastRefillDate.add(
                    Duration(days: _selectedWeeks! * 7))),
                highlight: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isYesterday(DateTime d) {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return d.year == y.year && d.month == y.month && d.day == y.day;
  }

  bool _canProceed() {
    if (_step == 0) return true; // brand is optional — can skip
    if (_step == 1) return _selectedKg != null;
    if (_step == 2) return _selectedWeeks != null;
    return true;
  }

  void _proceed() {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    // Save
    _save();
  }

  void _save() async {
    final utilProv = context.read<UtilityProvider>();
    final auth = context.read<AuthProvider>();
    final householdId = auth.household!.id;

    // Build brand label
    final customBrand = _customBrandCtrl.text.trim();

    // If there's an existing gas tracker, update it; otherwise create one
    final gasItems = utilProv.gasItems;
    if (gasItems.isNotEmpty) {
      await utilProv.setupGas(
        itemId: gasItems.first.id,
        householdId: householdId,
        cylinderKg: _selectedKg!,
        weeksItLasts: _selectedWeeks!,
        lastRefilledAt: _lastRefillDate,
        gasBrand: _selectedBrand,
        gasBrandCustom: customBrand.isEmpty ? null : customBrand,
      );
    } else {
      // Create new gas tracker
      const uuid = Uuid();
      final brandName = (_selectedBrand == GasBrand.other && customBrand.isNotEmpty)
          ? customBrand
          : _selectedBrand?.displayName ?? '';
      final lbl = brandName.isNotEmpty
          ? '$brandName ${_selectedKg}kg'
          : '${_selectedKg}kg Gas Cylinder';
      final newGas = UtilityTracker(
        id: uuid.v4(),
        householdId: householdId,
        type: UtilityType.cookingGas,
        label: lbl,
        cylinderKg: _selectedKg,
        gasBrand: _selectedBrand,
        gasBrandCustom: customBrand.isEmpty ? null : customBrand,
        estimatedDurationDays: _selectedWeeks! * 7,
        lastRefilledAt: _lastRefillDate,
        gasSetupDone: true,
        updatedAt: DateTime.now(),
      );
      await utilProv.addItem(newGas, householdId);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gas tracking set up ✓'),
          backgroundColor: AppColors.primaryTeal,
        ),
      );
    }
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _QuickDateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickDateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentOrange
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.accentOrange
                : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight
                ? AppColors.accentOrange
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SupplyCard extends StatelessWidget {
  final SupplyItem item;
  final bool isOwner;

  const _SupplyCard({required this.item, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final supply = context.read<SupplyProvider>();

    return HomeFlowCard(
      borderColor: item.needsAttention
          ? AppColors.accentOrange.withValues(alpha: 0.3)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (item.isOwnerOnly)
                          Tooltip(
                            message: 'Owner eyes only',
                            child: Icon(Icons.lock,
                                size: 14,
                                color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.category} · ${item.unitType}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (item.isGas && item.lastRestockedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Refilled: ${_formatDate(item.lastRestockedAt!)}${item.isGasLowAlert ? ' · Refill soon' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: item.isGasLowAlert
                              ? AppColors.accentOrange
                              : AppColors.textHint,
                          fontWeight: item.isGasLowAlert
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              StatusChip.fromSupplyStatus(item.status),
            ],
          ),
          const SizedBox(height: 12),
          // Status update chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: SupplyStatus.values.map((s) {
                final selected = item.status == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      supply.updateSupplyStatus(
                          item.id, s, auth.household!.id,
                          updatedByName: auth.currentUser?.fullName);
                      // If marking low/very low, offer to create request
                      if (s == SupplyStatus.runningLow ||
                          s == SupplyStatus.veryLow ||
                          s == SupplyStatus.finished) {
                        _showAddToShoppingDialog(context, item, auth);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? _chipColor(s)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? _chipBorderColor(s)
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        _statusLabel(s),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? _chipTextColor(s)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Last activity attribution (usage log or status change)
          Builder(builder: (_) {
            // Pick the most recent: last usage log or last status update
            final lastLog = item.usageLogs.isNotEmpty
                ? item.usageLogs.reduce(
                    (a, b) => a.date.isAfter(b.date) ? a : b)
                : null;
            final useLog = lastLog != null &&
                (item.statusUpdatedAt == null ||
                    lastLog.date.isAfter(item.statusUpdatedAt!));
            String? line;
            if (useLog && lastLog != null) {
              final who = lastLog.loggedByName != null
                  ? 'By ${lastLog.loggedByName}'
                  : null;
              line = [
                if (who != null) who,
                'Logged ${_formatDateTime(lastLog.date)}',
              ].join(' · ');
            } else if (item.statusUpdatedAt != null) {
              final who = item.statusUpdatedByName != null
                  ? 'By ${item.statusUpdatedByName}'
                  : null;
              line = [
                if (who != null) who,
                'Updated ${_formatDateTime(item.statusUpdatedAt!)}',
              ].join(' · ');
            }
            if (line == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            );
          }),
          // Optional usage logging (visible to all; data surfaces in Pro analytics)
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _LogUsageSheet(item: item),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 14, color: AppColors.primaryTeal),
                const SizedBox(width: 4),
                Text(
                  item.usageLogs.isEmpty
                      ? 'Log amount used'
                      : 'Log amount used · ${item.usageLogs.length} entr${item.usageLogs.length == 1 ? 'y' : 'ies'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => supply.toggleOwnerOnly(item.id, auth.household!.id),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.isOwnerOnly ? Icons.lock : Icons.lock_open,
                    size: 13,
                    color: item.isOwnerOnly
                        ? AppColors.textSecondary
                        : AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.isOwnerOnly ? 'Owner only' : 'Visible to all',
                    style: TextStyle(
                      fontSize: 11,
                      color: item.isOwnerOnly
                          ? AppColors.textSecondary
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(SupplyStatus s) {
    switch (s) {
      case SupplyStatus.enough:
        return 'Enough';
      case SupplyStatus.runningLow:
        return 'Running Low';
      case SupplyStatus.veryLow:
        return 'Very Low';
      case SupplyStatus.finished:
        return 'Finished';
    }
  }

  Color _chipColor(SupplyStatus s) {
    switch (s) {
      case SupplyStatus.enough:
        return AppColors.statusEnough;
      case SupplyStatus.runningLow:
        return AppColors.statusLow;
      case SupplyStatus.veryLow:
        return AppColors.statusVeryLow;
      case SupplyStatus.finished:
        return AppColors.statusFinished;
    }
  }

  Color _chipBorderColor(SupplyStatus s) {
    switch (s) {
      case SupplyStatus.enough:
        return AppColors.statusEnoughText;
      case SupplyStatus.runningLow:
        return AppColors.statusLowText;
      case SupplyStatus.veryLow:
        return AppColors.statusVeryLowText;
      case SupplyStatus.finished:
        return AppColors.statusFinishedText;
    }
  }

  Color _chipTextColor(SupplyStatus s) {
    switch (s) {
      case SupplyStatus.enough:
        return AppColors.statusEnoughText;
      case SupplyStatus.runningLow:
        return AppColors.statusLowText;
      case SupplyStatus.veryLow:
        return AppColors.statusVeryLowText;
      case SupplyStatus.finished:
        return AppColors.statusFinishedText;
    }
  }

  void _showAddToShoppingDialog(
      BuildContext context, SupplyItem item, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add to Shopping?'),
        content: Text('Add ${item.name} to the shopping requests?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              const uuid = Uuid();
              final req = ShoppingRequest(
                id: uuid.v4(),
                householdId: auth.household!.id,
                supplyItemId: item.id,
                itemName: item.name,
                quantity: '1 ${item.unitType}',
                category: item.category,
                urgency: item.status == SupplyStatus.finished
                    ? ShoppingUrgency.critical
                    : item.status == SupplyStatus.veryLow
                        ? ShoppingUrgency.neededToday
                        : ShoppingUrgency.neededSoon,
                requestedByUserId: auth.currentUser!.id,
                requestedByName: auth.currentUser!.fullName,
                requestedAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              context.read<SupplyProvider>().addShoppingRequest(
                  req, auth.household!.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${item.name} added to shopping requests')),
              );
            },
            child: const Text('Add Request'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  String _formatDateTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $h:$m';
  }
}

class _AddSupplySheet extends StatefulWidget {
  const _AddSupplySheet();

  @override
  State<_AddSupplySheet> createState() => _AddSupplySheetState();
}

class _AddSupplySheetState extends State<_AddSupplySheet> {
  final _nameCtrl = TextEditingController();
  String _category = AppConstants.supplyCategories.first;
  String _unit = AppConstants.unitTypes.first;
  bool _isOwnerOnly = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final supply = context.read<SupplyProvider>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add Supply Item',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text('Browse suggestions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryTeal,
                side: const BorderSide(color: AppColors.primaryTeal),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final supply = context.read<SupplyProvider>();
                final alreadyTracked = supply.supplies
                    .map((s) => s.name.toLowerCase())
                    .toSet();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) =>
                      _SuggestionsSheet(alreadyTracked: alreadyTracked),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or add manually',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Item name'),
            autofocus: false,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: AppConstants.supplyCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _unit,
            decoration: const InputDecoration(labelText: 'Unit type'),
            items: AppConstants.unitTypes
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (v) => setState(() => _unit = v!),
          ),
          const SizedBox(height: 20),
          if (auth.isOwner)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 16),
                  SizedBox(width: 6),
                  Text('Owner eyes only', style: TextStyle(fontSize: 14)),
                ],
              ),
              subtitle: const Text(
                'Hidden from house managers',
                style: TextStyle(fontSize: 12),
              ),
              value: _isOwnerOnly,
              onChanged: (v) => setState(() => _isOwnerOnly = v),
            ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              if (_nameCtrl.text.trim().isEmpty) return;
              const uuid = Uuid();
              final item = SupplyItem(
                id: uuid.v4(),
                householdId: auth.household!.id,
                name: _nameCtrl.text.trim(),
                category: _category,
                unitType: _unit,
                isGas: _nameCtrl.text.toLowerCase().contains('gas'),
                expectedDurationDays:
                    _nameCtrl.text.toLowerCase().contains('gas') ? 42 : null,
                isOwnerOnly: _isOwnerOnly,
              );
              supply.addSupplyItem(item, auth.household!.id);
              Navigator.pop(context);
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// LOG USAGE SHEET
// ════════════════════════════════════════════════════════════════

class _LogUsageSheet extends StatefulWidget {
  final SupplyItem item;
  const _LogUsageSheet({required this.item});

  @override
  State<_LogUsageSheet> createState() => _LogUsageSheetState();
}

class _LogUsageSheetState extends State<_LogUsageSheet> {
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qtyText = _qtyCtrl.text.trim();
    if (qtyText.isEmpty) return;
    final qty = double.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than zero.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final householdId =
          context.read<AuthProvider>().household?.id ?? '';
      final price = double.tryParse(_priceCtrl.text.trim());
      final loggedByName =
          context.read<AuthProvider>().currentUser?.fullName;
      await context.read<SupplyProvider>().logUsage(
            widget.item.id,
            qty,
            householdId,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            price: (price != null && price > 0) ? price : null,
            loggedByName: loggedByName,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log usage. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final recentLogs = item.usageLogs.reversed.take(5).toList();
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
            item.name,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount used',
              suffixText: item.unitType,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount spent (optional)',
              hintText: 'e.g. 850',
              prefixText: 'KES ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. used for cooking',
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
                      '${_formatDate(log.date)}: ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${log.quantity % 1 == 0 ? log.quantity.toInt() : log.quantity} ${item.unitType}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (log.loggedByName != null &&
                        log.loggedByName!.isNotEmpty) ...[
                      const Text(
                        '  ·  ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        log.loggedByName!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
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

  String _formatDate(DateTime d) {
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

// ════════════════════════════════════════════════════════════════
// ADD FROM SUGGESTIONS SHEET
// ════════════════════════════════════════════════════════════════

class _SuggestionsSheet extends StatefulWidget {
  final Set<String> alreadyTracked;
  const _SuggestionsSheet({required this.alreadyTracked});

  @override
  State<_SuggestionsSheet> createState() => _SuggestionsSheetState();
}

class _SuggestionsSheetState extends State<_SuggestionsSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _selected = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.toLowerCase();
    return AppConstants.starterSupplies.where((item) {
      if (widget.alreadyTracked.contains(
          (item['name'] as String).toLowerCase())) return false;
      if (q.isEmpty) return true;
      return (item['name'] as String).toLowerCase().contains(q) ||
          (item['category'] as String).toLowerCase().contains(q);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final item in _filtered) {
      result.putIfAbsent(item['category'] as String, () => []).add(item);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final supply = context.read<SupplyProvider>();
    final grouped = _grouped;
    final selectedCount = _selected.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: AppColors.primaryTeal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Browse Suggestions',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Text(
              'Tick items to add. Items you already track are hidden.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          // search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 1),
          // list
          Expanded(
            child: grouped.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No suggestions match your search.',
                        style:
                            TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        for (final item in entry.value)
                          CheckboxListTile(
                            dense: true,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            activeColor: AppColors.primaryTeal,
                            title: Text(item['name'] as String,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: Text(
                              item['unit'] as String,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                            value: _selected
                                .contains(item['name'] as String),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(item['name'] as String);
                              } else {
                                _selected.remove(item['name']);
                              }
                            }),
                          ),
                      ],
                    ],
                  ),
          ),
          // bottom action bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selectedCount == 0
                      ? null
                      : () {
                          const uuid = Uuid();
                          final householdId = auth.household!.id;
                          for (final name in _selected) {
                            final meta =
                                AppConstants.starterSupplies.firstWhere(
                                    (s) => s['name'] == name);
                            final isGas =
                                name.toLowerCase().contains('gas');
                            supply.addSupplyItem(
                              SupplyItem(
                                id: uuid.v4(),
                                householdId: householdId,
                                name: name,
                                category: meta['category'] as String,
                                unitType: meta['unit'] as String,
                                isGas: isGas,
                                expectedDurationDays:
                                    isGas ? 42 : null,
                              ),
                              householdId,
                            );
                          }
                          Navigator.pop(context);
                        },
                  child: Text(
                    selectedCount == 0
                        ? 'Select items to add'
                        : 'Add $selectedCount item${selectedCount == 1 ? '' : 's'}',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// METERED WATER TAB
// ════════════════════════════════════════════════════════════════

class MeteredWaterTabSection extends StatelessWidget {
  final bool embedded;
  const MeteredWaterTabSection({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();
    final items = utilProv.waterBillItems;
    final item = items.isNotEmpty ? items.first : null;
    final canManage = auth.isOwner || auth.isHouseManager;

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        if (item == null)
          _WaterBillSetupPrompt(canManage: canManage, item: null)
        else if (!item.waterBillSetupDone)
          _WaterBillSetupPrompt(canManage: canManage, item: item)
        else
          _WaterBillStatusCard(item: item, isOwner: auth.isOwner, canManage: canManage),
      ],
    );
  }
}

class _WaterBillSetupPrompt extends StatelessWidget {
  final bool canManage;
  final UtilityTracker? item;
  const _WaterBillSetupPrompt({required this.canManage, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryTeal.withValues(alpha: 0.15),
            AppColors.primaryTeal.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.water_outlined, color: AppColors.primaryTeal, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Metered Water Bill',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Monthly water bill tracking',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Track your mains/piped water bill due date, amount, and M-Pesa payment details.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.water_outlined, color: Colors.white, size: 18),
                label: const Text('Set Up Water Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onPressed: () => _showSetup(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSetup(BuildContext context) {
    final utilProv = context.read<UtilityProvider>();
    final auth = context.read<AuthProvider>();
    final existing = utilProv.waterBillItems.isNotEmpty ? utilProv.waterBillItems.first : null;

    if (existing == null) {
      // Create the utility item first, then open setup
      utilProv.addItem(
        UtilityTracker(
          id: const Uuid().v4(),
          householdId: auth.household!.id,
          type: UtilityType.waterBill,
          label: 'Water Bill',
          updatedAt: DateTime.now(),
        ),
        auth.household!.id,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final i = context.read<UtilityProvider>().waterBillItems.firstOrNull;
        if (i == null) return const SizedBox.shrink();
        return _SupWaterBillSetupSheet(item: i);
      },
    );
  }
}

class _WaterBillStatusCard extends StatelessWidget {
  final UtilityTracker item;
  final bool isOwner;
  final bool canManage;
  const _WaterBillStatusCard({required this.item, required this.isOwner, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final isAlert = item.isLowAlert;
    final status = item.waterBillPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final isPaid = status == UtilityPaymentStatus.paid;
    final days = item.waterBillDaysUntilDue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAlert
              ? [AppColors.statusVeryLow, AppColors.statusVeryLow.withValues(alpha: 0.4)]
              : [AppColors.primaryTeal.withValues(alpha: 0.1), AppColors.primaryTeal.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAlert ? AppColors.accentOrange.withValues(alpha: 0.4) : AppColors.primaryTeal.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAlert
                      ? AppColors.accentOrange.withValues(alpha: 0.15)
                      : AppColors.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.water_outlined,
                    color: isAlert ? AppColors.accentOrange : AppColors.primaryTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                    const Text('Metered Water Bill',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.statusEnoughText.withValues(alpha: 0.12)
                      : isAlert
                          ? AppColors.accentOrange.withValues(alpha: 0.12)
                          : AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPaid ? 'Paid ✓' : isAlert ? 'Due Soon' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? AppColors.statusEnoughText : isAlert ? AppColors.accentOrange : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _InfoTile(label: 'Due day', value: item.waterBillDueDayOfMonth != null ? '${item.waterBillDueDayOfMonth}th' : '—'),
              const SizedBox(width: 10),
              _InfoTile(label: 'Amount', value: item.waterBillAmount != null ? 'KSh ${item.waterBillAmount!.toStringAsFixed(0)}' : '—'),
              const SizedBox(width: 10),
              _InfoTile(label: 'Days left', value: days != null ? '$days' : '—'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.waterBillStatusMessage,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isAlert && !isPaid ? AppColors.accentOrange : isPaid ? AppColors.statusEnoughText : AppColors.textSecondary,
              fontWeight: isAlert || isPaid ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (item.waterBillMpesaTill != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${item.waterBillIsPaybill ? 'Paybill' : 'Till'} ${item.waterBillMpesaTill}'
                    '${item.waterBillMpesaAccountRef != null ? ' · ${item.waterBillMpesaAccountRef}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          // Actions
          if (canManage) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            if (isOwner) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => _SupWaterBillSetupSheet(item: item),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Setup'),
                  ),
                  if (!isPaid)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusEnoughText,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        context.read<UtilityProvider>().markWaterBillPaid(item.id, auth.household!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Water bill marked as paid'), backgroundColor: AppColors.statusEnoughText),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Paid'),
                    ),
                  if (isPaid)
                    OutlinedButton.icon(
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        context.read<UtilityProvider>().resetWaterBillCycle(item.id, auth.household!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Water bill reset for next cycle')),
                        );
                      },
                      icon: const Icon(Icons.refresh_outlined, size: 16),
                      label: const Text('Reset Cycle'),
                    ),
                ],
              ),
            ] else ...[
              // Manager: notify owner
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: item.waterBillNoteSent ? AppColors.textSecondary : AppColors.accentOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: item.waterBillNoteSent
                      ? null
                      : () async {
                          final auth = context.read<AuthProvider>();
                          final amt = item.waterBillAmount != null
                              ? 'KSh ${item.waterBillAmount!.toStringAsFixed(0)}'
                              : '';
                          final mpesa = item.waterBillMpesaTill != null
                              ? '\nM-Pesa: ${item.waterBillIsPaybill ? 'Paybill' : 'Buy Goods'} ${item.waterBillMpesaTill}'
                                '${item.waterBillMpesaAccountRef != null ? ' — Acc: ${item.waterBillMpesaAccountRef}' : ''}'
                              : '';
                          final msg = 'Hi! The water bill has arrived.'
                              '${amt.isNotEmpty ? '\nAmount: $amt' : ''}$mpesa'
                              '\nKindly arrange payment at your earliest. Thank you! 🙏';
                          await Clipboard.setData(ClipboardData(text: msg));
                          context.read<UtilityProvider>().notifyWaterBillArrived(item.id, auth.household!.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Message copied — paste it to the owner ✓'),
                                  backgroundColor: AppColors.accentOrange),
                            );
                          }
                        },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: Text(item.waterBillNoteSent ? 'Owner Notified ✓' : 'Bill Arrived — Remind Owner'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SupWaterBillSetupSheet extends StatefulWidget {
  final UtilityTracker item;
  const _SupWaterBillSetupSheet({required this.item});
  @override
  State<_SupWaterBillSetupSheet> createState() => _SupWaterBillSetupSheetState();
}

class _SupWaterBillSetupSheetState extends State<_SupWaterBillSetupSheet> {
  late final TextEditingController _dueDayCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _tillCtrl;
  late final TextEditingController _accountCtrl;
  bool _isPaybill = true;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _dueDayCtrl = TextEditingController(text: i.waterBillDueDayOfMonth?.toString() ?? '');
    _amountCtrl = TextEditingController(text: i.waterBillAmount?.toStringAsFixed(0) ?? '');
    _tillCtrl = TextEditingController(text: i.waterBillMpesaTill ?? '');
    _accountCtrl = TextEditingController(text: i.waterBillMpesaAccountRef ?? '');
    _isPaybill = i.waterBillIsPaybill;
  }

  @override
  void dispose() {
    _dueDayCtrl.dispose();
    _amountCtrl.dispose();
    _tillCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Water Bill Setup', style: Theme.of(context).textTheme.titleMedium),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dueDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Due day of month', hintText: 'e.g. 20'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Usual amount (KSh)', prefixText: 'KSh '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Paybill',
                    icon: Icons.account_balance_outlined,
                    selected: _isPaybill,
                    onTap: () => setState(() => _isPaybill = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleChip(
                    label: 'Buy Goods / Till',
                    icon: Icons.storefront_outlined,
                    selected: !_isPaybill,
                    onTap: () => setState(() => _isPaybill = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tillCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _isPaybill ? 'Paybill number' : 'Till number'),
            ),
            if (_isPaybill) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _accountCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(labelText: 'Account reference', hintText: 'e.g. meter number'),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  context.read<UtilityProvider>().setupWaterBill(
                    itemId: widget.item.id,
                    householdId: auth.household!.id,
                    billDueDayOfMonth: int.tryParse(_dueDayCtrl.text.trim()),
                    monthlyAmount: double.tryParse(_amountCtrl.text.trim()),
                    mpesaTill: _tillCtrl.text.trim().isEmpty ? null : _tillCtrl.text.trim(),
                    isPaybill: _isPaybill,
                    mpesaAccountRef: _accountCtrl.text.trim().isEmpty ? null : _accountCtrl.text.trim(),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Water bill set up ✓'), backgroundColor: AppColors.primaryTeal),
                  );
                },
                child: const Text('Save Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SERVICE CHARGE TAB
// ════════════════════════════════════════════════════════════════

class ServiceChargeTabSection extends StatelessWidget {
  final bool embedded;
  const ServiceChargeTabSection({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();
    final items = utilProv.serviceChargeItems;
    final item = items.isNotEmpty ? items.first : null;
    final canManage = auth.isOwner || auth.isHouseManager;

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        if (item == null)
          _ServiceChargeSetupPrompt(canManage: canManage, item: null)
        else if (!item.serviceChargeSetupDone)
          _ServiceChargeSetupPrompt(canManage: canManage, item: item)
        else
          _ServiceChargeStatusCard(item: item, isOwner: auth.isOwner, canManage: canManage),
      ],
    );
  }
}

class _ServiceChargeSetupPrompt extends StatelessWidget {
  final bool canManage;
  final UtilityTracker? item;
  const _ServiceChargeSetupPrompt({required this.canManage, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.withValues(alpha: 0.15),
            Colors.grey.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cleaning_services_outlined, color: Colors.grey, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Service Charge',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Monthly service charge tracking',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Track your monthly service charge — covers security, maintenance, common areas, painting, garbage collection, and more.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white, size: 18),
                label: const Text('Set Up Service Charge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onPressed: () => _showSetup(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSetup(BuildContext context) {
    final utilProv = context.read<UtilityProvider>();
    final auth = context.read<AuthProvider>();
    final existing = utilProv.serviceChargeItems.isNotEmpty ? utilProv.serviceChargeItems.first : null;

    if (existing == null) {
      utilProv.addItem(
        UtilityTracker(
          id: const Uuid().v4(),
          householdId: auth.household!.id,
          type: UtilityType.serviceCharge,
          label: 'Service Charge',
          updatedAt: DateTime.now(),
        ),
        auth.household!.id,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final i = context.read<UtilityProvider>().serviceChargeItems.firstOrNull;
        if (i == null) return const SizedBox.shrink();
        return _SupServiceChargeSetupSheet(item: i);
      },
    );
  }
}

class _ServiceChargeStatusCard extends StatelessWidget {
  final UtilityTracker item;
  final bool isOwner;
  final bool canManage;
  const _ServiceChargeStatusCard({required this.item, required this.isOwner, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final isAlert = item.isLowAlert;
    final status = item.serviceChargePaymentStatus ?? UtilityPaymentStatus.unpaid;
    final isPaid = status == UtilityPaymentStatus.paid;
    final days = item.serviceChargeDaysUntilDue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAlert
              ? [AppColors.statusVeryLow, AppColors.statusVeryLow.withValues(alpha: 0.4)]
              : [Colors.grey.withValues(alpha: 0.1), Colors.grey.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAlert ? AppColors.accentOrange.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAlert ? AppColors.accentOrange.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.cleaning_services_outlined,
                    color: isAlert ? AppColors.accentOrange : Colors.grey, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                    const Text('Service Charge',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.statusEnoughText.withValues(alpha: 0.12)
                      : isAlert
                          ? AppColors.accentOrange.withValues(alpha: 0.12)
                          : AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPaid ? 'Paid ✓' : isAlert ? 'Due Soon' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? AppColors.statusEnoughText : isAlert ? AppColors.accentOrange : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoTile(label: 'Due day', value: item.serviceChargeDueDayOfMonth != null ? '${item.serviceChargeDueDayOfMonth}th' : '—'),
              const SizedBox(width: 10),
              _InfoTile(label: 'Amount', value: item.serviceChargeAmount != null ? 'KSh ${item.serviceChargeAmount!.toStringAsFixed(0)}' : '—'),
              const SizedBox(width: 10),
              _InfoTile(label: 'Days left', value: days != null ? '$days' : '—'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.serviceChargeStatusMessage,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isAlert && !isPaid ? AppColors.accentOrange : isPaid ? AppColors.statusEnoughText : AppColors.textSecondary,
              fontWeight: isAlert || isPaid ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (item.serviceChargeMpesaTill != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${item.serviceChargeIsPaybill ? 'Paybill' : 'Till'} ${item.serviceChargeMpesaTill}'
                    '${item.serviceChargeMpesaAccountRef != null ? ' · ${item.serviceChargeMpesaAccountRef}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            if (isOwner) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => _SupServiceChargeSetupSheet(item: item),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Setup'),
                  ),
                  if (!isPaid)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusEnoughText,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        context.read<UtilityProvider>().markServiceChargePaid(item.id, auth.household!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Service charge marked as paid'), backgroundColor: AppColors.statusEnoughText),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Paid'),
                    ),
                  if (isPaid)
                    OutlinedButton.icon(
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        context.read<UtilityProvider>().resetServiceChargeCycle(item.id, auth.household!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Service charge reset for next cycle')),
                        );
                      },
                      icon: const Icon(Icons.refresh_outlined, size: 16),
                      label: const Text('Reset Cycle'),
                    ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: item.serviceChargeNoteSent ? AppColors.textSecondary : AppColors.accentOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: item.serviceChargeNoteSent
                      ? null
                      : () async {
                          final auth = context.read<AuthProvider>();
                          final amt = item.serviceChargeAmount != null
                              ? 'KSh ${item.serviceChargeAmount!.toStringAsFixed(0)}'
                              : '';
                          final mpesa = item.serviceChargeMpesaTill != null
                              ? '\nM-Pesa: ${item.serviceChargeIsPaybill ? 'Paybill' : 'Buy Goods'} ${item.serviceChargeMpesaTill}'
                                '${item.serviceChargeMpesaAccountRef != null ? ' — Acc: ${item.serviceChargeMpesaAccountRef}' : ''}'
                              : '';
                          final msg = 'Hi! The service charge bill has arrived.'
                              '${amt.isNotEmpty ? '\nAmount: $amt' : ''}$mpesa'
                              '\nKindly arrange payment at your earliest. Thank you! 🙏';
                          await Clipboard.setData(ClipboardData(text: msg));
                          context.read<UtilityProvider>().notifyServiceChargeArrived(item.id, auth.household!.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Message copied — paste it to the owner ✓'),
                                  backgroundColor: AppColors.accentOrange),
                            );
                          }
                        },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: Text(item.serviceChargeNoteSent ? 'Owner Notified ✓' : 'Bill Arrived — Remind Owner'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SupServiceChargeSetupSheet extends StatefulWidget {
  final UtilityTracker item;
  const _SupServiceChargeSetupSheet({required this.item});
  @override
  State<_SupServiceChargeSetupSheet> createState() => _SupServiceChargeSetupSheetState();
}

class _SupServiceChargeSetupSheetState extends State<_SupServiceChargeSetupSheet> {
  late final TextEditingController _dueDayCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _tillCtrl;
  late final TextEditingController _accountCtrl;
  bool _isPaybill = true;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _dueDayCtrl = TextEditingController(text: i.serviceChargeDueDayOfMonth?.toString() ?? '');
    _amountCtrl = TextEditingController(text: i.serviceChargeAmount?.toStringAsFixed(0) ?? '');
    _tillCtrl = TextEditingController(text: i.serviceChargeMpesaTill ?? '');
    _accountCtrl = TextEditingController(text: i.serviceChargeMpesaAccountRef ?? '');
    _isPaybill = i.serviceChargeIsPaybill;
  }

  @override
  void dispose() {
    _dueDayCtrl.dispose();
    _amountCtrl.dispose();
    _tillCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Service Charge Setup', style: Theme.of(context).textTheme.titleMedium),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dueDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Due day of month', hintText: 'e.g. 5'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Usual amount (KSh)', prefixText: 'KSh '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Paybill',
                    icon: Icons.account_balance_outlined,
                    selected: _isPaybill,
                    onTap: () => setState(() => _isPaybill = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleChip(
                    label: 'Buy Goods / Till',
                    icon: Icons.storefront_outlined,
                    selected: !_isPaybill,
                    onTap: () => setState(() => _isPaybill = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tillCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _isPaybill ? 'Paybill number' : 'Till number'),
            ),
            if (_isPaybill) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _accountCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(labelText: 'Account reference', hintText: 'e.g. plot/unit number'),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  context.read<UtilityProvider>().setupServiceCharge(
                    itemId: widget.item.id,
                    householdId: auth.household!.id,
                    billDueDayOfMonth: int.tryParse(_dueDayCtrl.text.trim()),
                    monthlyAmount: double.tryParse(_amountCtrl.text.trim()),
                    mpesaTill: _tillCtrl.text.trim().isEmpty ? null : _tillCtrl.text.trim(),
                    isPaybill: _isPaybill,
                    mpesaAccountRef: _accountCtrl.text.trim().isEmpty ? null : _accountCtrl.text.trim(),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Service charge set up ✓'), backgroundColor: AppColors.primaryTeal),
                  );
                },
                child: const Text('Save Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared helper widgets for the new tabs
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// UTILITY SEARCH RESULT TILE
// ═══════════════════════════════════════════════════════════════════════

class _UtilitySearchResultTile extends StatelessWidget {
  final UtilityTracker item;
  final String tabName;
  final IconData icon;
  final VoidCallback onTap;
  const _UtilitySearchResultTile({
    required this.item,
    required this.tabName,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAlert = item.isLowAlert;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isAlert
                    ? AppColors.accentOrange.withValues(alpha: 0.35)
                    : AppColors.primaryTeal.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isAlert
                        ? AppColors.accentOrange.withValues(alpha: 0.1)
                        : AppColors.primaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      size: 18,
                      color: isAlert ? AppColors.accentOrange : AppColors.primaryTeal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      Text(tabName,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (isAlert)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Alert',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentOrange)),
                  ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RENT TAB
// ═══════════════════════════════════════════════════════════════════════

class RentTabSection extends StatelessWidget {
  final bool embedded;
  const RentTabSection({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();
    final items = utilProv.rentItems;
    final item = items.isNotEmpty ? items.first : null;
    final canManage = auth.isOwner || auth.isHouseManager;

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        if (item == null)
          _RentSetupPrompt(canManage: canManage, item: null)
        else if (!item.rentSetupDone)
          _RentSetupPrompt(canManage: canManage, item: item)
        else
          _RentStatusCard(item: item, isOwner: auth.isOwner, canManage: canManage),
      ],
    );
  }
}

class _RentSetupPrompt extends StatelessWidget {
  final bool canManage;
  final UtilityTracker? item;
  const _RentSetupPrompt({required this.canManage, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryTeal.withValues(alpha: 0.15),
            AppColors.primaryTeal.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.home_outlined, color: AppColors.primaryTeal, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('Monthly rent payment tracking', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Track your monthly rent — get due-date reminders, record your landlord details, and mark payments on time.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.home_outlined, color: Colors.white, size: 18),
                label: const Text('Set Up Rent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onPressed: () => _showSetup(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSetup(BuildContext context) {
    final utilProv = context.read<UtilityProvider>();
    final auth = context.read<AuthProvider>();
    final existing = utilProv.rentItems.isNotEmpty ? utilProv.rentItems.first : null;

    if (existing == null) {
      utilProv.addItem(
        UtilityTracker(
          id: const Uuid().v4(),
          householdId: auth.household!.id,
          type: UtilityType.rent,
          label: 'Monthly Rent',
          updatedAt: DateTime.now(),
        ),
        auth.household!.id,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final i = context.read<UtilityProvider>().rentItems.firstOrNull;
        if (i == null) return const SizedBox.shrink();
        return _SupRentSetupSheet(item: i);
      },
    );
  }
}

class _RentStatusCard extends StatelessWidget {
  final UtilityTracker item;
  final bool isOwner;
  final bool canManage;
  const _RentStatusCard({required this.item, required this.isOwner, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final isAlert = item.isLowAlert;
    final status = item.rentPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final isPaid = status == UtilityPaymentStatus.paid;
    final days = item.rentDaysUntilDue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAlert
              ? [AppColors.statusVeryLow, AppColors.statusVeryLow.withValues(alpha: 0.4)]
              : [AppColors.primaryTeal.withValues(alpha: 0.08), AppColors.primaryTeal.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAlert ? AppColors.accentOrange.withValues(alpha: 0.4) : AppColors.primaryTeal.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAlert ? AppColors.accentOrange.withValues(alpha: 0.15) : AppColors.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.home_outlined,
                    color: isAlert ? AppColors.accentOrange : AppColors.primaryTeal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                    if (item.rentLandlordName != null)
                      Text(item.rentLandlordName!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    else
                      const Text('Rent', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.statusEnoughText.withValues(alpha: 0.12)
                      : isAlert
                          ? AppColors.accentOrange.withValues(alpha: 0.12)
                          : AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPaid ? 'Paid ✓' : isAlert ? 'Due Soon' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? AppColors.statusEnoughText : isAlert ? AppColors.accentOrange : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoTile(label: 'Due day', value: item.rentDueDayOfMonth != null ? '${item.rentDueDayOfMonth}th' : '—'),
              const SizedBox(width: 10),
              _InfoTile(label: 'Amount', value: item.rentAmount != null ? 'KSh ${item.rentAmount!.toStringAsFixed(0)}' : '—'),
              const SizedBox(width: 10),
              _InfoTile(label: 'Days left', value: days != null ? '$days' : '—'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.rentStatusMessage,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isAlert && !isPaid ? AppColors.accentOrange : isPaid ? AppColors.statusEnoughText : AppColors.textSecondary,
              fontWeight: isAlert || isPaid ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (item.rentMpesaTill != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${item.rentIsPaybill ? 'Paybill' : 'Till'} ${item.rentMpesaTill}'
                    '${item.rentMpesaAccountRef != null ? ' · ${item.rentMpesaAccountRef}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            if (isOwner) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => _SupRentSetupSheet(item: item),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Setup'),
                  ),
                  if (!isPaid)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusEnoughText,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        context.read<UtilityProvider>().markRentPaid(item.id, auth.household!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rent marked as paid'), backgroundColor: AppColors.statusEnoughText),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Paid'),
                    ),
                  if (isPaid)
                    OutlinedButton.icon(
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        context.read<UtilityProvider>().resetRentCycle(item.id, auth.household!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rent reset for next cycle')),
                        );
                      },
                      icon: const Icon(Icons.refresh_outlined, size: 16),
                      label: const Text('Reset Cycle'),
                    ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: item.rentNoteSent ? AppColors.textSecondary : AppColors.accentOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: item.rentNoteSent
                      ? null
                      : () async {
                          final auth = context.read<AuthProvider>();
                          final amt = item.rentAmount != null
                              ? 'KSh ${item.rentAmount!.toStringAsFixed(0)}'
                              : '';
                          final landlord = (item.rentLandlordName?.trim().isNotEmpty ?? false)
                              ? ' to ${item.rentLandlordName}'
                              : '';
                          final mpesa = item.rentMpesaTill != null
                              ? '\nM-Pesa: ${item.rentIsPaybill ? 'Paybill' : 'Buy Goods'} ${item.rentMpesaTill}'
                                '${item.rentMpesaAccountRef != null ? ' — Acc: ${item.rentMpesaAccountRef}' : ''}'
                              : '';
                          final msg = 'Hi! Rent is due this month$landlord.'
                              '${amt.isNotEmpty ? '\nAmount: $amt' : ''}$mpesa'
                              '\nKindly arrange payment at your earliest. Thank you! 🙏';
                          await Clipboard.setData(ClipboardData(text: msg));
                          context.read<UtilityProvider>().notifyRentDue(item.id, auth.household!.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Message copied — paste it to the owner ✓'),
                                  backgroundColor: AppColors.accentOrange),
                            );
                          }
                        },
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: Text(item.rentNoteSent ? 'Owner Notified ✓' : 'Rent Due — Remind Owner'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SupRentSetupSheet extends StatefulWidget {
  final UtilityTracker item;
  const _SupRentSetupSheet({required this.item});
  @override
  State<_SupRentSetupSheet> createState() => _SupRentSetupSheetState();
}

class _SupRentSetupSheetState extends State<_SupRentSetupSheet> {
  late final TextEditingController _dueDayCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _landlordCtrl;
  late final TextEditingController _tillCtrl;
  late final TextEditingController _accountCtrl;
  bool _isPaybill = true;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _dueDayCtrl = TextEditingController(text: i.rentDueDayOfMonth?.toString() ?? '');
    _amountCtrl = TextEditingController(text: i.rentAmount?.toStringAsFixed(0) ?? '');
    _landlordCtrl = TextEditingController(text: i.rentLandlordName ?? '');
    _tillCtrl = TextEditingController(text: i.rentMpesaTill ?? '');
    _accountCtrl = TextEditingController(text: i.rentMpesaAccountRef ?? '');
    _isPaybill = i.rentIsPaybill;
  }

  @override
  void dispose() {
    _dueDayCtrl.dispose(); _amountCtrl.dispose(); _landlordCtrl.dispose();
    _tillCtrl.dispose(); _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rent Setup', style: Theme.of(context).textTheme.titleMedium),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _landlordCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Landlord / Agent name (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dueDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Due day of month', hintText: 'e.g. 1'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Monthly rent (KSh)', prefixText: 'KSh '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Paybill',
                    icon: Icons.account_balance_outlined,
                    selected: _isPaybill,
                    onTap: () => setState(() => _isPaybill = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleChip(
                    label: 'Buy Goods / Till',
                    icon: Icons.storefront_outlined,
                    selected: !_isPaybill,
                    onTap: () => setState(() => _isPaybill = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tillCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _isPaybill ? 'Paybill number' : 'Till number'),
            ),
            if (_isPaybill) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _accountCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(labelText: 'Account reference (e.g. unit number)'),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  context.read<UtilityProvider>().setupRent(
                    itemId: widget.item.id,
                    householdId: auth.household!.id,
                    billDueDayOfMonth: int.tryParse(_dueDayCtrl.text.trim()),
                    monthlyAmount: double.tryParse(_amountCtrl.text.trim()),
                    landlordName: _landlordCtrl.text.trim().isEmpty ? null : _landlordCtrl.text.trim(),
                    mpesaTill: _tillCtrl.text.trim().isEmpty ? null : _tillCtrl.text.trim(),
                    isPaybill: _isPaybill,
                    mpesaAccountRef: _accountCtrl.text.trim().isEmpty ? null : _accountCtrl.text.trim(),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rent set up ✓'), backgroundColor: AppColors.primaryTeal),
                  );
                },
                child: const Text('Save Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PAY TV TAB
// ═══════════════════════════════════════════════════════════════════════

class PayTvTabSection extends StatelessWidget {
  final bool embedded;
  const PayTvTabSection({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final utilProv = context.watch<UtilityProvider>();
    final auth = context.watch<AuthProvider>();
    final items = utilProv.payTvItems;
    final item = items.isNotEmpty ? items.first : null;
    final canManage = auth.isOwner || auth.isHouseManager;

    return ListView(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [
        if (item == null)
          _PayTvSetupPrompt(canManage: canManage, item: null)
        else if (!item.payTvSetupDone)
          _PayTvSetupPrompt(canManage: canManage, item: item)
        else
          _PayTvStatusCard(item: item, isOwner: auth.isOwner, canManage: canManage),
      ],
    );
  }
}

class _PayTvSetupPrompt extends StatelessWidget {
  final bool canManage;
  final UtilityTracker? item;
  const _PayTvSetupPrompt({required this.canManage, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withValues(alpha: 0.12),
            Colors.purple.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tv_outlined, color: Colors.purple, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pay TV', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('DSTV, Zuku TV, StarTimes & more', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Track your Pay TV subscription — get renewal reminders so your decoder never goes off unexpectedly.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          if (canManage) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.tv_outlined, color: Colors.white, size: 18),
                label: const Text('Set Up Pay TV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onPressed: () => _showSetup(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSetup(BuildContext context) {
    final utilProv = context.read<UtilityProvider>();
    final auth = context.read<AuthProvider>();
    final existing = utilProv.payTvItems.isNotEmpty ? utilProv.payTvItems.first : null;

    if (existing == null) {
      utilProv.addItem(
        UtilityTracker(
          id: const Uuid().v4(),
          householdId: auth.household!.id,
          type: UtilityType.payTv,
          label: 'Pay TV',
          updatedAt: DateTime.now(),
        ),
        auth.household!.id,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final i = context.read<UtilityProvider>().payTvItems.firstOrNull;
        if (i == null) return const SizedBox.shrink();
        return _SupPayTvSetupSheet(item: i);
      },
    );
  }
}

class _PayTvStatusCard extends StatelessWidget {
  final UtilityTracker item;
  final bool isOwner;
  final bool canManage;
  const _PayTvStatusCard({required this.item, required this.isOwner, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final isAlert = item.isLowAlert;
    final status = item.payTvPaymentStatus ?? UtilityPaymentStatus.unpaid;
    final isPaid = status == UtilityPaymentStatus.paid;
    final days = item.payTvDaysUntilDue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAlert
              ? [AppColors.statusVeryLow, AppColors.statusVeryLow.withValues(alpha: 0.4)]
              : [Colors.purple.withValues(alpha: 0.08), Colors.purple.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAlert ? AppColors.accentOrange.withValues(alpha: 0.4) : Colors.purple.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAlert ? AppColors.accentOrange.withValues(alpha: 0.15) : Colors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.tv_outlined,
                    color: isAlert ? AppColors.accentOrange : Colors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
                    Text(item.payTvProvider ?? 'Pay TV',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppColors.statusEnoughText.withValues(alpha: 0.12)
                      : isAlert
                          ? AppColors.accentOrange.withValues(alpha: 0.12)
                          : AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPaid ? 'Paid ✓' : isAlert ? 'Due Soon' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPaid ? AppColors.statusEnoughText : isAlert ? AppColors.accentOrange : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoTile(label: 'Due day', value: item.payTvDueDayOfMonth != null ? '${item.payTvDueDayOfMonth}th' : '—'),
              const SizedBox(width: 10),
              _InfoTile(label: 'Monthly', value: item.payTvMonthlyAmount != null ? 'KSh ${item.payTvMonthlyAmount!.toStringAsFixed(0)}' : '—'),
              const SizedBox(width: 10),
              _InfoTile(label: 'Days left', value: days != null ? '$days' : '—'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.payTvStatusMessage,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isAlert && !isPaid ? AppColors.accentOrange : isPaid ? AppColors.statusEnoughText : AppColors.textSecondary,
              fontWeight: isAlert || isPaid ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (item.payTvMpesaTill != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android_outlined, size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${item.payTvIsPaybill ? 'Paybill' : 'Till'} ${item.payTvMpesaTill}'
                    '${item.payTvMpesaAccountRef != null ? ' · ${item.payTvMpesaAccountRef}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            if (isOwner) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => _SupPayTvSetupSheet(item: item),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Setup'),
                  ),
                  if (!isPaid)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        context.read<UtilityProvider>().markPayTvPaid(item.id, auth.household!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pay TV marked as paid'), backgroundColor: Colors.purple),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Paid'),
                    ),
                  if (isPaid)
                    OutlinedButton.icon(
                      onPressed: () {
                        final auth = context.read<AuthProvider>();
                        context.read<UtilityProvider>().resetPayTvCycle(item.id, auth.household!.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pay TV reset for next cycle')),
                        );
                      },
                      icon: const Icon(Icons.refresh_outlined, size: 16),
                      label: const Text('Reset Cycle'),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SupPayTvSetupSheet extends StatefulWidget {
  final UtilityTracker item;
  const _SupPayTvSetupSheet({required this.item});
  @override
  State<_SupPayTvSetupSheet> createState() => _SupPayTvSetupSheetState();
}

class _SupPayTvSetupSheetState extends State<_SupPayTvSetupSheet> {
  late final TextEditingController _providerCtrl;
  late final TextEditingController _dueDayCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _tillCtrl;
  late final TextEditingController _accountCtrl;
  bool _isPaybill = false;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _providerCtrl = TextEditingController(text: i.payTvProvider ?? '');
    _dueDayCtrl = TextEditingController(text: i.payTvDueDayOfMonth?.toString() ?? '');
    _amountCtrl = TextEditingController(text: i.payTvMonthlyAmount?.toStringAsFixed(0) ?? '');
    _tillCtrl = TextEditingController(text: i.payTvMpesaTill ?? '');
    _accountCtrl = TextEditingController(text: i.payTvMpesaAccountRef ?? '');
    _isPaybill = i.payTvIsPaybill;
  }

  @override
  void dispose() {
    _providerCtrl.dispose(); _dueDayCtrl.dispose(); _amountCtrl.dispose();
    _tillCtrl.dispose(); _accountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pay TV Setup', style: Theme.of(context).textTheme.titleMedium),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _providerCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Provider (e.g. DSTV, Zuku TV, StarTimes)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dueDayCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Due day of month', hintText: 'e.g. 15'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Monthly amount (KSh)', prefixText: 'KSh '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Paybill',
                    icon: Icons.account_balance_outlined,
                    selected: _isPaybill,
                    onTap: () => setState(() => _isPaybill = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ToggleChip(
                    label: 'Buy Goods / Till',
                    icon: Icons.storefront_outlined,
                    selected: !_isPaybill,
                    onTap: () => setState(() => _isPaybill = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tillCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _isPaybill ? 'Paybill number' : 'Till number'),
            ),
            if (_isPaybill) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _accountCtrl,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(labelText: 'Account reference (e.g. Smart Card No.)'),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final auth = context.read<AuthProvider>();
                  context.read<UtilityProvider>().setupPayTv(
                    itemId: widget.item.id,
                    householdId: auth.household!.id,
                    providerName: _providerCtrl.text.trim().isEmpty ? null : _providerCtrl.text.trim(),
                    dueDayOfMonth: int.tryParse(_dueDayCtrl.text.trim()),
                    monthlyAmount: double.tryParse(_amountCtrl.text.trim()),
                    mpesaTill: _tillCtrl.text.trim().isEmpty ? null : _tillCtrl.text.trim(),
                    isPaybill: _isPaybill,
                    mpesaAccountRef: _accountCtrl.text.trim().isEmpty ? null : _accountCtrl.text.trim(),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pay TV set up ✓'), backgroundColor: AppColors.primaryTeal),
                  );
                },
                child: const Text('Save Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
