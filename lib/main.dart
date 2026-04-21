import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'admin/admin_panel_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/supply_provider.dart';
import 'providers/meal_provider.dart';
import 'providers/laundry_provider.dart';
import 'providers/staff_provider.dart';
import 'providers/task_provider.dart';
import 'providers/meal_timetable_provider.dart';
import 'services/supabase_service.dart';
import 'providers/utility_provider.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const HomeFlowApp());
}

class HomeFlowApp extends StatelessWidget {
  const HomeFlowApp({super.key});

  static final GoRouter _adminRouter = GoRouter(
    initialLocation: '/admin/dashboard',
    routes: [
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 0,
          child: AdminDashboardPage(),
        ),
      ),
      GoRoute(
        path: '/admin/households',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 1,
          child: AdminHouseholdsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/households/:id',
        builder: (context, state) => AdminPanelScreen(
          selectedIndex: 1,
          child: AdminHouseholdDetailPage(
            householdId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 2,
          child: AdminUsersPage(),
        ),
      ),
      GoRoute(
        path: '/admin/plans',
        builder: (context, state) => AdminPanelScreen(
          selectedIndex: 3,
          child: const AdminPlansPage(),
        ),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 4,
          child: AdminAnalyticsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/presets',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 5,
          child: AdminPresetsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/notifications',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 6,
          child: AdminNotificationsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/support',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 7,
          child: AdminSupportPage(),
        ),
      ),
      GoRoute(
        path: '/admin/activity-logs',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 8,
          child: AdminActivityLogsPage(),
        ),
      ),
      GoRoute(
        path: '/admin/admin-users',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 9,
          child: AdminUsersManagementPage(),
        ),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) => const AdminPanelScreen(
          selectedIndex: 10,
          child: AdminSettingsPage(),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SupplyProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()),
        ChangeNotifierProvider(create: (_) => ChildProvider()),
        ChangeNotifierProvider(create: (_) => LaundryProvider()),
        ChangeNotifierProvider(create: (_) => StaffProvider()),
        ChangeNotifierProvider(create: (_) => UtilityProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => MealTimetableProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: kIsWeb
          ? MaterialApp.router(
              title: 'homeFlow Admin',
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              routerConfig: _adminRouter,
            )
          : MaterialApp(
              title: 'homeFlow',
              theme: AppTheme.lightTheme,
              debugShowCheckedModeBanner: false,
              home: const _AppEntry(),
            ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
