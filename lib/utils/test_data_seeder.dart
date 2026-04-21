import 'package:uuid/uuid.dart';
import '../models/supply_item.dart';
import '../models/shopping_request.dart';
import '../models/meal_log.dart';
import '../models/laundry_item.dart';
import '../models/child_model.dart';
import '../models/staff_schedule.dart';
import '../models/app_notification.dart';
import '../models/utility_tracker.dart';
import '../providers/supply_provider.dart';
import '../providers/meal_provider.dart';
import '../providers/laundry_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/utility_provider.dart';

/// Seeds realistic Kenyan household test data into all providers.
class TestDataSeeder {
  static const _uuid = Uuid();

  static Future<void> seed({
    required String householdId,
    required String userId,
    required String userName,
    required SupplyProvider supplyProvider,
    required MealProvider mealProvider,
    required ChildProvider childProvider,
    required LaundryProvider laundryProvider,
    required StaffProvider staffProvider,
    required UtilityProvider utilityProvider,
    required NotificationProvider notificationProvider,
  }) async {
    await _seedSupplyStatuses(supplyProvider, householdId);
    await _seedShoppingRequests(supplyProvider, householdId, userId, userName);
    await _seedMealLogs(mealProvider, householdId, userId);
    await _seedLaundryItems(laundryProvider, householdId, userId);
    await _seedChildren(childProvider, householdId, userId);
    await _seedStaffSchedule(staffProvider, householdId);
    await _seedUtilities(utilityProvider, householdId);
    await _seedNotifications(notificationProvider, householdId);
  }

  // --- SUPPLIES: Give some items low / very low / finished statuses ---
  static Future<void> _seedSupplyStatuses(
      SupplyProvider provider, String householdId) async {
    final supplies = provider.supplies;
    if (supplies.isEmpty) return;

    // Map supply names (matching starterSupplies) to demo statuses
    final statusMap = <String, SupplyStatus>{
      'Cooking Oil': SupplyStatus.runningLow,
      'Sugar': SupplyStatus.veryLow,
      'Milk': SupplyStatus.finished,
      'Bread': SupplyStatus.runningLow,
      'Rice': SupplyStatus.enough,
      'Tea Leaves': SupplyStatus.veryLow,
      'Toilet Paper': SupplyStatus.finished,
      'Dishwashing Paste': SupplyStatus.runningLow,
      '13kg Gas Cylinder': SupplyStatus.enough,
      'Maize Flour': SupplyStatus.enough,
      'Wheat Flour': SupplyStatus.veryLow,
      'Beans': SupplyStatus.enough,
      'Eggs': SupplyStatus.runningLow,
      'Onions': SupplyStatus.enough,
      'Tomatoes': SupplyStatus.runningLow,
      'Hand-wash Detergent Powder': SupplyStatus.enough,
      'Bleach (Jik)': SupplyStatus.enough,
      'Body Soap': SupplyStatus.veryLow,
      'Sukuma Wiki': SupplyStatus.enough,
      'Bananas': SupplyStatus.enough,
    };

    for (final entry in statusMap.entries) {
      final item = supplies.where((s) => s.name == entry.key).firstOrNull;
      if (item != null) {
        await provider.updateSupplyStatus(item.id, entry.value, householdId);
      }
    }
  }

