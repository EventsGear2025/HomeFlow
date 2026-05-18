import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/supply_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/laundry_provider.dart';
import '../../providers/staff_provider.dart';
import '../../providers/utility_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/ad_provider.dart';
import '../../models/ad_offer.dart';
import '../../models/shopping_request.dart';
import 'package:uuid/uuid.dart';
import '../../models/meal_log.dart';
import '../../models/task_item.dart';
import '../../models/supply_item.dart';
import '../../utils/app_colors.dart';
import '../../utils/home_pro_intelligence.dart';
import '../../utils/smart_tips_engine.dart';
import '../../utils/upgrade_flow.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/smart_tips_section.dart';
import '../../widgets/status_chips.dart';
import 'home_pro_analytics_screen.dart';
import '../notifications/notifications_screen.dart';
import '../staff/staff_screen.dart';
import '../utilities/utilities_screen.dart';
import '../supplies/supplies_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatelessWidget {
  final void Function(int index)? onNavigate;
  static final GlobalKey<ScaffoldState> shellScaffoldKey =
      GlobalKey<ScaffoldState>();

  const DashboardScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final supply = context.watch<SupplyProvider>();
    final meals = context.watch<MealProvider>();
    final laundry = context.watch<LaundryProvider>();
    final staff = context.watch<StaffProvider>();
    final utilities = context.watch<UtilityProvider>();
    final notifications = context.watch<NotificationProvider>();

    final user = auth.currentUser;
    final household = auth.household;
    final firstName = user?.fullName.split(' ').first ?? 'there';
    final visibleSupplies = supply.visibleSupplies(isOwner: auth.isOwner);
    final visibleUtilities = utilities.visibleItems(isOwner: auth.isOwner);

    final lowStockItems = supply.lowStockItems(isOwner: auth.isOwner);
    final pendingRequests = supply.pendingRequests;
    final activeLaundry = laundry.activeItems;
    final todayMeals = meals.getTodaysMeals();
    final missingPriceLogs = [
      ...supply.historyRequests.where((request) => request.pricePaid == null),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final children = context.watch<ChildProvider>().children;
    final unread = notifications.unreadCount;
    final homeProTips = SmartTipsEngine.allTips(
      meals: meals.mealLogs,
      laundry: laundry.items,
      supplies: visibleSupplies,
      utilities: visibleUtilities,
    );
    final intelligence = HomeProIntelligenceEngine.build(
      meals: meals.mealLogs,
      laundry: laundry.items,
      supplies: visibleSupplies,
      utilities: visibleUtilities,
      householdMembers: auth.householdMembers.length,
      childrenCount: children.length,
    );
    final analyticsHighlights = auth.isHomePro
        ? <String>[
            intelligence.watchpointCount == 0
                ? 'Calm week ahead'
                : '${intelligence.watchpointCount} live watchpoint${intelligence.watchpointCount == 1 ? '' : 's'}',
            homeProTips.isEmpty
                ? 'No urgent blind spots'
                : '${homeProTips.length} smart tip${homeProTips.length == 1 ? '' : 's'}',
            'Meals + laundry + bills',
          ]
        : const <String>[
            'Home pulse score',
            '7-day pressure map',
            'Household archetype',
          ];

    void openHomeProIntelligence() {
      if (auth.isHomePro) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeProAnalyticsScreen(),
          ),
        );
        return;
      }
      openHomeProUpgrade(
        context,
        source: 'dashboard_home_pro_intelligence',
      );
    }

    void openPriceLogReminder() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MissingPriceLogSheet(requests: missingPriceLogs),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primaryTeal,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
              ),
            ),
            title: Text(
              household?.householdName ?? 'homeFlow',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: const BoxDecoration(
                          color: AppColors.accentOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.uiBlue, AppColors.primaryTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              (user?.fullName.isNotEmpty == true)
                                  ? user!.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good ${_greeting()}, $firstName 👋',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.home_outlined,
                                    color: Colors.white60,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    household?.householdName ??
                                        'Your Household',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _RolePill(
                                    label: auth.isOwner ? 'Owner' : 'Manager',
                                  ),
                                  const SizedBox(width: 6),
                                  HomePlanBadge(
                                    label: auth.householdPlanLabel,
                                    isPro: auth.isHomePro,
                                    useLightText: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _HeaderPill(
                            icon: Icons.inventory_2_outlined,
                            label: '${lowStockItems.length} low stock',
                            urgent: lowStockItems.isNotEmpty,
                          ),
                          const SizedBox(width: 7),
                          _HeaderPill(
                            icon: Icons.restaurant_outlined,
                            label:
                                '${todayMeals.length} meal${todayMeals.length == 1 ? '' : 's'} today',
                            urgent: false,
                          ),
                          const SizedBox(width: 7),
                          _HeaderPill(
                            icon: Icons.local_laundry_service_outlined,
                            label: '${activeLaundry.length} laundry',
                            urgent: false,
                          ),
                          if (pendingRequests.isNotEmpty) ...[
                            const SizedBox(width: 7),
                            _HeaderPill(
                              icon: Icons.shopping_cart_outlined,
                              label: '${pendingRequests.length} pending',
                              urgent: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── BODY ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions
                  const _SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  _QuickActionsRow(
                    isOwner: auth.isOwner,
                    onNavigate: onNavigate,
                  ),

                  const SizedBox(height: 16),

                  // Sponsored ad strip
                  const _AdBannerStrip(),

                  const SizedBox(height: 16),

                  // Home Status
                  const _SectionHeader(title: 'Home Status'),
                  const SizedBox(height: 12),
                  _HomeStatusStrip(
                    supply: supply,
                    laundry: laundry,
                    utilities: utilities,
                    isOwner: auth.isOwner,
                    onSupplies: () => onNavigate?.call(1),
                    onLaundry: () => onNavigate?.call(3),
                    onUtilities: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UtilitiesScreen(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'Analytics',
                    action: auth.isHomePro ? 'Open' : 'Unlock',
                    onAction: openHomeProIntelligence,
                  ),
                  const SizedBox(height: 12),
                  PremiumAnalyticsEntryCard(
                    title: 'Home Pro Intelligence',
                    subtitle: auth.isHomePro
                        ? 'One premium surface for your home pulse, pressure map, household archetype, and this week\'s next best move.'
                        : 'Unlock a premium household operating view built from meals, laundry, supplies, and utilities.',
                    icon: Icons.auto_awesome_mosaic_rounded,
                    highlights: analyticsHighlights,
                    isUnlocked: auth.isHomePro,
                    supportingPanel: missingPriceLogs.isEmpty
                        ? null
                        : _HomeProPriceReminderInline(
                            requests: missingPriceLogs,
                            isHomePro: auth.isHomePro,
                            onReview: openPriceLogReminder,
                          ),
                    unlockedLabel: 'Open Home Pro Intelligence',
                    onPressed: openHomeProIntelligence,
                  ),
                  if (auth.isHomePro) ...[
                    const SizedBox(height: 20),
                    const _SectionHeader(title: 'Smart Insights'),
                    const SizedBox(height: 12),
                    SmartTipsDashboardStrip(
                      tips: homeProTips,
                      onViewAll: openHomeProIntelligence,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Today's Meals
                  _SectionHeader(
                    title: "Today's Meals",
                    action: 'Log meal',
                    onAction: () => onNavigate?.call(4),
                  ),
                  const SizedBox(height: 12),
                  _MealsCard(meals: todayMeals),

                  const SizedBox(height: 28),

                  // Shopping Requests
                  if (pendingRequests.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Shopping Requests',
                      action: 'View all',
                      onAction: () => onNavigate?.call(2),
                    ),
                    const SizedBox(height: 12),
                    _ShoppingRequestCard(
                      count: pendingRequests.length,
                      onTap: () => onNavigate?.call(2),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Kids
                  if (children.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Kids & School',
                      action: 'View',
                      onAction: () => onNavigate?.call(5),
                    ),
                    const SizedBox(height: 12),
                    _KidsCard(children: children),
                    const SizedBox(height: 8),
                    _SchoolNeedsBanner(onTap: () => onNavigate?.call(5)),
                    const SizedBox(height: 28),
                  ],

                  // Staff — owner only
                  if (auth.isOwner) ...[
                    _SectionHeader(
                      title: 'Staff',
                      action: 'Manage',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StaffScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _StaffCard(schedule: staff.schedule),
                    const SizedBox(height: 28),
                  ],

                  // Today's Tasks — visible to both owner and manager
                  _SectionHeader(
                    title: "Today's Tasks",
                    action: 'View all',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StaffScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TasksPreviewCard(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE PILL
// ─────────────────────────────────────────────────────────────────────────────

class _RolePill extends StatelessWidget {
  final String label;
  const _RolePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER PILL
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool urgent;

  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: urgent
            ? AppColors.accentOrange.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: urgent
              ? AppColors.accentOrange.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: urgent ? AppColors.accentOrange : Colors.white70,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: urgent ? AppColors.accentOrange : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const Spacer(),
        if (action != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: AppColors.primaryTeal,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeProPriceReminderInline extends StatelessWidget {
  final List<ShoppingRequest> requests;
  final bool isHomePro;
  final VoidCallback onReview;

  const _HomeProPriceReminderInline({
    required this.requests,
    required this.isHomePro,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final preview = requests.take(2).toList();
    final missingCount = requests.length;
    final title = missingCount == 1
        ? '1 bought item still needs its price'
        : '$missingCount bought items still need prices';
    final subtitle = isHomePro
        ? 'Home Pro works better when bought items have prices logged. That keeps spend and refill analytics accurate.'
        : 'Log these prices now so Home Pro can give sharper analytics when you need them.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.tipAlert.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tipAlert.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.tipAlert,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final request in preview)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.tipAlert.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      request.itemName,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                if (requests.length > preview.length)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.tipAlert.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      '+${requests.length - preview.length} more',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.tipAlert,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onReview,
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text(
                'Review unlogged items',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingPriceLogSheet extends StatefulWidget {
  final List<ShoppingRequest> requests;

  const _MissingPriceLogSheet({required this.requests});

  @override
  State<_MissingPriceLogSheet> createState() => _MissingPriceLogSheetState();
}

class _MissingPriceLogSheetState extends State<_MissingPriceLogSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _savingIds = <String>{};
  late List<ShoppingRequest> _pendingRequests;

  @override
  void initState() {
    super.initState();
    _pendingRequests = List<ShoppingRequest>.from(widget.requests);
    for (final request in widget.requests) {
      _controllers[request.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveItem(ShoppingRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    final supply = context.read<SupplyProvider>();
    final controller = _controllers[request.id];
    final rawValue = controller?.text.trim().replaceAll(',', '') ?? '';
    final parsed = double.tryParse(rawValue);

    if (parsed == null || parsed <= 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('Enter a valid price for ${request.itemName}.')),
      );
      return;
    }

    setState(() => _savingIds.add(request.id));

    try {
      await supply.replaceRequest(
        request.copyWith(pricePaid: parsed),
        request.householdId,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingIds.remove(request.id));
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save price for ${request.itemName}.')),
      );
      return;
    }

    if (!mounted) return;
    final itemName = request.itemName;
    setState(() {
      _savingIds.remove(request.id);
      _pendingRequests.removeWhere((item) => item.id == request.id);
      _controllers.remove(request.id)?.dispose();
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved price for $itemName.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.52,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: _pendingRequests.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle_rounded,
                                  size: 40,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'All missing prices are logged',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Home Pro can now use those purchases for cleaner spend and refill analytics.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Done',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            18,
                            20,
                            MediaQuery.of(context).viewInsets.bottom + 28,
                          ),
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.tipAlert.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: AppColors.tipAlert,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Finish your price logs',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _pendingRequests.length == 1
                                            ? '1 bought item still needs a price.'
                                            : '${_pendingRequests.length} bought items still need prices.',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.tipAlertBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.tipAlert.withValues(alpha: 0.14),
                                ),
                              ),
                              child: const Text(
                                'Log each amount and tap Done. The item will leave this list immediately, and Home Pro analytics will get better data to work with.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (final request in _pendingRequests) ...[
                              _MissingPriceEntryRow(
                                request: request,
                                controller: _controllers[request.id]!,
                                isSaving: _savingIds.contains(request.id),
                                onDone: () => _saveItem(request),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close for now'),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MissingPriceEntryRow extends StatelessWidget {
  final ShoppingRequest request;
  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onDone;

  const _MissingPriceEntryRow({
    required this.request,
    required this.controller,
    required this.isSaving,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
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
                      request.itemName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.quantity} • ${_relativeLogTime(request.updatedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.tipAlertBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Missing price',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tipAlert,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => onDone(),
            decoration: InputDecoration(
              labelText: 'Price paid (KES)',
              hintText: 'e.g. 350',
              prefixText: 'KES ',
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(92, 38),
              ),
              onPressed: isSaving ? null : onDone,
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeLogTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays >= 7) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? 'bought 1 week ago' : 'bought $weeks weeks ago';
    }
    if (difference.inDays >= 1) {
      return difference.inDays == 1
          ? 'bought yesterday'
          : 'bought ${difference.inDays} days ago';
    }
    if (difference.inHours >= 1) {
      return difference.inHours == 1
          ? 'bought 1 hour ago'
          : 'bought ${difference.inHours} hours ago';
    }
    return 'bought today';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final int lowStockCount;
  final int pendingCount;
  final VoidCallback onTap;

  const _AlertBanner({
    required this.lowStockCount,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (lowStockCount > 0)
        '$lowStockCount item${lowStockCount > 1 ? 's' : ''} low on stock',
      if (pendingCount > 0)
        '$pendingCount shopping request${pendingCount > 1 ? 's' : ''} pending',
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accentOrange.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.accentOrange,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Needs Attention',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentOrange,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    parts.join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.accentOrange,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS ROW (scrollable)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  final bool isOwner;
  final void Function(int)? onNavigate;

  const _QuickActionsRow({required this.isOwner, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final items = isOwner
        ? [
            _QA(
              Icons.inventory_2_outlined,
              'Supplies',
              AppColors.primaryTeal,
              () => onNavigate?.call(1),
            ),
            _QA(
              Icons.check_circle_outline,
              'Approve',
              AppColors.accentOrange,
              () => onNavigate?.call(2),
            ),
            _QA(
              Icons.local_fire_department_outlined,
              'Utilities',
              AppColors.utilitiesOrange,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UtilitiesScreen()),
              ),
            ),
            _QA(
              Icons.local_laundry_service_outlined,
              'Laundry',
              AppColors.secondaryTeal,
              () => onNavigate?.call(3),
            ),
            _QA(
              Icons.restaurant_outlined,
              'Meals',
              AppColors.statusLowText,
              () => onNavigate?.call(4),
            ),
            _QA(
              Icons.badge_outlined,
              'Staff',
              AppColors.textSecondary,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffScreen()),
              ),
            ),
          ]
        : [
            _QA(
              Icons.inventory_2_outlined,
              'Supplies',
              AppColors.primaryTeal,
              () => onNavigate?.call(1),
            ),
            _QA(
              Icons.shopping_cart_outlined,
              'Request',
              AppColors.accentOrange,
              () => onNavigate?.call(2),
            ),
            _QA(
              Icons.local_fire_department_outlined,
              'Utilities',
              AppColors.utilitiesOrange,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UtilitiesScreen()),
              ),
            ),
            _QA(
              Icons.local_laundry_service_outlined,
              'Laundry',
              AppColors.secondaryTeal,
              () => onNavigate?.call(3),
            ),
            _QA(
              Icons.restaurant_outlined,
              'Meals',
              AppColors.statusLowText,
              () => onNavigate?.call(4),
            ),
            _QA(
              Icons.child_care_outlined,
              'Kids',
              AppColors.primaryTeal,
              () => onNavigate?.call(5),
            ),
          ];

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = items[i];
          return GestureDetector(
            onTap: a.onTap,
            child: Container(
              width: 74,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: a.color.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: a.color.withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(a.icon, color: a.color, size: 19),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    a.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: a.color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QA {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QA(this.icon, this.label, this.color, this.onTap);
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME STATUS STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _HomeStatusStrip extends StatelessWidget {
  final SupplyProvider supply;
  final LaundryProvider laundry;
  final UtilityProvider utilities;
  final bool isOwner;
  final VoidCallback onSupplies;
  final VoidCallback onLaundry;
  final VoidCallback onUtilities;

  const _HomeStatusStrip({
    required this.supply,
    required this.laundry,
    required this.utilities,
    required this.isOwner,
    required this.onSupplies,
    required this.onLaundry,
    required this.onUtilities,
  });

  @override
  Widget build(BuildContext context) {
    final lowStock = supply.lowStockItems(isOwner: isOwner).length;
    final active = laundry.activeItems.length;
    // Filter utility alerts: managers must not see owner-only items
    final utilAlerts = utilities.lowAlertItems
        .where((i) => isOwner || !i.isOwnerOnly)
        .length;

    return Row(
      children: [
        Expanded(
          child: _StatusTile(
            icon: Icons.inventory_2_outlined,
            label: 'Supplies',
            value: lowStock == 0 ? 'All good' : '$lowStock low',
            isAlert: lowStock > 0,
            onTap: onSupplies,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusTile(
            icon: Icons.local_laundry_service_outlined,
            label: 'Laundry',
            value: active == 0 ? 'Clear' : '$active active',
            isAlert: false,
            onTap: onLaundry,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusTile(
            icon: Icons.bolt_outlined,
            label: 'Utilities',
            value: utilAlerts == 0 ? 'All OK' : '$utilAlerts alert',
            isAlert: utilAlerts > 0,
            onTap: onUtilities,
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isAlert;
  final VoidCallback onTap;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isAlert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = isAlert
        ? AppColors.accentOrange
        : AppColors.primaryTeal;
    final Color bg = isAlert
        ? AppColors.accentOrange.withValues(alpha: 0.07)
        : AppColors.primaryTeal.withValues(alpha: 0.06);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAlert
                ? AppColors.accentOrange.withValues(alpha: 0.25)
                : AppColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 17),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isAlert ? AppColors.accentOrange : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEALS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MealsCard extends StatelessWidget {
  final List<MealLog> meals;
  const _MealsCard({required this.meals});

  @override
  Widget build(BuildContext context) {
    if (meals.isEmpty) {
      return _EmptyCard(
        icon: Icons.restaurant_outlined,
        message: 'No meals logged yet today',
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.statusLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_outlined,
                  color: AppColors.statusLowText,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${meals.length} meal${meals.length > 1 ? 's' : ''} logged today',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: meals
                .map(
                  (m) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.secondaryTeal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      m.mealPeriod,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w600,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOPPING REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ShoppingRequestCard extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  const _ShoppingRequestCard({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentYellow.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: AppColors.accentOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count pending request${count > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Tap to view and approve',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPLY ROW
// ─────────────────────────────────────────────────────────────────────────────

class _SupplyRow extends StatelessWidget {
  final SupplyItem item;
  const _SupplyRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.statusVeryLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.accentOrange,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            StatusChip.fromSupplyStatus(item.status),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KIDS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _KidsCard extends StatelessWidget {
  final List<dynamic> children;
  const _KidsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final childProvider = context.watch<ChildProvider>();
    final logs = children
        .map((child) => childProvider.getTodaysLog(child.id))
        .toList();
    final readyCount = logs
        .where((log) => (log?.checkedCount ?? 0) >= 4)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.statusEnough,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: AppColors.statusEnoughText,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'School readiness',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$readyCount / ${children.length} ready today',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ReadinessChip(
                isReady: readyCount == children.length,
                label: readyCount == children.length
                    ? 'All Ready'
                    : 'In Progress',
              ),
            ],
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            Row(
              children: children.take(4).map<Widget>((child) {
                final log = childProvider.getTodaysLog(child.id);
                final ready = (log?.checkedCount ?? 0) >= 4;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: ready
                                ? AppColors.statusEnough
                                : AppColors.surfaceLight,
                            child: Text(
                              child.name[0].toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: ready
                                    ? AppColors.statusEnoughText
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (ready)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 13,
                                height: 13,
                                decoration: const BoxDecoration(
                                  color: AppColors.statusEnoughText,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        child.name.split(' ').first,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAFF CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final dynamic schedule;
  const _StaffCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final isOnDuty = schedule?.isOnDuty ?? true;
    final name = schedule?.userName ?? 'Not assigned';
    final statusLabel = schedule == null
        ? 'On Duty'
        : _fmtStatus(schedule.workStatus.toString().split('.').last);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOnDuty
                  ? AppColors.statusEnough
                  : AppColors.statusVeryLow,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isOnDuty
                      ? AppColors.statusEnoughText
                      : AppColors.accentOrange,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'House Manager',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ReadinessChip(
            isReady: isOnDuty,
            label: isOnDuty ? 'On Duty' : statusLabel,
          ),
        ],
      ),
    );
  }

  String _fmtStatus(String raw) {
    return raw
        .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}')
        .trim()
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OWNER PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _OwnerPanel extends StatelessWidget {
  final int pendingCount;
  final int lowStockCount;
  final String planType;
  final bool isHomePro;
  final VoidCallback? onShoppingTap;

  const _OwnerPanel({
    required this.pendingCount,
    required this.lowStockCount,
    required this.planType,
    required this.isHomePro,
    this.onShoppingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.home_outlined,
                size: 16,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(width: 7),
              const Text(
                'Household Overview',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              HomePlanBadge(label: planType, isPro: isHomePro),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          _PanelRow(
            icon: Icons.check_circle_outline,
            label: pendingCount > 0
                ? '$pendingCount request${pendingCount > 1 ? 's' : ''} awaiting approval'
                : 'No pending approvals',
            isAlert: pendingCount > 0,
            onTap: onShoppingTap ?? () {},
          ),
          const SizedBox(height: 8),
          _PanelRow(
            icon: Icons.inventory_2_outlined,
            label: lowStockCount > 0
                ? '$lowStockCount item${lowStockCount > 1 ? 's' : ''} need restocking'
                : 'All supplies stocked',
            isAlert: lowStockCount > 0,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SuppliesScreen()),
            ),
          ),
          if (!isHomePro) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => openHomeProUpgrade(
                context,
                source: 'dashboard_household_panel',
              ),
              icon: const Icon(Icons.trending_up_outlined, size: 18),
              label: const Text('Upgrade this household'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isAlert;
  final VoidCallback onTap;

  const _PanelRow({
    required this.icon,
    required this.label,
    required this.isAlert,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: isAlert
                ? AppColors.accentOrange
                : AppColors.statusEnoughText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isAlert
                    ? AppColors.accentOrange
                    : AppColors.textSecondary,
                fontWeight: isAlert ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 15,
            color: isAlert ? AppColors.accentOrange : AppColors.textHint,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TODAY'S TASKS PREVIEW CARD (compact, shown on home for both roles)
// ─────────────────────────────────────────────────────────────────────────────

class _TasksPreviewCard extends StatelessWidget {
  const _TasksPreviewCard();

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskProvider>();
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.isOwner;
    final today = tasks.todayTasks;
    final done = tasks.todayDoneCount;
    final total = tasks.todayTotalCount;
    final allDone = total > 0 && done == total;

    // Undone tasks first, then done — show max 3 in the preview
    final preview = [
      ...today.where((t) => !t.isDone),
      ...today.where((t) => t.isDone),
    ].take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone
              ? AppColors.statusEnoughText.withAlpha(55)
              : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: allDone
                        ? AppColors.statusEnoughText
                        : AppColors.primaryTeal,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  total == 0
                      ? 'No tasks yet today'
                      : allDone
                      ? 'All done today! 🎉'
                      : '$done of $total tasks done',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: allDone
                        ? AppColors.statusEnoughText
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Tasks remaining pill
                if (total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: allDone
                          ? AppColors.statusEnoughText.withAlpha(18)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      allDone ? 'Done ✓' : '${total - done} left',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: allDone
                            ? AppColors.statusEnoughText
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Progress bar ───────────────────────────────────────
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: done / total,
                  minHeight: 4,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    allDone
                        ? AppColors.statusEnoughText
                        : AppColors.primaryTeal,
                  ),
                ),
              ),
            ),
          // ── Task rows (preview) ────────────────────────────────
          if (today.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOwner
                          ? 'No tasks assigned yet — go to Staff to add some.'
                          : 'Nothing scheduled for today.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Column(
                children: preview.map((task) {
                  return _PreviewTaskRow(task: task, tasks: tasks, isOwner: isOwner);
                }).toList(),
              ),
            ),
          // ── Footer CTA ─────────────────────────────────────────
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DailyTasksScreen()),
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    total == 0
                        ? (isOwner
                              ? 'Go to Staff to add tasks'
                              : 'View in Staff')
                        : total > 3
                        ? 'View all $total tasks'
                        : (isOwner
                              ? 'Manage tasks in Staff'
                              : 'View tasks in Staff'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: AppColors.primaryTeal,
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

class _PreviewTaskRow extends StatelessWidget {
  final TaskItem task;
  final TaskProvider tasks;
  final bool isOwner;
  const _PreviewTaskRow({required this.task, required this.tasks, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => tasks.toggleTask(task.id),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: task.isDone ? AppColors.primaryTeal : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isDone
                      ? AppColors.primaryTeal
                      : AppColors.textHint,
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
                  color: task.isDone
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textHint,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: task.addedBy == 'owner'
                    ? AppColors.accentOrange.withAlpha(18)
                    : AppColors.primaryTeal.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                task.addedBy == 'owner'
                    ? (isOwner ? 'Me' : 'Owner')
                    : (isOwner ? 'Manager' : 'Me'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: task.addedBy == 'owner'
                      ? AppColors.accentOrange
                      : AppColors.primaryTeal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textHint, size: 22),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD ANALYTICS ROW
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardAnalyticsRow extends StatelessWidget {
  final SupplyProvider supply;
  final UtilityProvider utilities;
  final AuthProvider auth;

  const _DashboardAnalyticsRow({
    required this.supply,
    required this.utilities,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    final isPro = auth.isHomePro;
    final isOwner = auth.isOwner;

    // Supplies data
    final items = supply.visibleSupplies(isOwner: isOwner);
    final needAction = items.where((i) => i.needsAttention).length;
    final finished =
        items.where((i) => i.status == SupplyStatus.finished).length;

    // Utilities data
    final utilItems = utilities.visibleItems(isOwner: isOwner);
    final alerts = utilItems.where((i) => i.isLowAlert).length;

    return Row(
      children: [
        Expanded(
          child: _AnalyticsMiniCard(
            icon: Icons.inventory_2_outlined,
            title: 'Supplies',
            metrics: [
              _MiniMetric('${items.length}', 'tracked'),
              if (needAction > 0)
                _MiniMetric('$needAction', 'low', isAlert: true),
              if (finished > 0)
                _MiniMetric('$finished', 'out'),
            ],
            isPro: isPro,
            onTap: () {
              if (isPro) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SuppliesAnalyticsScreen(),
                  ),
                );
              } else {
                openHomeProUpgrade(
                  context,
                  source: 'dashboard_supplies_analytics',
                );
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AnalyticsMiniCard(
            icon: Icons.bolt_outlined,
            title: 'Utilities',
            metrics: [
              _MiniMetric('${utilItems.length}', 'bills'),
              if (alerts > 0)
                _MiniMetric('$alerts', alerts == 1 ? 'alert' : 'alerts',
                    isAlert: true),
            ],
            isPro: isPro,
            onTap: () {
              if (isPro) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UtilitiesAnalyticsScreen(),
                  ),
                );
              } else {
                openHomeProUpgrade(
                  context,
                  source: 'dashboard_utilities_analytics',
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _MiniMetric {
  final String value;
  final String label;
  final bool isAlert;
  const _MiniMetric(this.value, this.label, {this.isAlert = false});
}

class _AnalyticsMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<_MiniMetric> metrics;
  final bool isPro;
  final VoidCallback onTap;

  const _AnalyticsMiniCard({
    required this.icon,
    required this.title,
    required this.metrics,
    required this.isPro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.primaryTeal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color:
                            AppColors.accentOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentOrange,
                          letterSpacing: 0.4,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textHint,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: metrics
                    .map(
                      (m) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: m.isAlert
                                  ? AppColors.accentOrange
                                  : AppColors.primaryTeal,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            m.label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED CARD DECORATION
// ─────────────────────────────────────────────────────────────────────────────

BoxDecoration _cardDeco() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.divider),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// AD BANNER STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _AdBannerStrip extends StatefulWidget {
  const _AdBannerStrip();

  @override
  State<_AdBannerStrip> createState() => _AdBannerStripState();
}

class _AdBannerStripState extends State<_AdBannerStrip> {
  @override
  void initState() {
    super.initState();
    // Fetch on first build — safe to call even if Supabase isn't configured.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdProvider>().fetchOffers();
    });
  }

  /// Pick icon by advertiser name.
  IconData _iconFor(String advertiser) {
    switch (advertiser.toLowerCase()) {
      case 'naivas':
        return Icons.local_grocery_store_outlined;
      case 'carrefour':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.storefront_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final adProvider = context.watch<AdProvider>();
    final offers = adProvider.offers;

    // While loading or empty, collapse to nothing
    if (adProvider.isLoading || offers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.textHint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'SPONSORED',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textHint,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final offer = offers[i];
              return GestureDetector(
                onTap: () => _showAdCartSheet(context, offer),
                child: Container(
                  width: 248,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: offer.accentColor.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: offer.accentColor.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // ── Brand icon + discount badge ─────────────────
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: offer.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _iconFor(offer.advertiser),
                              color: offer.accentColor,
                              size: 23,
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: offer.accentColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '-${offer.discountPercent}%',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // ── Product details ────────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              offer.advertiser,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: offer.accentColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              offer.productName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Text(
                                  offer.formattedOldPrice,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textHint,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  offer.formattedNewPrice,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: offer.accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Save ${offer.formattedSaving}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            // ── "Tap to add" hint ──────────────────
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.add_shopping_cart_rounded,
                                    size: 11,
                                    color:
                                        offer.accentColor.withValues(alpha: 0.7)),
                                const SizedBox(width: 3),
                                Text(
                                  'Tap to add',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: offer.accentColor
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  void _showAdCartSheet(BuildContext context, AdOffer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdAddToCartSheet(offer: offer),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// AD ADD-TO-CART BOTTOM SHEET
// Owner  → adds directly to their personal buy list (no approval needed).
// Manager → submits a request for owner approval.
// ─────────────────────────────────────────────────────────────────────────────

class _AdAddToCartSheet extends StatefulWidget {
  final AdOffer offer;
  const _AdAddToCartSheet({required this.offer});

  @override
  State<_AdAddToCartSheet> createState() => _AdAddToCartSheetState();
}

class _AdAddToCartSheetState extends State<_AdAddToCartSheet> {
  final _qtyCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final supply = context.read<SupplyProvider>();
    final isOwner = auth.isOwner;
    final accent = widget.offer.accentColor;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_offer_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.offer.advertiser,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.3),
                    ),
                    Text(
                      widget.offer.productName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // ── Price strip ──────────────────────────────────────────────────
          Row(
            children: [
              Text(
                widget.offer.formattedOldPrice,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.offer.formattedNewPrice,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accent),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Save ${widget.offer.formattedSaving}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Quantity ────────────────────────────────────────────────────
          TextField(
            controller: _qtyCtrl,
            decoration: InputDecoration(
              labelText: 'Quantity',
              hintText: 'e.g. 2 bags, 1 piece',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.inventory_2_outlined),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 8),

          // ── Role hint ───────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                isOwner
                    ? Icons.shopping_bag_outlined
                    : Icons.pending_actions_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  isOwner
                      ? 'Goes straight to your buy list — no approval needed.'
                      : 'Sends a request to the owner for approval.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Action button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isOwner ? AppColors.primaryTeal : AppColors.accentOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: Icon(
                  isOwner ? Icons.add_shopping_cart : Icons.send_rounded,
                  size: 18),
              label: Text(
                isOwner ? 'Add to My List' : 'Submit Request',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              onPressed: () {
                if (auth.currentUser == null || auth.household == null) return;
                const uuid = Uuid();
                final qty = _qtyCtrl.text.trim().isEmpty
                    ? '1'
                    : _qtyCtrl.text.trim();
                final req = ShoppingRequest(
                  id: uuid.v4(),
                  householdId: auth.household!.id,
                  itemName: widget.offer.productName,
                  quantity: qty,
                  category: widget.offer.category,
                  urgency: ShoppingUrgency.neededSoon,
                  notes: 'From ${widget.offer.advertiser} offer',
                  status: isOwner
                      ? ShoppingStatus.approved
                      : ShoppingStatus.requested,
                  purchaseType: isOwner
                      ? PurchaseType.ownerPurchase
                      : PurchaseType.managerRequest,
                  requestedByUserId: auth.currentUser!.id,
                  requestedByName: auth.currentUser!.fullName,
                  approvedByUserId:
                      isOwner ? auth.currentUser!.id : null,
                  requestedAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  catalogProductName: widget.offer.productName,
                  catalogBrand: widget.offer.advertiser,
                );
                supply.addShoppingRequest(req, auth.household!.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isOwner
                        ? 'Added to your buy list'
                        : 'Request submitted — waiting for owner approval'),
                    backgroundColor: isOwner
                        ? AppColors.primaryTeal
                        : AppColors.accentOrange,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// SCHOOL NEEDS BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _SchoolNeedsBanner extends StatelessWidget {
  final VoidCallback? onTap;
  const _SchoolNeedsBanner({this.onTap});

  @override
  Widget build(BuildContext context) {
    final childProvider = context.watch<ChildProvider>();
    final needs = childProvider.needsForTomorrow;
    if (needs.isEmpty) return const SizedBox.shrink();

    // Group by child name for a tidy display
    final childProvider2 = context.read<ChildProvider>();
    final childNames = <String>{};
    for (final n in needs) {
      try {
        final c = childProvider2.children.firstWhere((c) => c.id == n.childId);
        childNames.add(c.name.split(' ').first);
      } catch (_) {}
    }
    final namesStr = childNames.join(', ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentYellow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.backpack_outlined,
                size: 18, color: AppColors.accentOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${needs.length} school item${needs.length == 1 ? '' : 's'} needed tomorrow'
                '${namesStr.isNotEmpty ? ' for $namesStr' : ''}'
                ' — buy before dusk today',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentOrange,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.accentOrange),
          ],
        ),
      ),
    );
  }
}
