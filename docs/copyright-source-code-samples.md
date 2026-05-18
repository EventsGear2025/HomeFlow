# SOURCE CODE DEPOSIT — COPYRIGHT REGISTRATION
## Software Title: HomeFlow
## Nature of Work: Mobile Application Software (Flutter/Dart)
## Author/Owner: [YOUR FULL LEGAL NAME / COMPANY NAME]
## Date of Creation: 2025 – 2026
## Platform: Android & iOS (cross-platform)

---

> **Notice:** The following pages contain representative source code excerpts
> from the HomeFlow mobile application. This deposit is submitted in support of
> a copyright registration application. All code was authored originally by the
> applicant and has not been published or licensed to any third party.

---

## TABLE OF CONTENTS

1. Application Entry Point — `lib/main.dart`
2. Data Model — `lib/models/supply_item.dart`
3. Data Model — `lib/models/shopping_request.dart`
4. State Management — `lib/providers/supply_provider.dart`
5. Business Logic — `lib/services/retailer_catalog_service.dart`
6. Authentication Service — `lib/services/supabase_auth_service.dart`
7. Backend Sync Service — `lib/services/sync_service.dart` (excerpt)

---

## 1. Application Entry Point
**File:** `lib/main.dart`

```dart
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
import 'providers/price_compare_provider.dart';
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
    ],
  );
}
```

---

## 2. Data Model — Supply Item
**File:** `lib/models/supply_item.dart`

```dart
enum SupplyStatus { enough, runningLow, veryLow, finished }

/// A single usage log entry for a supply item.
class SupplyUsageEntry {
  final DateTime date;
  final double quantity;
  final String? notes;
  /// Optional cost paid for this amount (e.g. KES spent on restock).
  final double? price;
  /// Name of the person who logged this entry.
  final String? loggedByName;

  SupplyUsageEntry({
    required this.date,
    required this.quantity,
    this.notes,
    this.price,
    this.loggedByName,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'quantity': quantity,
        'notes': notes,
        if (price != null) 'price': price,
        if (loggedByName != null) 'loggedByName': loggedByName,
      };

  factory SupplyUsageEntry.fromJson(Map<String, dynamic> json) =>
      SupplyUsageEntry(
        date: DateTime.parse(json['date']),
        quantity: (json['quantity'] as num).toDouble(),
        notes: json['notes'],
        price: json['price'] != null ? (json['price'] as num).toDouble() : null,
        loggedByName: json['loggedByName'],
      );
}

class SupplyItem {
  final String id;
  final String householdId;
  final String name;
  final String category;
  final String unitType;
  final SupplyStatus status;
  final String? preferredBrand;
  final String? notes;
  final DateTime? lastRestockedAt;
  final int? expectedDurationDays;
  final bool isGas;
  /// When true, this item is hidden from house managers — owner eyes only.
  final bool isOwnerOnly;
  /// Optional usage log entries (Home Pro analytics).
  final List<SupplyUsageEntry> usageLogs;
  /// When the status was last changed (shown on card).
  final DateTime? statusUpdatedAt;
  /// Name of the person who last changed the status.
  final String? statusUpdatedByName;
}
```

---

## 3. Data Model — Shopping Request
**File:** `lib/models/shopping_request.dart`

```dart
enum ShoppingUrgency { neededSoon, neededToday, critical }
enum ShoppingStatus { requested, seen, approved, purchased, deferred }

/// Who originated this entry and through what flow.
/// - managerRequest  : manager noticed low stock → awaits owner approval
/// - ownerPurchase   : owner adding to their own personal buy list
/// - managerDirectBuy: manager bought something immediately (emergency)
enum PurchaseType { managerRequest, ownerPurchase, managerDirectBuy }

class ShoppingRequest {
  final String id;
  final String householdId;
  final String? supplyItemId;
  final String itemName;
  final String quantity;
  final String category;
  final ShoppingUrgency urgency;
  final String? notes;
  final ShoppingStatus status;
  final PurchaseType purchaseType;
  final bool autoApproved;
  final String? autoApproveReason;
  final String? buyAnywayReason;
  final String requestedByUserId;
  final String requestedByName;
  final String? approvedByUserId;
  final DateTime requestedAt;
  final DateTime updatedAt;

  ShoppingRequest({
    required this.id,
    required this.householdId,
    this.supplyItemId,
    required this.itemName,
    required this.quantity,
    required this.category,
    required this.urgency,
    this.notes,
    this.status = ShoppingStatus.requested,
    this.purchaseType = PurchaseType.managerRequest,
    this.autoApproved = false,
    this.autoApproveReason,
    this.buyAnywayReason,
    required this.requestedByUserId,
    required this.requestedByName,
    this.approvedByUserId,
    required this.requestedAt,
    required this.updatedAt,
  });

  /// True if this was a manager request that needed (or still needs) approval.
  bool get needsApproval =>
      purchaseType == PurchaseType.managerRequest &&
      (status == ShoppingStatus.requested || status == ShoppingStatus.seen);

  /// True if this is in the owner's personal buy list.
  bool get isOwnerPurchase => purchaseType == PurchaseType.ownerPurchase;

  /// True if the manager bypassed the normal approval flow.
  bool get wasBuyAnyway => buyAnywayReason != null;
}
```