  // --- SHOPPING REQUESTS: Mix of pending, approved, purchased ---
  static Future<void> _seedShoppingRequests(
      SupplyProvider provider,
      String householdId,
      String userId,
      String userName) async {
    final now = DateTime.now();

    final requests = [
      ShoppingRequest(
        id: _uuid.v4(),
        householdId: householdId,
        itemName: 'Fresh Milk (2L)',
        quantity: '3 litres',
        category: 'Dairy & Eggs',
        urgency: ShoppingUrgency.critical,
        notes: 'Kids have no milk for breakfast',
        status: ShoppingStatus.requested,
        requestedByUserId: userId,
        requestedByName: userName,
        requestedAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      ShoppingRequest(
        id: _uuid.v4(),
        householdId: householdId,
        itemName: 'Sugar (2kg)',
        quantity: '1 bag',
        category: 'Dry Foods & Cereals',
        urgency: ShoppingUrgency.neededToday,
        notes: 'Almost finished',
        status: ShoppingStatus.approved,
        requestedByUserId: userId,
        requestedByName: userName,
        approvedByUserId: userId,
        requestedAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      ShoppingRequest(
        id: _uuid.v4(),
        householdId: householdId,
        itemName: 'Toilet Paper (12 pack)',
        quantity: '2 packs',
        category: 'Laundry & Cleaning',
        urgency: ShoppingUrgency.critical,
        notes: 'Completely out',
        status: ShoppingStatus.requested,
        requestedByUserId: userId,
        requestedByName: userName,
        requestedAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      ShoppingRequest(
        id: _uuid.v4(),
        householdId: householdId,
        itemName: 'Tea Leaves (500g)',
        quantity: '2 packets',
        category: 'Breakfast Staples',
        urgency: ShoppingUrgency.neededSoon,
        status: ShoppingStatus.approved,
        requestedByUserId: userId,
        requestedByName: userName,
        approvedByUserId: userId,
        requestedAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 12)),
      ),
      ShoppingRequest(
        id: _uuid.v4(),
        householdId: householdId,
        itemName: 'Dishwashing Paste (Pride)',
        quantity: '2 tins',
        category: 'Kitchen Cleaning',
        urgency: ShoppingUrgency.neededSoon,
        status: ShoppingStatus.requested,
        requestedByUserId: userId,
        requestedByName: userName,
        requestedAt: now.subtract(const Duration(days: 1, hours: 5)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 5)),
      ),
      ShoppingRequest(
        id: _uuid.v4(),
        householdId: householdId,
        itemName: 'Wheat Flour (2kg)',
        quantity: '1 bag',
        category: 'Dry Foods & Cereals',
        urgency: ShoppingUrgency.neededToday,
        notes: 'For chapati tonight',
        status: ShoppingStatus.requested,
        requestedByUserId: userId,
        requestedByName: userName,
        requestedAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      ShoppingRequest(
        id: _uuid.v4(),
        householdId: householdId,
        itemName: 'Sukuma Wiki',
        quantity: '2 bunches',
        category: 'Vegetables',
        urgency: ShoppingUrgency.neededToday,
        notes: 'For lunch and dinner',
        status: ShoppingStatus.requested,
        requestedByUserId: userId,
        requestedByName: userName,
        requestedAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      ShoppingRequest(
        id: _uuid.v4(),
        householdId: householdId,
        itemName: 'Tomatoes (1kg)',
        quantity: '1 kg',
        category: 'Vegetables',
        urgency: ShoppingUrgency.neededSoon,
        status: ShoppingStatus.approved,
        requestedByUserId: userId,
        requestedByName: userName,
        approvedByUserId: userId,
        requestedAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 10)),
      ),
    ];

    for (final req in requests) {
      await provider.addShoppingRequest(req, householdId);
    }
  }

