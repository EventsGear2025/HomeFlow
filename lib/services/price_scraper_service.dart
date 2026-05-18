import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/retailer_quote.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCRAPED PRODUCT
// A (retailer, rawText, price) triple extracted from a live website page.
// ─────────────────────────────────────────────────────────────────────────────

class ScrapedProduct {
  final RetailerCode retailer;
  final String rawText;
  final double price;

  const ScrapedProduct({
    required this.retailer,
    required this.rawText,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
        'r': retailer.index,
        't': rawText,
        'p': price,
      };

  factory ScrapedProduct.fromJson(Map<String, dynamic> j) => ScrapedProduct(
        retailer: RetailerCode.values[j['r'] as int],
        rawText: j['t'] as String,
        price: (j['p'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PRICE SCRAPER SERVICE
// Fetches live prices from carrefour.ke and naivas.online, caches results in
// SharedPreferences for up to 24 hours, and falls back to static catalog when
// scraping fails.
// ─────────────────────────────────────────────────────────────────────────────

class PriceScraperService {
  static const _cacheKey = 'scraped_products_v2';
  static const _tsKey = 'scraped_ts_v2';
  static const _maxCacheAge = Duration(hours: 24);

  // Naivas category pages (server-rendered — SSR HTML likely has product data)
  static const _naivasUrls = [
    'https://www.naivas.online/dairy',
    'https://www.naivas.online/fats-oils',
    'https://www.naivas.online/commodities/sugar-sweeteners',
    'https://www.naivas.online/commodities/rice-cereals',
    'https://www.naivas.online/cleaning',
    'https://www.naivas.online/personal-care',
    'https://www.naivas.online/baby-kids',
    'https://www.naivas.online/food-cupboard',
    'https://www.naivas.online/bakery-confectionery',
  ];

  // Carrefour search pages — may embed product data in __NEXT_DATA__ JSON blob
  static const _carrefourUrls = [
    'https://www.carrefour.ke/mafken/en/search?q=cooking+oil+vegetable',
    'https://www.carrefour.ke/mafken/en/search?q=uht+milk',
    'https://www.carrefour.ke/mafken/en/search?q=sugar+white',
    'https://www.carrefour.ke/mafken/en/search?q=wheat+flour',
    'https://www.carrefour.ke/mafken/en/search?q=basmati+rice',
    'https://www.carrefour.ke/mafken/en/search?q=washing+powder+toss',
    'https://www.carrefour.ke/mafken/en/search?q=toilet+tissue+paper',
    'https://www.carrefour.ke/mafken/en/search?q=baby+diapers+pampers',
    'https://www.carrefour.ke/mafken/en/search?q=bar+soap+menengai',
    'https://www.carrefour.ke/mafken/en/search?q=toothpaste+colgate',
    'https://www.carrefour.ke/mafken/en/search?q=dettol+handwash+antibacterial',
  ];

  static final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate',
    'Connection': 'keep-alive',
  };

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Returns cached products if cache is fresh (< 24 h). Returns null if stale.
  static Future<List<ScrapedProduct>?> getCached() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_tsKey);
    if (ts == null) return null;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > _maxCacheAge) return null;
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ScrapedProduct.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Timestamp of the most recent successful cache write. Null if no cache.
  static Future<DateTime?> cacheTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_tsKey);
    return ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null;
  }

  /// Fetches live prices from both retailers concurrently.
  /// Caches any results found and returns them with a success flag.
  static Future<({List<ScrapedProduct> products, bool hadErrors})>
      refresh() async {
    final results = <ScrapedProduct>[];
    bool hadErrors = false;

    final futures = [
      ..._naivasUrls.map((u) => _fetchPage(u, RetailerCode.naivas)),
      ..._carrefourUrls.map((u) => _fetchPage(u, RetailerCode.carrefour)),
    ];

    final pageResults = await Future.wait(futures, eagerError: false);
    for (final r in pageResults) {
      if (r == null) {
        hadErrors = true;
      } else {
        results.addAll(r);
      }
    }

    if (results.isNotEmpty) {
      await _saveCache(results);
    }

    debugPrint(
      '[PriceScraper] refresh done: ${results.length} products, '
      'hadErrors=$hadErrors',
    );
    return (products: results, hadErrors: hadErrors);
  }

