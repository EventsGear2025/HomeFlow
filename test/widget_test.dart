import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:homeflow/models/household_model.dart';
import 'package:homeflow/models/user_model.dart';
import 'package:homeflow/providers/ad_provider.dart';
import 'package:homeflow/providers/auth_provider.dart';
import 'package:homeflow/providers/laundry_provider.dart';
import 'package:homeflow/providers/meal_provider.dart';
import 'package:homeflow/providers/meal_timetable_provider.dart';
import 'package:homeflow/providers/price_compare_provider.dart';
import 'package:homeflow/providers/staff_provider.dart';
import 'package:homeflow/providers/supply_provider.dart';
import 'package:homeflow/providers/task_provider.dart';
import 'package:homeflow/providers/utility_provider.dart';
import 'package:homeflow/screens/auth/manager_otp_screen.dart';
import 'package:homeflow/screens/auth/otp_screen.dart';
import 'package:homeflow/screens/auth/signup_screen.dart';
import 'package:homeflow/screens/main_shell.dart';
import 'package:homeflow/services/supabase_auth_service.dart';

void main() {
  test('manager role values map correctly', () {
    final authService = SupabaseAuthService();

    expect(authService.inferRoleValue('house_manager'), UserRole.houseManager);
    expect(authService.inferRoleValue('houseManager'), UserRole.houseManager);
    expect(authService.inferRoleValue('owner'), UserRole.owner);
  });

  testWidgets('owner signup skips OTP when session is immediate', (WidgetTester tester) async {
    final auth = _FakeAuthProvider(ownerNeedsEmailConfirmation: false);

    await tester.pumpWidget(_buildApp(auth));

    await tester.enterText(find.byType(TextFormField).at(0), 'Jane Owner');
    await tester.enterText(find.byType(TextFormField).at(1), 'jane@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret12');
    await tester.enterText(find.byType(TextFormField).at(3), 'Jane Household');
    await tester.enterText(find.byType(TextFormField).at(4), '123 Palm Street');

    await tester.ensureVisible(find.text('Create Household & Verify Email'));
    await tester.tap(find.text('Create Household & Verify Email'));
    await tester.pumpAndSettle();

    expect(auth.ownerSetupCalls, 1);
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(OtpScreen), findsNothing);
  });

  testWidgets('manager signup routes to manager OTP when confirmation is required',
      (WidgetTester tester) async {
    final auth = _FakeAuthProvider(managerNeedsEmailConfirmation: true);

    await tester.pumpWidget(_buildApp(auth));

    await tester.tap(find.text("I'm a Manager"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Mark Manager');
    await tester.enterText(find.byType(TextFormField).at(1), 'mark@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret12');

    await tester.tap(find.text('Create Manager Account'));
    await tester.pumpAndSettle();

    expect(auth.managerPreStepCalls, 1);
    expect(auth.managerSetupCalls, 0);
    expect(find.byType(ManagerOtpScreen), findsOneWidget);
  });
}

Widget _buildApp(_FakeAuthProvider auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(create: (_) => SupplyProvider()),
      ChangeNotifierProvider(create: (_) => MealProvider()),
      ChangeNotifierProvider(create: (_) => ChildProvider()),
      ChangeNotifierProvider(create: (_) => LaundryProvider()),
      ChangeNotifierProvider(create: (_) => StaffProvider()),
      ChangeNotifierProvider(create: (_) => UtilityProvider()),
      ChangeNotifierProvider(create: (_) => TaskProvider()),
      ChangeNotifierProvider(create: (_) => MealTimetableProvider()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ChangeNotifierProvider(create: (_) => PriceCompareProvider()),
      ChangeNotifierProvider(create: (_) => AdProvider()),
    ],
    child: const MaterialApp(home: SignUpScreen()),
  );
}

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider({
    this.ownerNeedsEmailConfirmation = true,
    this.managerNeedsEmailConfirmation = true,
  });

  final bool ownerNeedsEmailConfirmation;
  final bool managerNeedsEmailConfirmation;

  int ownerSetupCalls = 0;
  int managerPreStepCalls = 0;
  int managerSetupCalls = 0;

  UserModel? _currentUser;
  HouseholdModel? _household;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  HouseholdModel? get household => _household;

  @override
  bool get isLoading => false;

  @override
  bool get isOwner => _currentUser?.isOwner ?? false;

  @override
  bool get isHouseManager => _currentUser?.isHouseManager ?? false;

  @override
  Future<bool> signUpOwner({
    required String fullName,
    required String email,
    required String password,
    required String householdName,
    required String deliveryAddress,
    String? deliveryPhone,
  }) async {
    return ownerNeedsEmailConfirmation;
  }

  @override
  Future<void> completeOwnerSetup({
    required String fullName,
    required String email,
    required String householdName,
    required String deliveryAddress,
    String? deliveryPhone,
  }) async {
    ownerSetupCalls += 1;
    _currentUser = UserModel(
      id: 'owner-test',
      fullName: fullName,
      email: email,
      role: UserRole.owner,
      householdId: '',
    );
    _household = null;
    notifyListeners();
  }

  @override
  Future<bool> signUpManagerPreStep({
    required String fullName,
    required String email,
    required String password,
  }) async {
    managerPreStepCalls += 1;
    return managerNeedsEmailConfirmation;
  }

  @override
  Future<void> completeManagerSetup({
    required String fullName,
    required String email,
  }) async {
    managerSetupCalls += 1;
    _currentUser = UserModel(
      id: 'manager-test',
      fullName: fullName,
      email: email,
      role: UserRole.houseManager,
      householdId: '',
    );
    _household = null;
    notifyListeners();
  }
}