  // --- MEAL LOGS: Today's meals + yesterday + day before ---
  static Future<void> _seedMealLogs(
      MealProvider provider, String householdId, String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    final logs = [
      // ── TODAY ─────────────────────────────────────────────────────
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: today.copyWith(hour: 7, minute: 15),
        mealPeriod: 'Breakfast',
        selectedFoods: ['Tea with Milk', 'Bread', 'Boiled Eggs', 'Banana'],
        packedForSchool: false,
        nutritionTags: MealLog.deriveNutritionTags(
            ['Tea with Milk', 'Bread', 'Boiled Eggs', 'Banana']),
        createdByUserId: userId,
      ),
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: today.copyWith(hour: 9, minute: 45),
        mealPeriod: 'School Snack',
        selectedFoods: ['Mandazi', 'Banana', 'Juice'],
        packedForSchool: true,
        childName: 'Amani',
        nutritionTags:
            MealLog.deriveNutritionTags(['Mandazi', 'Banana', 'Juice']),
        createdByUserId: userId,
      ),
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: today.copyWith(hour: 13, minute: 0),
        mealPeriod: 'Lunch',
        selectedFoods: ['Ugali & Sukuma Wiki', 'Beef Stew', 'Tomatoes', 'Avocado'],
        packedForSchool: false,
        nutritionTags: MealLog.deriveNutritionTags(
            ['Ugali & Sukuma Wiki', 'Beef Stew', 'Tomatoes', 'Avocado']),
        createdByUserId: userId,
      ),
      // ── YESTERDAY ─────────────────────────────────────────────────
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: yesterday.copyWith(hour: 7, minute: 0),
        mealPeriod: 'Breakfast',
        selectedFoods: ['Uji', 'Groundnuts', 'Mandazi', 'Banana'],
        packedForSchool: false,
        nutritionTags: MealLog.deriveNutritionTags(
            ['Uji', 'Groundnuts', 'Mandazi', 'Banana']),
        createdByUserId: userId,
      ),
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: yesterday.copyWith(hour: 10, minute: 0),
        mealPeriod: 'School Snack',
        selectedFoods: ['Boiled Egg', 'Orange', 'Groundnuts'],
        packedForSchool: true,
        childName: 'Zuri',
        nutritionTags: MealLog.deriveNutritionTags(
            ['Boiled Egg', 'Orange', 'Groundnuts']),
        createdByUserId: userId,
      ),
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: yesterday.copyWith(hour: 13, minute: 15),
        mealPeriod: 'Lunch',
        selectedFoods: ['Rice & Beans', 'Cabbage', 'Avocado'],
        packedForSchool: false,
        nutritionTags: MealLog.deriveNutritionTags(
            ['Rice & Beans', 'Cabbage', 'Avocado']),
        createdByUserId: userId,
      ),
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: yesterday.copyWith(hour: 19, minute: 30),
        mealPeriod: 'Dinner',
        selectedFoods: ['Chapati & Ndengu', 'Spinach', 'Yoghurt'],
        packedForSchool: false,
        nutritionTags: MealLog.deriveNutritionTags(
            ['Chapati & Ndengu', 'Spinach', 'Yoghurt']),
        createdByUserId: userId,
      ),
      // ── TWO DAYS AGO ──────────────────────────────────────────────
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: twoDaysAgo.copyWith(hour: 7, minute: 30),
        mealPeriod: 'Breakfast',
        selectedFoods: ['Tea with Milk', 'Bread', 'Omelette', 'Pawpaw'],
        packedForSchool: false,
        nutritionTags: MealLog.deriveNutritionTags(
            ['Tea with Milk', 'Bread', 'Omelette', 'Pawpaw']),
        createdByUserId: userId,
      ),
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: twoDaysAgo.copyWith(hour: 13, minute: 0),
        mealPeriod: 'Lunch',
        selectedFoods: ['Githeri', 'Kachumbari', 'Avocado'],
        packedForSchool: false,
        nutritionTags: MealLog.deriveNutritionTags(
            ['Githeri', 'Kachumbari', 'Avocado']),
        createdByUserId: userId,
      ),
      MealLog(
        id: _uuid.v4(),
        householdId: householdId,
        date: twoDaysAgo.copyWith(hour: 19, minute: 0),
        mealPeriod: 'Dinner',
        selectedFoods: ['Ugali & Beef Stew', 'Sukuma Wiki', 'Tomatoes'],
        packedForSchool: false,
        nutritionTags: MealLog.deriveNutritionTags(
            ['Ugali & Beef Stew', 'Sukuma Wiki', 'Tomatoes']),
        createdByUserId: userId,
      ),
    ];

    for (final log in logs) {
      await provider.addMealLog(log, householdId);
    }
  }

  // --- LAUNDRY: Items at various stages & priorities ---
  static Future<void> _seedLaundryItems(
      LaundryProvider provider, String householdId, String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 8, 0);

    // Helper: create a date N days ago at a given hour
    DateTime ago(int days, {int hour = 8, int minute = 0}) =>
        today.subtract(Duration(days: days)).add(Duration(hours: hour, minutes: minute));

    final items = [
      // ── TODAY ──────────────────────────────────────────────────────
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Master Bedroom',
        numberOfLoads: 2,
        stage: LaundryStage.washing,
        notes: 'Duvet cover + pillow cases',
        createdByUserId: userId,
        createdAt: ago(0, hour: 7, minute: 30),
        updatedAt: ago(0, hour: 7, minute: 30),
      ),
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Bedroom 2',
        numberOfLoads: 3,
        stage: LaundryStage.drying,
        createdByUserId: userId,
        createdAt: ago(0, hour: 6, minute: 0),
        updatedAt: ago(0, hour: 9, minute: 0),
      ),
      // ── YESTERDAY ─────────────────────────────────────────────────
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Bedroom 1',
        numberOfLoads: 1,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(1, hour: 8, minute: 0),
        storedAt: ago(1, hour: 14, minute: 30),
        updatedAt: ago(1, hour: 14, minute: 30),
      ),
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Master Bedroom',
        numberOfLoads: 2,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(1, hour: 9, minute: 0),
        storedAt: ago(1, hour: 16, minute: 0),
        updatedAt: ago(1, hour: 16, minute: 0),
      ),
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Staff Bedroom',
        numberOfLoads: 1,
        stage: LaundryStage.folded,
        createdByUserId: userId,
        createdAt: ago(1, hour: 10, minute: 0),
        updatedAt: ago(1, hour: 15, minute: 0),
      ),
      // ── 2 DAYS AGO ────────────────────────────────────────────────
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Bedroom 3',
        numberOfLoads: 2,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(2, hour: 7, minute: 45),
        storedAt: ago(2, hour: 15, minute: 0),
        updatedAt: ago(2, hour: 15, minute: 0),
      ),
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Bedroom 4',
        numberOfLoads: 1,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(2, hour: 8, minute: 30),
        storedAt: ago(2, hour: 14, minute: 0),
        updatedAt: ago(2, hour: 14, minute: 0),
      ),
      // ── 4 DAYS AGO ────────────────────────────────────────────────
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Master Bedroom',
        numberOfLoads: 3,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(4, hour: 8, minute: 0),
        storedAt: ago(4, hour: 17, minute: 0),
        updatedAt: ago(4, hour: 17, minute: 0),
      ),
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Bedroom 1',
        numberOfLoads: 2,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(4, hour: 9, minute: 0),
        storedAt: ago(4, hour: 16, minute: 30),
        updatedAt: ago(4, hour: 16, minute: 30),
      ),
      // ── 6 DAYS AGO ────────────────────────────────────────────────
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Bedroom 2',
        numberOfLoads: 2,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(6, hour: 8, minute: 15),
        storedAt: ago(6, hour: 14, minute: 0),
        updatedAt: ago(6, hour: 14, minute: 0),
      ),
      // ── 10 DAYS AGO (last month boundary) ─────────────────────────
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Bedroom 3',
        numberOfLoads: 1,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(10, hour: 7, minute: 30),
        storedAt: ago(10, hour: 13, minute: 0),
        updatedAt: ago(10, hour: 13, minute: 0),
      ),
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Staff Bedroom',
        numberOfLoads: 2,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(10, hour: 9, minute: 0),
        storedAt: ago(10, hour: 15, minute: 30),
        updatedAt: ago(10, hour: 15, minute: 30),
      ),
      // ── 18 DAYS AGO ───────────────────────────────────────────────
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Master Bedroom',
        numberOfLoads: 2,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(18, hour: 8, minute: 0),
        storedAt: ago(18, hour: 15, minute: 0),
        updatedAt: ago(18, hour: 15, minute: 0),
      ),
      LaundryItem(
        id: _uuid.v4(),
        householdId: householdId,
        bedroom: 'Bedroom 4',
        numberOfLoads: 1,
        stage: LaundryStage.stored,
        createdByUserId: userId,
        createdAt: ago(18, hour: 10, minute: 0),
        storedAt: ago(18, hour: 16, minute: 0),
        updatedAt: ago(18, hour: 16, minute: 0),
      ),
    ];

    for (final item in items) {
      await provider.addItem(item, householdId);
    }
  }

  // --- CHILDREN: Two school-age kids with partial routine logs ---
  static Future<void> _seedChildren(
      ChildProvider provider, String householdId, String userId) async {
    final now = DateTime.now();

    final child1 = ChildModel(
      id: _uuid.v4(),
      householdId: householdId,
      name: 'Amani',
      schoolName: 'Brookhouse School',
      className: 'Grade 3',
      dropoffTime: '7:15 AM',
      pickupTime: '3:30 PM',
      snackRequired: true,
    );

    final child2 = ChildModel(
      id: _uuid.v4(),
      householdId: householdId,
      name: 'Zuri',
      schoolName: 'Brookhouse School',
      className: 'Grade 1',
      dropoffTime: '7:15 AM',
      pickupTime: '2:00 PM',
      snackRequired: true,
    );

    await provider.addChild(child1, householdId);
    await provider.addChild(child2, householdId);

    // Add today's routine log for Amani (partially complete)
    final log1 = ChildRoutineLog(
      id: _uuid.v4(),
      childId: child1.id,
      date: now,
      uniformReady: true,
      shoesReady: true,
      lunchPacked: true,
      snackPacked: false,
      swimwearReady: false,
      droppedOff: false,
      pickedUp: false,
      updatedByUserId: userId,
    );

    // Add today's routine log for Zuri (mostly done)
    final log2 = ChildRoutineLog(
      id: _uuid.v4(),
      childId: child2.id,
      date: now,
      uniformReady: true,
      shoesReady: true,
      lunchPacked: true,
      snackPacked: true,
      swimwearReady: true,
      droppedOff: true,
      pickedUp: false,
      updatedByUserId: userId,
    );

    await provider.updateRoutineLog(log1, householdId);
    await provider.updateRoutineLog(log2, householdId);
  }

  // --- STAFF: House manager on duty ---
  static Future<void> _seedStaffSchedule(
      StaffProvider provider, String householdId) async {
    final schedule = StaffSchedule(
      id: _uuid.v4(),
      householdId: householdId,
      userId: _uuid.v4(),
      userName: 'Mary Wanjiku',
      workStatus: WorkStatus.onDuty,
      recurringOffDay: 'Sunday',
      notes: 'Been with the family for 3 years',
      updatedAt: DateTime.now(),
    );
    await provider.updateSchedule(schedule, householdId);
  }

  // --- NOTIFICATIONS: A realistic mix ---
  static Future<void> _seedNotifications(
      NotificationProvider provider, String householdId) async {
    final now = DateTime.now();

    final notifications = [
      AppNotification(
        id: _uuid.v4(),
        householdId: householdId,
        type: 'supply_low',
        title: '🚨 Milk is Finished',
        body: 'Fresh milk is completely out. Kids need it for breakfast.',
        priority: NotificationPriority.critical,
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
      AppNotification(
        id: _uuid.v4(),
        householdId: householdId,
        type: 'supply_low',
        title: '⚠️ Toilet Paper Running Very Low',
        body: 'Only 1 roll remaining. Please restock urgently.',
        priority: NotificationPriority.critical,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      AppNotification(
        id: _uuid.v4(),
        householdId: householdId,
        type: 'supply_low',
        title: 'Sugar is Very Low',
        body: 'Sugar supply is very low. Consider adding to shopping list.',
        priority: NotificationPriority.high,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      AppNotification(
        id: _uuid.v4(),
        householdId: householdId,
        type: 'laundry',
        title: 'Urgent Laundry',
        body: 'Amani\'s school uniform is in the wash — needed by tomorrow morning.',
        priority: NotificationPriority.high,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 30)),
      ),
      AppNotification(
        id: _uuid.v4(),
        householdId: householdId,
        type: 'shopping',
        title: 'New Shopping Request',
        body: 'Mary added "Fresh Milk (2L)" to the shopping list. Marked as critical.',
        priority: NotificationPriority.high,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: _uuid.v4(),
        householdId: householdId,
        type: 'school',
        title: 'Amani\'s Snack Not Packed',
        body: 'School snack for Amani is not yet packed for today.',
        priority: NotificationPriority.normal,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: _uuid.v4(),
        householdId: householdId,
        type: 'supply_low',
        title: 'Tea Leaves Running Low',
        body: 'Tea leaves supply is very low.',
        priority: NotificationPriority.normal,
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      AppNotification(
        id: _uuid.v4(),
        householdId: householdId,
        type: 'laundry',
        title: 'Zuri\'s Uniform Ready',
        body: 'Zuri\'s school uniform has been washed, ironed and is ready.',
        priority: NotificationPriority.normal,
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
    ];

    for (final n in notifications) {
      await provider.addNotification(n, householdId);
    }
  }

  // --- UTILITIES: Gas 10 days old (~67%), electricity almost empty, water healthy ---
  static Future<void> _seedUtilities(
      UtilityProvider provider, String householdId) async {
    if (provider.items.isNotEmpty) return;

    final now = DateTime.now();

    final gas = UtilityTracker(
      id: _uuid.v4(),
      householdId: householdId,
      type: UtilityType.cookingGas,
      label: 'Kitchen Gas',
      cylinderSize: GasCylinderSize.kg13,
      lastRefilledAt: now.subtract(const Duration(days: 10)),
      estimatedDurationDays: 42,
      updatedAt: now,
    );

    final electricity = UtilityTracker(
      id: _uuid.v4(),
      householdId: householdId,
      type: UtilityType.electricity,
      label: 'Main Electricity',
      tokenUnitsAdded: 50,
      unitsRemaining: 18,
      lastToppedUpAt: now.subtract(const Duration(days: 9)),
      updatedAt: now,
    );

    final water = UtilityTracker(
      id: _uuid.v4(),
      householdId: householdId,
      type: UtilityType.water,
      label: 'Jibu Drinking Water',
      isDrinkingWater: true,
      waterSetupDone: true,
      containerSizeLitres: 18.5,
      totalContainers: 2,
      fullContainers: 1,
      emptyContainers: 1,
      reorderThreshold: 1,
      typicalOrderQuantity: 2,
      reorderFrequencyDays: 14,
      pricePerContainer: 450,
      supplier1: const GasSupplier(
        name: 'Jibu',
        phone: '+254700000000',
        mpesaName: 'Jibu Water',
        mpesaTill: '530530',
        isPaybill: false,
      ),
      lastDeliveredAt: now.subtract(const Duration(days: 12)),
      paymentStatus: UtilityPaymentStatus.unpaid,
      notes: '2 bottles every ~2 weeks. Supplier can leave before M-Pesa is sent.',
      updatedAt: now,
    );

    for (final item in [gas, electricity, water]) {
      await provider.addItem(item, householdId);
    }
  }
}
