import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../providers/supply_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/laundry_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/utility_provider.dart';
import '../providers/task_provider.dart';
import '../providers/meal_timetable_provider.dart';
import '../services/sync_service.dart';
import '../utils/app_colors.dart';
import '../utils/upgrade_flow.dart';
import '../widgets/common_widgets.dart';
import 'auth/login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'supplies/supplies_screen.dart';
import 'laundry/laundry_screen.dart';
import 'meals/meals_screen.dart';
import 'kids/kids_screen.dart';
import 'shopping/shopping_screen.dart';
import 'staff/staff_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isLoading = true;

  // Tab indices: 0=Home 1=Supplies 2=Shopping 3=Laundry 4=Meals 5=Kids
  List<Widget> get _screens => [
    DashboardScreen(onNavigate: _navigateTo),
    const SuppliesScreen(),
    const ShoppingScreen(),
    const LaundryScreen(),
    const MealsScreen(),
    const KidsScreen(),
  ];

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final householdId = auth.household?.id;
    if (householdId == null) return;

    final supplyProvider = context.read<SupplyProvider>();
    final mealProvider = context.read<MealProvider>();
    final childProvider = context.read<ChildProvider>();
    final laundryProvider = context.read<LaundryProvider>();
    final staffProvider = context.read<StaffProvider>();
    final utilityProvider = context.read<UtilityProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final taskProvider = context.read<TaskProvider>();
    final timetableProvider = context.read<MealTimetableProvider>();

    // Ensure Supabase membership record exists for this user
    final role = auth.isOwner ? 'owner' : 'house_manager';
    await SyncService.ensureHouseholdMember(householdId, role);

    await Future.wait([
      supplyProvider.loadData(householdId),
      mealProvider.loadData(householdId),
      childProvider.loadData(householdId),
      laundryProvider.loadData(householdId),
      staffProvider.loadData(householdId),
      utilityProvider.loadData(householdId),
      taskProvider.loadData(householdId),
      timetableProvider.loadData(householdId),
      notificationProvider.loadData(householdId),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.surfaceLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondaryTeal, AppColors.primaryTeal],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.home_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColors.primaryTeal,
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading your household…',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: DashboardScreen.shellScaffoldKey,
      drawer: const _AccountDrawer(),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primaryTeal,
            unselectedItemColor: AppColors.textHint,
            backgroundColor: AppColors.white,
            elevation: 0,
            iconSize: 22,
            selectedLabelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'Supplies',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_cart_outlined),
                activeIcon: Icon(Icons.shopping_cart_rounded),
                label: 'Shopping',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.local_laundry_service_outlined),
                activeIcon: Icon(Icons.local_laundry_service_rounded),
                label: 'Laundry',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant_outlined),
                activeIcon: Icon(Icons.restaurant_rounded),
                label: 'Meals',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.child_care_outlined),
                activeIcon: Icon(Icons.child_care_rounded),
                label: 'Kids',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDrawer extends StatelessWidget {
  const _AccountDrawer();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final household = auth.household;
    final isOwner = auth.isOwner;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondaryTeal, AppColors.primaryTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      user?.fullName.substring(0, 1).toUpperCase() ?? '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? (isOwner ? 'Homeowner' : 'House manager'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isOwner ? 'Homeowner account' : 'House manager account',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  HomePlanBadge(
                    label: auth.householdPlanLabel,
                    isPro: auth.isHomePro,
                    useLightText: true,
                  ),
                  if ((household?.householdName ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      household!.householdName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerSection(
                    title: 'Account',
                    children: [
                      _DrawerTile(
                        icon: Icons.person_outline,
                        title: 'Profile info',
                        subtitle: 'See your account and household details',
                        onTap: () => _showProfileSheet(context),
                      ),
                      _DrawerTile(
                        icon: auth.isHomePro
                            ? Icons.workspace_premium_outlined
                            : Icons.trending_up_outlined,
                        title: auth.isHomePro
                            ? 'Home Pro plan'
                            : 'Upgrade to Home Pro',
                        subtitle: auth.isHomePro
                            ? 'Review your current household plan'
                            : 'See everything included in Home Pro',
                        onTap: () {
                          Navigator.pop(context);
                          openHomeProUpgrade(context, source: 'account_drawer');
                        },
                      ),
                      if (isOwner)
                        _DrawerTile(
                          icon: Icons.group_add_outlined,
                          title: 'Home manager',
                          subtitle: 'Add, remove, and manage join code',
                          onTap: () => _showManagerSheet(context),
                        )
                      else ...[
                        _DrawerTile(
                          icon: Icons.home_outlined,
                          title: auth.household?.householdName ?? 'Your household',
                          subtitle: () {
                            final owner = auth.householdMembers
                                .where((u) => u.role == UserRole.owner)
                                .firstOrNull;
                            return owner != null
                                ? 'Owner: ${owner.fullName}'
                                : 'Your household details';
                          }(),
                        ),
                        _DrawerTile(
                          icon: Icons.exit_to_app_outlined,
                          title: 'Leave household',
                          subtitle: 'Remove yourself from this household',
                          onTap: () => _confirmLeaveHousehold(context),
                        ),
                      ],
                    ],
                  ),
                  _DrawerSection(
                    title: 'Household',
                    children: [
                      _DrawerTile(
                        icon: Icons.badge_outlined,
                        title: 'Staff',
                        subtitle: 'View schedules, notes, and staff details',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StaffScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  _DrawerSection(
                    title: 'Support',
                    children: [
                      _DrawerTile(
                        icon: Icons.description_outlined,
                        title: 'Terms & Conditions',
                        subtitle: 'How this app should be used',
                        onTap: () => _showTermsSheet(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.accentOrange),
              title: const Text('Log out'),
              subtitle: const Text('Sign out of this device'),
              onTap: () async {
                await auth.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OwnerProfileSheet(),
    );
  }

  void _showManagerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManageHomeManagerSheet(),
    );
  }

  Future<void> _confirmLeaveHousehold(BuildContext context) async {
    Navigator.pop(context); // close drawer first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave household?'),
        content: const Text(
          'You will lose access to this household\'s data and will need a new invite code to join another one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await context.read<AuthProvider>().leaveHousehold();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showTermsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TermsSheet(),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DrawerSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryTeal),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _OwnerProfileSheet extends StatelessWidget {
  const _OwnerProfileSheet();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final household = auth.household;

    return _SheetShell(
      title: 'Profile info',
      subtitle: 'Your account details and household identity.',
      child: Column(
        children: [
          HomeFlowCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Household plan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      HomePlanBadge(
                        label: auth.householdPlanLabel,
                        isPro: auth.isHomePro,
                        compact: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () =>
                      openHomeProUpgrade(context, source: 'profile_sheet'),
                  child: Text(auth.isHomePro ? 'View plan' : 'Upgrade'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoTile(label: 'Full name', value: user?.fullName ?? '—'),
          _InfoTile(label: 'Email', value: user?.email ?? '—'),
          _InfoTile(
            label: 'Role',
            value: auth.isOwner ? 'Homeowner' : 'House manager',
          ),
          _InfoTile(label: 'Household', value: household?.householdName ?? '—'),
          _InfoTile(
            label: 'Sign-up code',
            value: auth.ownerInviteCode.isEmpty ? '—' : auth.ownerInviteCode,
          ),
        ],
      ),
    );
  }
}

class _ManageHomeManagerSheet extends StatefulWidget {
  const _ManageHomeManagerSheet();

  @override
  State<_ManageHomeManagerSheet> createState() =>
      _ManageHomeManagerSheetState();
}

class _ManageHomeManagerSheetState extends State<_ManageHomeManagerSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return _SheetShell(
      title: 'Home manager',
      subtitle: 'Add or remove managers and share the sign-up code securely.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.statusVeryLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentOrange.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manager sign-up code',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentOrange,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        auth.ownerInviteCode,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: auth.ownerInviteCode),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sign-up code copied ✓'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Copy'),
                    ),
                  ],
                ),
                const Text(
                  'Share this code with the person you want to join as home manager during sign-up.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Linked managers',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (auth.managers.isEmpty)
            const _InlineEmpty(text: 'No home manager added yet.')
          else
            ...auth.managers.map(
              (manager) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryTeal.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        manager.fullName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryTeal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            manager.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            manager.email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await auth.removeHouseManager(manager.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${manager.fullName} removed'),
                          ),
                        );
                      },
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Add manager manually',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Manager full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Manager email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () async {
              if (_nameCtrl.text.trim().isEmpty ||
                  _emailCtrl.text.trim().isEmpty)
                return;
              await auth.addHouseManager(
                fullName: _nameCtrl.text.trim(),
                email: _emailCtrl.text.trim(),
              );
              _nameCtrl.clear();
              _emailCtrl.clear();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Home manager added ✓')),
              );
              setState(() {});
            },
            child: const Text('Add manager'),
          ),
        ],
      ),
    );
  }
}

class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  @override
  Widget build(BuildContext context) {
    return const _SheetShell(
      title: 'Terms & Conditions',
      subtitle:
          'Key usage expectations for household coordination in homeFlow.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TermBullet('Use accurate household, supply, and staff information.'),
          _TermBullet(
            'Keep sign-up codes private and only share with trusted staff or managers.',
          ),
          _TermBullet(
            'Managers may help coordinate orders, but owners remain responsible for payment decisions.',
          ),
          _TermBullet(
            'Review supplier and payment details before sending money or approving restocking.',
          ),
          _TermBullet(
            'Treat the app as a coordination tool; always confirm urgent deliveries directly when needed.',
          ),
        ],
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String text;

  const _InlineEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }
}

class _TermBullet extends StatelessWidget {
  final String text;

  const _TermBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 7, color: AppColors.primaryTeal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
