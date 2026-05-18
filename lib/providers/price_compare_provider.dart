import 'package:flutter/foundation.dart';
import '../models/retailer_quote.dart';
import '../models/shopping_request.dart';
import '../models/supply_item.dart';
import '../services/retailer_catalog_service.dart';
import '../services/price_scraper_service.dart';
import '../services/product_preference_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRICE COMPARE PROVIDER
// Manages retailer quotes, user store selections, and basket totals.
// ─────────────────────────────────────────────────────────────────────────────

enum CompareMode { bestMix, carrefourOnly, naivasOnly }

class PriceCompareProvider extends ChangeNotifier {
  final Map<String, ItemCompareResult> _quotes = {};

  /// Manual or auto store selection per item ID.
  final Map<String, RetailerCode?> _selections = {};

  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchedAt;

  // Live-price refresh state
  bool _isRefreshingLive = false;
  bool _liveHadErrors = false;
  DateTime? _livePricesUpdatedAt;
  int _liveProductCount = 0;

  // ─── Getters ──────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAnyQuotes => _quotes.isNotEmpty;
  DateTime? get lastFetchedAt => _lastFetchedAt;
  bool get isRefreshingLive => _isRefreshingLive;
  bool get liveHadErrors => _liveHadErrors;
  DateTime? get livePricesUpdatedAt => _livePricesUpdatedAt;
  int get liveProductCount => _liveProductCount;
  bool get hasLivePrices => _livePricesUpdatedAt != null && _liveProductCount > 0;

  ItemCompareResult? quoteFor(String itemId) => _quotes[itemId];
  RetailerCode? selectionFor(String itemId) => _selections[itemId];

  /// True if selection was set manually (not from auto-cheapest logic).
  bool isManualSelection(String itemId) =>
      _selections.containsKey(itemId) &&
      _selections[itemId] != _quotes[itemId]?.cheapestRetailer;

  // ─── Fetch ────────────────────────────────────────────────────────────────

