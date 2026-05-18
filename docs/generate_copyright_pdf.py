#!/usr/bin/env python3
"""
Generates docs/copyright-source-code-samples.pdf from embedded content.
Run with: /Users/macbookpro2/myapp/.venv/bin/python docs/generate_copyright_pdf.py
"""

from fpdf import FPDF
import os

OUTPUT = os.path.join(os.path.dirname(__file__), "copyright-source-code-samples.pdf")

# ── Content ────────────────────────────────────────────────────────────────────

COVER = {
    "title": "SOURCE CODE DEPOSIT",
    "subtitle": "COPYRIGHT REGISTRATION APPLICATION",
    "lines": [
        ("Software Title:", "HomeFlow"),
        ("Nature of Work:", "Mobile Application Software (Flutter / Dart)"),
        ("Author / Owner:", "[YOUR FULL LEGAL NAME / COMPANY NAME]"),
        ("Date of Creation:", "2025 - 2026"),
        ("Platform:", "Android & iOS (cross-platform)"),
    ],
    "notice": (
        "The following pages contain representative source code excerpts from the HomeFlow "
        "mobile application. This deposit is submitted in support of a copyright registration "
        "application. All code was authored originally by the applicant and has not been "
        "published or licensed to any third party."
    ),
}

SECTIONS = [
    {
        "title": "1. Application Entry Point",
        "file": "lib/main.dart",
        "description": "Application bootstrap, dependency injection, and router configuration.",
        "code": """\
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/supply_provider.dart';
import 'providers/meal_provider.dart';
import 'providers/price_compare_provider.dart';
import 'services/supabase_service.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const HomeFlowApp());
}

class HomeFlowApp extends StatelessWidget {
  const HomeFlowApp({super.key});

  static final GoRouter _router = GoRouter(
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
        path: '/admin/households/:id',
        builder: (context, state) => AdminPanelScreen(
          selectedIndex: 1,
          child: AdminHouseholdDetailPage(
            householdId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
    ],
  );
}""",
    },
    {
        "title": "2. Data Model - Supply Item",
        "file": "lib/models/supply_item.dart",
        "description": "Core domain model representing a tracked household supply item, including usage logs and role visibility.",
        "code": """\
enum SupplyStatus { enough, runningLow, veryLow, finished }

class SupplyUsageEntry {
  final DateTime date;
  final double quantity;
  final String? notes;
  final double? price;          // KES cost for this restock
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
        price: json['price'] != null
            ? (json['price'] as num).toDouble()
            : null,
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
  // When true, hidden from house managers - owner eyes only
  final bool isOwnerOnly;
  // Home Pro analytics usage log
  final List<SupplyUsageEntry> usageLogs;
  final DateTime? statusUpdatedAt;
  final String? statusUpdatedByName;
}""",
    },
    {
        "title": "3. Data Model - Shopping Request",
        "file": "lib/models/shopping_request.dart",
        "description": "Models the complete shopping workflow including urgency levels, approval states, and purchase types.",
        "code": """\
enum ShoppingUrgency { neededSoon, neededToday, critical }
enum ShoppingStatus  { requested, seen, approved, purchased, deferred }

// Who originated the entry and through what flow:
//  managerRequest   - manager noticed low stock, awaits owner approval
//  ownerPurchase    - owner's personal buy list (no approval needed)
//  managerDirectBuy - manager bought immediately (emergency / small item)
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

  // True if manager request is still awaiting owner decision
  bool get needsApproval =>
      purchaseType == PurchaseType.managerRequest &&
      (status == ShoppingStatus.requested ||
       status == ShoppingStatus.seen);

  bool get isOwnerPurchase =>
      purchaseType == PurchaseType.ownerPurchase;

  bool get wasBuyAnyway => buyAnywayReason != null;
}""",
    },
    {
        "title": "4. State Management - Supply Provider",
        "file": "lib/providers/supply_provider.dart",
        "description": "ChangeNotifier provider managing supply tracking, shopping requests, and Supabase ↔ local-cache synchronisation.",
        "code": """\
class SupplyProvider extends ChangeNotifier {
  List<SupplyItem>       _supplies         = [];
  List<ShoppingRequest>  _shoppingRequests = [];
  bool                   _isLoading        = false;

  // Role-aware supply list
  List<SupplyItem> visibleSupplies({required bool isOwner}) =>
      isOwner ? _supplies
              : _supplies.where((s) => !s.isOwnerOnly).toList();

  List<SupplyItem> get lowStockItems =>
      _supplies.where((s) => s.needsAttention).toList();

  List<SupplyItem> get finishedSupplies =>
      _supplies.where((s) => s.status == SupplyStatus.finished).toList();

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

  List<ShoppingRequest> get ownerBuyList => _shoppingRequests
      .where((r) =>
          r.purchaseType == PurchaseType.ownerPurchase &&
          r.status != ShoppingStatus.purchased &&
          r.status != ShoppingStatus.deferred)
      .toList();

  Future<void> loadData(String householdId) async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final remoteSupplies = await SyncService.fetchAll(
        'app_supplies', householdId, SupplyItem.fromJson);
    if (remoteSupplies != null) {
      _supplies = remoteSupplies;
      await prefs.setString('supplies_$householdId',
          jsonEncode(_supplies.map((s) => s.toJson()).toList()));
    } else {
      final json = prefs.getString('supplies_$householdId');
      if (json != null) {
        _supplies = (jsonDecode(json) as List)
            .map((e) => SupplyItem.fromJson(e)).toList();
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
    await prefs.setString('shopping_requests_$householdId',
        jsonEncode(_shoppingRequests.map((r) => r.toJson()).toList()));
    await SyncService.save('app_shopping_requests', householdId,
        _shoppingRequests, (r) => r.toJson());
  }

  Future<void> removeSupplyItem(
      String supplyId, String householdId) async {
    _supplies.removeWhere((s) => s.id == supplyId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supplies_$householdId',
        jsonEncode(_supplies.map((s) => s.toJson()).toList()));
    await SyncService.save('app_supplies', householdId,
        _supplies, (s) => s.toJson());
  }
}""",
    },
    {
        "title": "5. Business Logic - Retailer Price Comparison & Fuzzy Matching",
        "file": "lib/services/retailer_catalog_service.dart",
        "description": (
            "Original 4-pass fuzzy matching algorithm that resolves a user-typed item name "
            "to catalog entries for Carrefour Kenya and Naivas Supermarket. "
            "Includes Wagner-Fischer Levenshtein edit-distance implementation."
        ),
        "code": """\
// 4-pass fuzzy matching algorithm
// Pass 1: Exact phrase containment           (score 3.0)
// Pass 2: Compound-word / no-space match     (score 2.5)
//         e.g. "cornflakes" <-> "corn flakes"
// Pass 3: Token-level substring              (score 1.5)
// Pass 4: Per-token Levenshtein distance     (score 1.2)
//         <= 1 edit for short words, <= 2 for long words

static List<RetailerQuote> quotesForItem(
  String itemName, {String? preferredBrand}) {

  final normalized = itemName.toLowerCase().trim();
  final normalizedCompact =
      normalized.replaceAll(RegExp(r'\\s+'), '');
  final tokens = normalized
      .split(RegExp(r'[\\s/,]+'))
      .where((t) => t.length > 2)
      .toList();

  final Map<RetailerCode,
        ({_CatalogEntry entry, double score})> best = {};

  for (final entry in _catalog) {
    double score = 0;

    for (final kw in entry.keywords) {
      // Pass 1: exact phrase
      if (normalized.contains(kw) || kw.contains(normalized)) {
        score = score < 3.0 ? 3.0 : score;
        continue;
      }
      // Pass 2: compound-word
      final kwCompact = kw.replaceAll(' ', '');
      if (kwCompact.length > 3 &&
          (normalizedCompact.contains(kwCompact) ||
           kwCompact.contains(normalizedCompact))) {
        score = score < 2.5 ? 2.5 : score;
        continue;
      }
      // Pass 3: token substring
      for (final token in tokens) {
        if (token.length > 2 &&
            (kw.contains(token) || token.contains(kw))) {
          score = score < 1.5 ? 1.5 : score;
        }
      }
      // Pass 4: Levenshtein fuzzy
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
    if (score == 0) continue;
    final existing = best[entry.retailer];
    if (existing == null || score > existing.score) {
      best[entry.retailer] = (entry: entry, score: score);
    }
  }
  return RetailerCode.values.map((code) {
    final found = best[code];
    if (found == null) return RetailerQuote(
      retailerCode: code, matchType: MatchType.notFound,
      isAvailable: false, confidenceScore: 0);
    final e = found.entry;
    return RetailerQuote(
      retailerCode: code,
      productName: e.productName, brand: e.brand,
      sizeLabel: e.sizeLabel,    price: e.price,
      currency: 'KES',           isAvailable: true,
      matchType: e.matchType,    confidenceScore: e.confidence);
  }).toList();
}

// Wagner-Fischer Levenshtein edit distance
static int _editDistance(String a, String b) {
  if ((a.length - b.length).abs() > 3) return 99;
  final m = a.length, n = b.length;
  final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
  for (var i = 0; i <= m; i++) dp[i][0] = i;
  for (var j = 0; j <= n; j++) dp[0][j] = j;
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      dp[i][j] = a[i-1] == b[j-1]
          ? dp[i-1][j-1]
          : 1 + [dp[i-1][j], dp[i][j-1], dp[i-1][j-1]]
                .reduce((x, y) => x < y ? x : y);
    }
  }
  return dp[m][n];
}""",
    },
    {
        "title": "6. Authentication Service",
        "file": "lib/services/supabase_auth_service.dart",
        "description": "Wraps Supabase GoTrue auth: sign-up, sign-in, OTP verification, role inference from user metadata.",
        "code": """\
class SupabaseAuthService {
  bool get hasActiveSession =>
      SupabaseService.auth.currentUser != null;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) => SupabaseService.auth.signInWithPassword(
        email: email, password: password);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) => SupabaseService.auth.signUp(
        email: email, password: password, data: data);

  Future<void> signOut() async {
    try {
      await SupabaseService.auth.signOut();
    } catch (e) {
      debugPrint('signOut skipped: $e');
    }
  }

  // Infer household role from Supabase user metadata
  UserRole inferRoleFromMetadata(User user) {
    final role = user.userMetadata?['role']?.toString();
    return role == UserRole.houseManager.name
        ? UserRole.houseManager
        : UserRole.owner;
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) => SupabaseService.auth.verifyOTP(
        email: email, token: token, type: OtpType.signup);

  Future<void> resendOtp({required String email}) =>
      SupabaseService.auth.resend(
          type: OtpType.signup, email: email);
}""",
    },
    {
        "title": "7. Backend Sync Service",
        "file": "lib/services/sync_service.dart",
        "description": "Two-way synchronisation between local SharedPreferences cache and Supabase, with graceful offline fallback.",
        "code": """\
class SyncService {
  static final _db = SupabaseService.client;
  static bool get isAuthenticated =>
      _db.auth.currentUser != null;

  // Fetch all rows for [table] / [householdId].
  // Returns null on failure so callers fall back to local cache.
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
      return rows
          .map((r) => fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SyncService] fetchAll $table: $e');
      return null;
    }
  }

  // Upsert full list to Supabase.
  static Future<void> save<T>(
    String table,
    String householdId,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    if (!isAuthenticated) return;
    try {
      final payload = items.map((item) => {
            ...toJson(item), 'household_id': householdId,
          }).toList();
      await _db.from(table).upsert(payload);
    } catch (e) {
      debugPrint('[SyncService] save $table: $e');
    }
  }

  // Ensure the auth user has a membership row in the household.
  static Future<void> ensureHouseholdMember(
    String householdId, {
    String? fullName,
    String? displayEmail,
  }) async {
    if (!isAuthenticated) return;
    await _db.from('app_household_members').upsert({
      'user_id': _db.auth.currentUser!.id,
      'household_id': householdId,
      if (fullName != null) 'full_name': fullName,
      if (displayEmail != null) 'display_email': displayEmail,
    });
  }
}""",
    },
]