  /// Wipes stored cache so the next fetch will hit the network.
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_tsKey);
  }

  // ─── Internal: fetch ──────────────────────────────────────────────────────

  static Future<List<ScrapedProduct>?> _fetchPage(
    String url,
    RetailerCode retailer,
  ) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        debugPrint('[PriceScraper] HTTP ${res.statusCode} for $url');
        return null;
      }
      final products = _parse(res.body, retailer);
      debugPrint(
        '[PriceScraper] ${retailer.name} $url → ${products.length} products',
      );
      return products;
    } catch (e) {
      debugPrint('[PriceScraper] error fetching $url: $e');
      return null;
    }
  }

  // ─── Internal: parse ──────────────────────────────────────────────────────

  static List<ScrapedProduct> _parse(String html, RetailerCode retailer) {
    // Strategy 1: Next.js __NEXT_DATA__ (Carrefour uses Next.js)
    final nextDataMatch = RegExp(
      r'<script[^>]+id="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>',
    ).firstMatch(html);
    if (nextDataMatch != null) {
      final from = _parseNextData(nextDataMatch.group(1)!, retailer);
      if (from.isNotEmpty) return from;
    }

    // Strategy 2: schema.org JSON-LD product markup
    final fromLd = _parseJsonLd(html, retailer);
    if (fromLd.isNotEmpty) return fromLd;

    // Strategy 3: generic embedded JSON state blobs
    final fromScript = _parseEmbeddedJson(html, retailer);
    if (fromScript.isNotEmpty) return fromScript;

    // Strategy 4: text extraction — strip tags, find "Name KES price" patterns
    return _parseStrippedText(html, retailer);
  }

  /// Parses Next.js page JSON embedded as __NEXT_DATA__ in the head element.
  static List<ScrapedProduct> _parseNextData(
    String json,
    RetailerCode retailer,
  ) {
    final out = <ScrapedProduct>[];
    try {
      // Pattern: "name":"Some Product"  ... "salePrice":123.45
      // Also handles "price":"123.45" and "basePrice":123
      final re = RegExp(
        r'"name"\s*:\s*"([^"]{4,80})"(?:[^{}]*?)"(?:salePrice|price|basePrice)"\s*:\s*([\d.]+)',
      );
      for (final m in re.allMatches(json)) {
        final name =
            m.group(1)!.replaceAll(r'\u0026', '&').replaceAll(r'\/', '/').trim();
        final price = double.tryParse(m.group(2)!);
        if (price != null && price > 5 && price < 60000) {
          out.add(ScrapedProduct(retailer: retailer, rawText: name, price: price));
        }
      }
    } catch (e) {
      debugPrint('[PriceScraper] __NEXT_DATA__ parse error: $e');
    }
    return out;
  }

  /// Parses schema.org/Product JSON-LD blocks for name + price.
  static List<ScrapedProduct> _parseJsonLd(String html, RetailerCode retailer) {
    final out = <ScrapedProduct>[];
    final scriptRe = RegExp(
      r'<script[^>]+type="application/ld\+json"[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    );
    for (final sc in scriptRe.allMatches(html)) {
      final c = sc.group(1) ?? '';
      if (!c.contains('Product') && !c.contains('ItemList')) continue;
      final re = RegExp(
        r'"name"\s*:\s*"([^"]{4,80})"[^}]{0,500}"price"\s*:\s*"?([\d.]+)"?',
      );
      for (final m in re.allMatches(c)) {
        final price = double.tryParse(m.group(2)!);
        if (price != null && price > 5 && price < 60000) {
          out.add(ScrapedProduct(
            retailer: retailer,
            rawText: m.group(1)!.trim(),
            price: price,
          ));
        }
      }
    }
    return out;
  }

  /// Parses window.__STATE__ / initialState / similar embedded JSON blobs.
  static List<ScrapedProduct> _parseEmbeddedJson(
    String html,
    RetailerCode retailer,
  ) {
    final out = <ScrapedProduct>[];
    final stateRe = RegExp(
      r'(?:window\.__[A-Z_]{3,}__|initialState|productList|__STATE__)\s*='
      r'\s*(\{[\s\S]{20,100000}?\})\s*;',
    );
    for (final m in stateRe.allMatches(html)) {
      final blob = m.group(1) ?? '';
      final namePrice = RegExp(
        r'"(?:name|title|productName)"\s*:\s*"([^"]{4,80})"'
        r'[^}]{0,300}"(?:price|salePrice|currentPrice)"\s*:\s*([\d.]+)',
      );
      for (final nm in namePrice.allMatches(blob)) {
        final price = double.tryParse(nm.group(2)!);
        if (price != null && price > 5 && price < 60000) {
          out.add(ScrapedProduct(
            retailer: retailer,
            rawText: nm.group(1)!.trim(),
            price: price,
          ));
        }
      }
    }
    return out;
  }

  /// Last-resort parser: strip HTML tags, then look for "Name KES price" text.
  static List<ScrapedProduct> _parseStrippedText(
    String html,
    RetailerCode retailer,
  ) {
    final out = <ScrapedProduct>[];

    final clean = html
        .replaceAll(
            RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(
            RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Pattern A: "Product Name KES 1,234" — name before price
    final reA = RegExp(
      r'([A-Z][A-Za-z0-9 &+\-/.()]{4,60}?)\s+KES\s*([\d,]+(?:\.\d{0,2})?)',
    );
    for (final m in reA.allMatches(clean)) {
      final name = m.group(1)!.trim();
      final price = double.tryParse(m.group(2)!.replaceAll(',', ''));
      if (price != null && price > 5 && price < 60000 && name.length > 4) {
        out.add(ScrapedProduct(retailer: retailer, rawText: name, price: price));
      }
    }

    // Pattern B: "KES 1,234 Product Name" — price before name
    final reB = RegExp(
      r'KES\s*([\d,]+(?:\.\d{0,2})?)\s+([A-Z][A-Za-z0-9 &+\-/.()]{4,60})',
    );
    for (final m in reB.allMatches(clean)) {
      final price = double.tryParse(m.group(1)!.replaceAll(',', ''));
      final name = m.group(2)!.trim();
      if (price != null && price > 5 && price < 60000 && name.length > 4) {
        out.add(ScrapedProduct(retailer: retailer, rawText: name, price: price));
      }
    }

    return out;
  }

  // ─── Internal: cache ──────────────────────────────────────────────────────

  static Future<void> _saveCache(List<ScrapedProduct> products) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(products.map((p) => p.toJson()).toList()),
    );
    await prefs.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
  }
}
