import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RETAILER CONFIG
// New retailers can be added here without touching UI logic.
// ─────────────────────────────────────────────────────────────────────────────

enum RetailerCode { carrefour, naivas }

enum MatchType { exact, nearMatch, categoryAlternative, notFound }

class RetailerInfo {
  final RetailerCode code;
  final String name;
  final Color brandColor;
  final Color brandColorLight;

  const RetailerInfo({
    required this.code,
    required this.name,
    required this.brandColor,
    required this.brandColorLight,
  });

  static const carrefour = RetailerInfo(
    code: RetailerCode.carrefour,
    name: 'Carrefour',
    brandColor: Color(0xFF006EB6),
    brandColorLight: Color(0xFFE3F2FD),
  );

  static const naivas = RetailerInfo(
    code: RetailerCode.naivas,
    name: 'Naivas',
    brandColor: Color(0xFFD84315),
    brandColorLight: Color(0xFFFBE9E7),
  );

  static const List<RetailerInfo> all = [carrefour, naivas];

  static RetailerInfo forCode(RetailerCode code) =>
      all.firstWhere((r) => r.code == code);
}

// ─────────────────────────────────────────────────────────────────────────────
// QUOTE — one retailer's price for a single item
// ─────────────────────────────────────────────────────────────────────────────

class RetailerQuote {
  final RetailerCode retailerCode;
  final String? productId;
  final String? productName;
  final String? brand;
  final String? sizeLabel;
  final double? price;
  final String currency;
  final bool isAvailable;
  final MatchType matchType;
  final double confidenceScore;
  final String? deepLinkUrl;
  final bool isLivePrice;

  const RetailerQuote({
    required this.retailerCode,
    this.productId,
    this.productName,
    this.brand,
    this.sizeLabel,
    this.price,
    this.currency = 'KES',
    this.isAvailable = true,
    required this.matchType,
    this.confidenceScore = 1.0,
    this.deepLinkUrl,
    this.isLivePrice = false,
  });

  RetailerQuote copyWith({double? price, bool? isLivePrice}) => RetailerQuote(
        retailerCode: retailerCode,
        productId: productId,
        productName: productName,
        brand: brand,
        sizeLabel: sizeLabel,
        price: price ?? this.price,
        currency: currency,
        isAvailable: isAvailable,
        matchType: matchType,
        confidenceScore: confidenceScore,
        deepLinkUrl: deepLinkUrl,
        isLivePrice: isLivePrice ?? this.isLivePrice,
      );

  bool get hasPrice => price != null && isAvailable;
  RetailerInfo get info => RetailerInfo.forCode(retailerCode);

  /// Short label shown in compact chip.
  String get shortPriceLabel {
    if (!isAvailable) return 'Out of stock';
    if (price == null) return 'Unavailable';
    final prefix =
        (matchType == MatchType.nearMatch || matchType == MatchType.categoryAlternative)
            ? 'From '
            : '';
    return '$prefix${price!.toStringAsFixed(0)}';
  }

  /// Full label shown in detail rows.
  String get fullPriceLabel {
    if (!isAvailable) return 'Out of stock';
    if (price == null) return 'Price unavailable';
    final prefix =
        (matchType == MatchType.nearMatch || matchType == MatchType.categoryAlternative)
            ? 'From '
            : '';
    return '${prefix}KES ${price!.toStringAsFixed(0)}';
  }

  String get matchTypeLabel {
    switch (matchType) {
      case MatchType.exact:
        return 'Exact match';
      case MatchType.nearMatch:
        return 'Similar size';
      case MatchType.categoryAlternative:
        return 'Alternative brand';
      case MatchType.notFound:
        return 'Not found';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM COMPARE RESULT — all quotes for one list item
// ─────────────────────────────────────────────────────────────────────────────

class ItemCompareResult {
  final String itemId;
  final String itemName;
  final String? preferredBrand;
  final List<RetailerQuote> quotes;
  final DateTime fetchedAt;

  ItemCompareResult({
    required this.itemId,
    required this.itemName,
    this.preferredBrand,
    required this.quotes,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  RetailerQuote? quoteFor(RetailerCode code) =>
      quotes.where((q) => q.retailerCode == code).firstOrNull;

  RetailerCode? get cheapestRetailer {
    RetailerCode? best;
    double? bestPrice;
    for (final q in quotes) {
      if (q.hasPrice && (bestPrice == null || q.price! < bestPrice)) {
        best = q.retailerCode;
        bestPrice = q.price;
      }
    }
    return best;
  }

  double? get lowestPrice {
    double? best;
    for (final q in quotes) {
      if (q.hasPrice && (best == null || q.price! < best)) {
        best = q.price;
      }
    }
    return best;
  }

  bool get hasAnyPrice => quotes.any((q) => q.hasPrice);

  RetailerCode? get mostExpensiveRetailer {
    RetailerCode? worst;
    double? worstPrice;
    for (final q in quotes) {
      if (q.hasPrice && (worstPrice == null || q.price! > worstPrice)) {
        worst = q.retailerCode;
        worstPrice = q.price;
      }
    }
    return worst;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BASKET SUMMARY — totals across all items
// ─────────────────────────────────────────────────────────────────────────────

class BasketSummary {
  final double? carrefourTotal;
  final double? naivasTotal;
  final double? bestMixTotal;
  final int unmatchedCount;
  final int carrefourCoverage;
  final int naivasCoverage;
  final int totalItems;

  const BasketSummary({
    this.carrefourTotal,
    this.naivasTotal,
    this.bestMixTotal,
    required this.unmatchedCount,
    required this.carrefourCoverage,
    required this.naivasCoverage,
    required this.totalItems,
  });

  double? get bestSavings {
    if (bestMixTotal == null) return null;
    final worst = [carrefourTotal, naivasTotal]
        .whereType<double>()
        .fold<double?>(null, (max, v) => (max == null || v > max) ? v : max);
    if (worst == null) return null;
    final savings = worst - bestMixTotal!;
    return savings > 0 ? savings : null;
  }

  RetailerCode? get cheapestSingleStore {
    if (carrefourTotal != null && naivasTotal != null) {
      return carrefourTotal! <= naivasTotal!
          ? RetailerCode.carrefour
          : RetailerCode.naivas;
    }
    if (carrefourTotal != null) return RetailerCode.carrefour;
    if (naivasTotal != null) return RetailerCode.naivas;
    return null;
  }

  double? totalFor(RetailerCode code) =>
      code == RetailerCode.carrefour ? carrefourTotal : naivasTotal;
  int coverageFor(RetailerCode code) =>
      code == RetailerCode.carrefour ? carrefourCoverage : naivasCoverage;
}