DECLARATION = [
    "I declare that:",
    "",
    "1. The source code excerpts reproduced in this document are original works authored by me/us.",
    "2. The code was written in the Dart programming language using the Flutter cross-platform framework.",
    "3. The complete source code for this application comprises multiple source files across",
    "   lib/models/, lib/providers/, lib/services/, lib/screens/, and lib/utils/ directories.",
    "4. This application has not been published as open source and no licence has been granted",
    "   to any third party.",
    "5. The application is identified by the working title HomeFlow and is designed to run",
    "   on Android and iOS mobile platforms.",
    "",
    "",
    "Applicant Name:  ___________________________________________",
    "",
    "Signature:       ___________________________________________",
    "",
    "Date:            26 April 2026",
    "",
    "ID / Reg. No.:   ___________________________________________",
]


# ── PDF builder ───────────────────────────────────────────────────────────────

class PDF(FPDF):
    def safe(self, text):
        return s(str(text))

    def normalize_text(self, text):
        # Replace any character that can't be encoded in latin-1 with '?'
        return text.encode('latin-1', errors='replace').decode('latin-1')

    def header(self):
        if self.page_no() == 1:
            return
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(140, 140, 140)
        self.cell(0, 6, "HomeFlow - Source Code Deposit for Copyright Registration", align="L")
        self.cell(0, 6, f"Page {self.page_no()}", align="R", new_x="LMARGIN", new_y="NEXT")
        self.set_text_color(0, 0, 0)
        self.ln(2)

    def footer(self):
        self.set_y(-12)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(160, 160, 160)
        self.cell(0, 6, "CONFIDENTIAL - For copyright registration purposes only", align="C")
        self.set_text_color(0, 0, 0)