---

## 4. State Management — Supply Provider
**File:** `lib/providers/supply_provider.dart`

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/supply_item.dart';
import '../models/shopping_request.dart';
import '../services/sync_service.dart';
import '../utils/app_constants.dart';

class SupplyProvider extends ChangeNotifier {
  List<SupplyItem> _supplies = [];
  List<ShoppingRequest> _shoppingRequests = [];
  bool _isLoading = false;

  List<SupplyItem> get supplies => _supplies;

  /// Returns supplies visible to the current user.
  /// Owners see everything; house managers see only non-owner-only items.
  List<SupplyItem> visibleSupplies({required bool isOwner}) =>
      isOwner ? _supplies : _supplies.where((s) => !s.isOwnerOnly).toList();

  List<ShoppingRequest> get shoppingRequests => _shoppingRequests;
  bool get isLoading => _isLoading;

  List<SupplyItem> get lowStockItems =>
      _supplies.where((s) => s.needsAttention).toList();

  /// Supplies currently marked as finished — the auto shopping list.
  List<SupplyItem> get finishedSupplies =>
      _supplies.where((s) => s.status == SupplyStatus.finished).toList();

  List<SupplyItem> get gasItems =>
      _supplies.where((s) => s.isGas).toList();

  List<ShoppingRequest> get pendingRequests => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.managerRequest &&
          (r.status == ShoppingStatus.requested ||
              r.status == ShoppingStatus.seen))
      .toList();

  List<ShoppingRequest> get approvedRequests => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.managerRequest &&
          r.status == ShoppingStatus.approved)
      .toList();

  /// Owner's personal buy list (no approval needed).
  List<ShoppingRequest> get ownerBuyList => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.ownerPurchase &&
          r.status != ShoppingStatus.purchased &&
          r.status != ShoppingStatus.deferred)
      .toList();

  /// Deferred items — postponed, revisit when money/time allows.
  List<ShoppingRequest> get deferredRequests => _shoppingRequests
      .where((r) => r.status == ShoppingStatus.deferred)
      .toList();

  /// All completed / historical entries (purchased + direct-buys only).
  List<ShoppingRequest> get historyRequests => _shoppingRequests
      .where((r) =>
          r.status == ShoppingStatus.purchased ||
          r.purchaseType == PurchaseType.managerDirectBuy)
      .toList();

  /// Manager direct-buy entries that the owner hasn't acknowledged yet.
  List<ShoppingRequest> get unacknowledgedDirectBuys => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.managerDirectBuy &&
          r.status != ShoppingStatus.purchased)
      .toList();

  Future<void> loadData(String householdId) async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    // Try Supabase first; fall back to local cache on any error
    final remoteSupplies = await SyncService.fetchAll(
        'app_supplies', householdId, SupplyItem.fromJson);
    final remoteRequests = await SyncService.fetchAll(
        'app_shopping_requests', householdId, ShoppingRequest.fromJson);

    if (remoteSupplies != null) {
      _supplies = remoteSupplies;
      await prefs.setString('supplies_$householdId',
          jsonEncode(_supplies.map((s) => s.toJson()).toList()));
    } else {
      final suppliesJson = prefs.getString('supplies_$householdId');
      if (suppliesJson != null) {
        final List decoded = jsonDecode(suppliesJson);
        _supplies = decoded.map((e) => SupplyItem.fromJson(e)).toList();
      } else {
        _supplies = [];
      }
    }

    if (remoteRequests != null) {
      _shoppingRequests = remoteRequests;
      await prefs.setString('shopping_requests_$householdId',
          jsonEncode(_shoppingRequests.map((r) => r.toJson()).toList()));
    } else {
      final requestsJson = prefs.getString('shopping_requests_$householdId');
      if (requestsJson != null) {
        final List decoded = jsonDecode(requestsJson);
        _shoppingRequests =
            decoded.map((e) => ShoppingRequest.fromJson(e)).toList();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteShoppingRequest(
      String requestId, String householdId) async {
    _shoppingRequests.removeWhere((r) => r.id == requestId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'shopping_requests_$householdId',
        jsonEncode(_shoppingRequests.map((r) => r.toJson()).toList()));
    await SyncService.save(
        'app_shopping_requests', householdId, _shoppingRequests,
        (r) => r.toJson());
  }

  Future<void> removeSupplyItem(String supplyId, String householdId) async {
    _supplies.removeWhere((s) => s.id == supplyId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'supplies_$householdId',
        jsonEncode(_supplies.map((s) => s.toJson()).toList()));
    await SyncService.save(
        'app_supplies', householdId, _supplies, (s) => s.toJson());
  }
}
```

---

## 5. Business Logic — Retailer Price Comparison & Catalog Matching
**File:** `lib/services/retailer_catalog_service.dart`

```dart
// ─────────────────────────────────────────────────────────────────────────────
// RETAILER CATALOG SERVICE
// Maintains a static catalog of common household products for Carrefour Kenya
// and Naivas Supermarket, and implements a 4-pass fuzzy matching algorithm
// to resolve a user-typed item name to the best matching catalog entry.
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a [RetailerQuote] list (one per retailer) for the given item name.
/// Runs 4 matching passes in order of decreasing strictness:
///   Pass 1: Exact phrase containment (score 3.0)
///   Pass 2: Compound-word / no-space match — "cornflakes" ↔ "corn flakes" (score 2.5)
///   Pass 3: Token-level substring (score 1.5)
///   Pass 4: Per-token Levenshtein fuzzy (≤1 edit for short, ≤2 for long) (score 1.2)
static List<RetailerQuote> quotesForItem(
  String itemName, {
  String? preferredBrand,
}) {
  final normalized = itemName.toLowerCase().trim();
  final normalizedCompact = normalized.replaceAll(RegExp(r'\s+'), '');
  final tokens = normalized
      .split(RegExp(r'[\s/,]+'))
      .where((t) => t.length > 2)
      .toList();

  final Map<RetailerCode, ({_CatalogEntry entry, double score})> best = {};

  for (final entry in _catalog) {
    double score = 0;

    for (final kw in entry.keywords) {
      // ── Pass 1: exact phrase ────────────────────────────────────────────
      if (normalized.contains(kw) || kw.contains(normalized)) {
        score = score < 3.0 ? 3.0 : score;
        continue;
      }

      // ── Pass 2: compound-word (strip spaces both sides) ─────────────────
      final kwCompact = kw.replaceAll(' ', '');
      if (kwCompact.length > 3 &&
          (normalizedCompact.contains(kwCompact) ||
              kwCompact.contains(normalizedCompact))) {
        score = score < 2.5 ? 2.5 : score;
        continue;
      }

      // ── Pass 3: token-level substring ───────────────────────────────────
      for (final token in tokens) {
        if (token.length > 2 && (kw.contains(token) || token.contains(kw))) {
          score = score < 1.5 ? 1.5 : score;
        }
      }

      // ── Pass 4: fuzzy per-token (Levenshtein) ───────────────────────────
      for (final token in tokens) {
        if (token.length < 4) continue;
        for (final kwWord in kw.split(' ')) {
          if (kwWord.length < 4) continue;
          final maxDist =
              (token.length >= 7 || kwWord.length >= 7) ? 2 : 1;
          if (_editDistance(token, kwWord) <= maxDist) {
            score = score < 1.2 ? 1.2 : score;
          }
        }
      }
    }

    // Boost for matching preferred brand
    if (preferredBrand != null &&
        entry.brand != null &&
        entry.brand!.toLowerCase().contains(preferredBrand.toLowerCase())) {
      score += 0.5;
    }
    if (score == 0) continue;

    final existing = best[entry.retailer];
    if (existing == null ||
        score > existing.score ||
        (score == existing.score &&
            entry.confidence > existing.entry.confidence)) {
      best[entry.retailer] = (entry: entry, score: score);
    }
  }

  return RetailerCode.values.map((code) {
    final found = best[code];
    if (found == null) {
      return RetailerQuote(
        retailerCode: code,
        matchType: MatchType.notFound,
        isAvailable: false,
        confidenceScore: 0,
      );
    }
    final e = found.entry;
    return RetailerQuote(
      retailerCode: code,
      productId:
          '${code.name}_${e.productName.replaceAll(' ', '_').toLowerCase()}',
      productName: e.productName,
      brand: e.brand,
      sizeLabel: e.sizeLabel,
      price: e.price,
      currency: 'KES',
      isAvailable: true,
      matchType: e.matchType,
      confidenceScore: e.confidence,
    );
  }).toList();
}

/// Wagner-Fischer Levenshtein edit distance.
/// Bails out early if the length difference alone exceeds [maxDist].
static int _editDistance(String a, String b) {
  if ((a.length - b.length).abs() > 3) return 99;
  final m = a.length, n = b.length;
  final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) dp[i][0] = i;
  for (var j = 0; j <= n; j++) dp[0][j] = j;
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      dp[i][j] = a[i - 1] == b[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                .reduce((x, y) => x < y ? x : y);
    }
  }
  return dp[m][n];
}
```

---

## 6. Authentication Service
**File:** `lib/services/supabase_auth_service.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