  Future<void> fetchForShoppingItems({
    required List<ShoppingRequest> requests,
    required List<SupplyItem> finishedSupplies,
  }) async {
    final items = <({String id, String name, String? brand})>[];

    for (final r in requests) {
      items.add((id: r.id, name: r.itemName, brand: null));
    }
    for (final s in finishedSupplies) {
      items.add((id: s.id, name: s.name, brand: s.preferredBrand));
    }

    final currentIds = items.map((i) => i.id).toSet();
    final hadStaleQuotes = _quotes.keys.any((id) => !currentIds.contains(id));
    final hadStaleSelections =
        _selections.keys.any((id) => !currentIds.contains(id));

    _quotes.removeWhere((id, _) => !currentIds.contains(id));
    _selections.removeWhere((id, _) => !currentIds.contains(id));

    if (items.isEmpty) {
      _errorMessage = null;
      _lastFetchedAt = null;
      if (hadStaleQuotes || hadStaleSelections) {
        notifyListeners();
      }
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await RetailerCatalogService.fetchQuotes(items);
      for (final r in results) {
        _quotes[r.itemId] = r;
        // Default to cheapest if no manual override exists
        if (!_selections.containsKey(r.itemId)) {
          _selections[r.itemId] = r.cheapestRetailer;
        }
      }
      _lastFetchedAt = DateTime.now();
    } catch (e) {
      _errorMessage = 'Could not load prices. Please try again.';
      debugPrint('[PriceCompareProvider] fetch error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Selection ────────────────────────────────────────────────────────────

  void setSelection(String itemId, RetailerCode? code) {
    _selections[itemId] = code;
    notifyListeners();
  }

  void resetToAuto(String itemId) {
    _selections[itemId] = _quotes[itemId]?.cheapestRetailer;
    notifyListeners();
  }

  /// Overrides the auto-matched product for [itemId] / [code] with the user's
  /// explicit selection. Rebuilds the ItemCompareResult so basket totals update
  /// immediately, sets the store selection, and persists via ProductPreferenceStore.
  void setMatchedProduct(String itemId, RetailerCode code, RetailerQuote quote) {
    final existing = _quotes[itemId];
    if (existing == null) return;
    final updatedQuotes = existing.quotes
        .where((q) => q.retailerCode != code)
        .toList()
      ..add(quote);
    _quotes[itemId] = ItemCompareResult(
      itemId: existing.itemId,
      itemName: existing.itemName,
      preferredBrand: existing.preferredBrand,
      quotes: updatedQuotes,
      fetchedAt: existing.fetchedAt,
    );
    _selections[itemId] = code;
    notifyListeners();
    if (quote.productId != null) {
      ProductPreferenceStore.save(existing.itemName, code, quote.productId!);
    }
  }

  /// Apply a compare mode to ALL items in the list.
  void applyModeToAll(CompareMode mode, List<String> itemIds) {
    for (final id in itemIds) {
      switch (mode) {
        case CompareMode.bestMix:
          _selections[id] = _quotes[id]?.cheapestRetailer;
        case CompareMode.carrefourOnly:
          final q = _quotes[id]?.quoteFor(RetailerCode.carrefour);
          _selections[id] = (q?.hasPrice == true) ? RetailerCode.carrefour : null;
        case CompareMode.naivasOnly:
          final q = _quotes[id]?.quoteFor(RetailerCode.naivas);
          _selections[id] = (q?.hasPrice == true) ? RetailerCode.naivas : null;
      }
    }
    notifyListeners();
  }

  // ─── Basket summary ───────────────────────────────────────────────────────

  BasketSummary computeBasketSummary(List<String> itemIds) {
    double carrefourTotal = 0;
    double naivasTotal = 0;
    double bestMixTotal = 0;
    int unmatched = 0;
    int carrefourCoverage = 0;
    int naivasCoverage = 0;

    for (final id in itemIds) {
      final result = _quotes[id];
      if (result == null || !result.hasAnyPrice) {
        unmatched++;
        continue;
      }

      final cq = result.quoteFor(RetailerCode.carrefour);
      final nq = result.quoteFor(RetailerCode.naivas);

      if (cq?.hasPrice == true) {
        carrefourTotal += cq!.price!;
        carrefourCoverage++;
      }
      if (nq?.hasPrice == true) {
        naivasTotal += nq!.price!;
        naivasCoverage++;
      }
      final cheapest = result.lowestPrice;
      if (cheapest != null) {
        bestMixTotal += cheapest;
      }
    }

    return BasketSummary(
      carrefourTotal: carrefourCoverage > 0 ? carrefourTotal : null,
      naivasTotal: naivasCoverage > 0 ? naivasTotal : null,
      bestMixTotal:
          (carrefourCoverage > 0 || naivasCoverage > 0) ? bestMixTotal : null,
      unmatchedCount: unmatched,
      carrefourCoverage: carrefourCoverage,
      naivasCoverage: naivasCoverage,
      totalItems: itemIds.length,
    );
  }

  /// Selected retailer price for a specific item.
  double? selectedPriceFor(String itemId) {
    final code = _selections[itemId];
    if (code == null) return null;
    return _quotes[itemId]?.quoteFor(code)?.price;
  }

  void clearAll() {
    _quotes.clear();
    _selections.clear();
    _lastFetchedAt = null;
    notifyListeners();
  }

  // ─── Live price refresh ───────────────────────────────────────────────────

  /// Scrapes carrefour.ke and naivas.online for fresh prices, then re-fetches
  /// all currently-loaded quote items with the new data overlaid.
  Future<void> refreshLivePrices({
    required List<ShoppingRequest> requests,
    required List<SupplyItem> finishedSupplies,
  }) async {
    if (_isRefreshingLive) return;
    _isRefreshingLive = true;
    _liveHadErrors = false;
    notifyListeners();

    try {
      final result = await PriceScraperService.refresh();
      _liveProductCount = result.products.length;
      _liveHadErrors = result.hadErrors;
      if (result.products.isNotEmpty) {
        _livePricesUpdatedAt = await PriceScraperService.cacheTimestamp();
        // Re-run quote fetch so catalog overlays the new scraped prices
        await fetchForShoppingItems(
          requests: requests,
          finishedSupplies: finishedSupplies,
        );
      }
    } catch (e) {
      _liveHadErrors = true;
      debugPrint('[PriceCompareProvider] live refresh error: $e');
    }

    _isRefreshingLive = false;
    notifyListeners();
  }

  /// Called at app start to surface any already-cached live timestamp in the
  /// UI without triggering a network request.
  Future<void> loadCachedLiveTimestamp() async {
    _livePricesUpdatedAt = await PriceScraperService.cacheTimestamp();
    final cached = await PriceScraperService.getCached();
    _liveProductCount = cached?.length ?? 0;
    notifyListeners();
  }
}
