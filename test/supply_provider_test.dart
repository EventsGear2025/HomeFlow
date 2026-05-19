import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:homeflow/models/shopping_request.dart';
import 'package:homeflow/providers/supply_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addShoppingRequest merges duplicate active requests for the same supply',
      () async {
    final provider = SupplyProvider();
    const householdId = 'household-1';

    await provider.addShoppingRequest(
      ShoppingRequest(
        id: 'request-1',
        householdId: householdId,
        supplyItemId: 'supply-1',
        itemName: 'Milk',
        quantity: '1 litre',
        category: 'Dairy',
        urgency: ShoppingUrgency.neededSoon,
        requestedByUserId: 'user-1',
        requestedByName: 'Manager One',
        requestedAt: DateTime(2026, 5, 19, 8),
        updatedAt: DateTime(2026, 5, 19, 8),
      ),
      householdId,
    );

    await provider.addShoppingRequest(
      ShoppingRequest(
        id: 'request-2',
        householdId: householdId,
        supplyItemId: 'supply-1',
        itemName: 'Milk',
        quantity: '1 litre',
        category: 'Dairy',
        urgency: ShoppingUrgency.critical,
        requestedByUserId: 'user-1',
        requestedByName: 'Manager One',
        requestedAt: DateTime(2026, 5, 19, 9),
        updatedAt: DateTime(2026, 5, 19, 9),
      ),
      householdId,
    );

    expect(provider.shoppingRequests, hasLength(1));
    expect(provider.shoppingRequests.single.id, 'request-1');
    expect(provider.shoppingRequests.single.urgency, ShoppingUrgency.critical);
  });
}