class SupabaseAuthService {
  bool get isReady {
    try {
      return SupabaseService.client.auth.currentSession != null || true;
    } catch (_) {
      return false;
    }
  }

  User? get currentSupabaseUser {
    try {
      return SupabaseService.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get hasActiveSession => currentSupabaseUser != null;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return SupabaseService.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) {
    return SupabaseService.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<void> signOut() async {
    try {
      await SupabaseService.auth.signOut();
    } catch (error) {
      debugPrint('Supabase signOut skipped: $error');
    }
  }

  Future<void> updateUserMetadata(Map<String, dynamic> data) async {
    try {
      await SupabaseService.auth.updateUser(UserAttributes(data: data));
    } catch (error) {
      debugPrint('Supabase updateUserMetadata error: $error');
    }
  }

  UserRole inferRoleFromMetadata(User user) {
    final role = user.userMetadata?['role']?.toString();
    return role == UserRole.houseManager.name
        ? UserRole.houseManager
        : UserRole.owner;
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) {
    return SupabaseService.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
  }

  Future<void> resendOtp({required String email}) async {
    await SupabaseService.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }
}
```

---

## 7. Backend Sync Service (excerpt)
**File:** `lib/services/sync_service.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Handles two-way synchronisation between the local device cache and the
/// Supabase backend. Each household's data is isolated by [householdId].
class SyncService {
  static final _db = SupabaseService.client;

  /// True when the Supabase client has an authenticated user.
  static bool get isAuthenticated => _db.auth.currentUser != null;

  /// Fetches all rows for [table] belonging to [householdId].
  /// Returns null (rather than throwing) on network/auth failure so callers
  /// can gracefully fall back to the local SharedPreferences cache.
  static Future<List<T>?> fetchAll<T>(
    String table,
    String householdId,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    if (!isAuthenticated) return null;
    try {
      final rows = await _db
          .from(table)
          .select()
          .eq('household_id', householdId)
          .order('created_at');
      return rows.map((r) => fromJson(r as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[SyncService] fetchAll $table error: $e');
      return null;
    }
  }

  /// Upserts the full list for [table] / [householdId] to Supabase.
  static Future<void> save<T>(
    String table,
    String householdId,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    if (!isAuthenticated) return;
    try {
      final payload = items
          .map((item) => {
                ...toJson(item),
                'household_id': householdId,
              })
          .toList();
      await _db.from(table).upsert(payload);
    } catch (e) {
      debugPrint('[SyncService] save $table error: $e');
    }
  }

  /// Ensure the current auth user has a row in app_household_members.
  static Future<void> ensureHouseholdMember(
    String householdId, {
    String? fullName,
    String? displayEmail,
  }) async {
    if (!isAuthenticated) return;
    try {
      await _db.from('app_household_members').upsert({
        'user_id': _db.auth.currentUser!.id,
        'household_id': householdId,
        if (fullName != null) 'full_name': fullName,
        if (displayEmail != null) 'display_email': displayEmail,
      });
    } catch (e) {
      debugPrint('[SyncService] ensureHouseholdMember error: $e');
    }
  }
}
```

---

## DECLARATION

I declare that:

1. The source code excerpts reproduced above are original works authored by me/us.
2. The code was written in the Dart programming language using the Flutter cross-platform framework.
3. The complete source code for this application contains approximately **[X] lines of code** across **[X] source files**.
4. This application has not been published as open source and no licence has been granted to any third party.
5. The application is identified by the working title **HomeFlow** and is designed to run on Android and iOS mobile platforms.

**Applicant Name:** ___________________________________

**Signature:** ___________________________________

**Date:** 26 April 2026

**ID / Registration Number (if applicable):** ___________________________________

---

*End of Source Code Deposit Document*