def s(text):
    """Replace non-latin-1 characters for FPDF core fonts."""
    return (text
            .replace('\u2013', '-')
            .replace('\u2014', '-')
            .replace('\u2019', "'")
            .replace('\u2018', "'")
            .replace('\u201c', '"')
            .replace('\u201d', '"')
            .replace('\u2026', '...')
            .replace('\u2192', '->')
            .replace('\u2190', '<-')
            .replace('\u00a0', ' ')
            )


def build_pdf():
    pdf = PDF()
    pdf.set_auto_page_break(auto=True, margin=18)
    pdf.set_margins(20, 20, 20)

    # ── Cover page ──────────────────────────────────────────────────────────
    pdf.add_page()
    pdf.set_fill_color(30, 90, 120)
    pdf.rect(0, 0, 210, 60, "F")

    pdf.set_y(12)
    pdf.set_font("Helvetica", "B", 22)
    pdf.set_text_color(255, 255, 255)
    pdf.cell(0, 12, COVER["title"], align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 13)
    pdf.cell(0, 8, COVER["subtitle"], align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(0, 0, 0)

    pdf.ln(14)
    pdf.set_font("Helvetica", "B", 11)
    pdf.set_fill_color(240, 245, 248)
    pdf.set_draw_color(180, 200, 210)

    w = pdf.w - 40
    for label, value in COVER["lines"]:
        pdf.cell(w, 9, f"  {label}  {value}", border=1, fill=True,
                 new_x="LMARGIN", new_y="NEXT")

    pdf.ln(10)
    pdf.set_font("Helvetica", "I", 10)
    pdf.set_text_color(60, 60, 60)
    pdf.set_fill_color(255, 250, 230)
    pdf.set_draw_color(200, 180, 80)
    pdf.multi_cell(w, 6, COVER["notice"], border=1, fill=True)
    pdf.set_text_color(0, 0, 0)

    # ── Table of contents ───────────────────────────────────────────────────
    pdf.ln(12)
    pdf.set_font("Helvetica", "B", 13)
    pdf.set_draw_color(30, 90, 120)
    pdf.set_fill_color(30, 90, 120)
    pdf.set_text_color(255, 255, 255)
    pdf.cell(w, 9, "  TABLE OF CONTENTS", fill=True,
             new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(0, 0, 0)
    pdf.set_fill_color(255, 255, 255)
    pdf.set_font("Helvetica", "", 10)
    for i, sec in enumerate(SECTIONS, 1):
        pdf.cell(w, 7, s(f"  {sec['title']}  -  {sec['file']}"),
                 border="B", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(w, 7, "  Declaration & Signature",
             border="B", new_x="LMARGIN", new_y="NEXT")

    # ── Code sections ───────────────────────────────────────────────────────
    for sec in SECTIONS:
        pdf.add_page()

        # Section heading bar
        pdf.set_fill_color(30, 90, 120)
        pdf.set_text_color(255, 255, 255)
        pdf.set_font("Helvetica", "B", 12)
        pdf.cell(w, 9, s(f"  {sec['title']}"), fill=True,
                 new_x="LMARGIN", new_y="NEXT")
        pdf.set_text_color(0, 0, 0)

        # File path badge
        pdf.ln(2)
        pdf.set_font("Courier", "", 9)
        pdf.set_fill_color(235, 235, 235)
        pdf.cell(0, 6, f"  File: {sec['file']}", fill=True,
                 new_x="LMARGIN", new_y="NEXT")

        # Description
        pdf.ln(3)
        pdf.set_font("Helvetica", "", 10)
        pdf.set_text_color(50, 50, 50)
        pdf.multi_cell(0, 5, sec["description"])
        pdf.set_text_color(0, 0, 0)

        # Code block
        pdf.ln(3)
        pdf.set_font("Courier", "", 7.5)
        pdf.set_fill_color(245, 245, 245)
        pdf.set_draw_color(200, 200, 200)

        lines = sec["code"].split("\n")
        lh = 4.2
        block_h = len(lines) * lh + 6
        # Draw background rect
        pdf.set_fill_color(245, 245, 245)
        y_start = pdf.get_y()

        for line in lines:
            # Indent preserved; clip very long lines
            display = line if len(line) <= 105 else line[:102] + "..."
            pdf.cell(0, lh, display, new_x="LMARGIN", new_y="NEXT")

        pdf.set_draw_color(180, 180, 180)
        pdf.ln(2)

    # ── Declaration page ────────────────────────────────────────────────────
    pdf.add_page()
    pdf.set_fill_color(30, 90, 120)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 9, "  DECLARATION", fill=True,
             new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(0, 0, 0)
    pdf.ln(6)

    pdf.set_font("Helvetica", "", 10)
    for line in DECLARATION:
        if line == "":
            pdf.ln(4)
        else:
            pdf.multi_cell(0, 6, line)

    pdf.ln(10)
    pdf.set_font("Helvetica", "I", 8)
    pdf.set_text_color(120, 120, 120)
    pdf.cell(0, 6, "- End of Source Code Deposit Document -", align="C")

    pdf.output(OUTPUT)
    print(f"PDF created: {OUTPUT}")


if __name__ == "__main__":
    build_pdf()
