import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/retailer_quote.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT PREFERENCE STORE
// Persists the user's explicit product selections so that basket compare
// remembers which exact catalog product maps to a generic item name at
// each retailer, surviving app restarts.
//
// Key format: "<genericName_lowercase>|<retailerCode.name>"
// Value:      productId (e.g. "naivas_geisha_bar_soap_175g")
// ─────────────────────────────────────────────────────────────────────────────

class ProductPreferenceStore {
  static const String _prefKey = 'hf_product_prefs_v1';

  static String _mapKey(String genericName, RetailerCode code) =>
      '${genericName.toLowerCase().trim()}|${code.name}';

  static Future<Map<String, String>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  /// Saves [productId] as the preferred product for [genericName] at [code].
  static Future<void> save(
    String genericName,
    RetailerCode code,
    String productId,
  ) async {
    final map = await _load();
    map[_mapKey(genericName, code)] = productId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(map));
  }

  /// Returns the saved product ID for [genericName] at [code], or null.
  static Future<String?> get(String genericName, RetailerCode code) async {
    final map = await _load();
    return map[_mapKey(genericName, code)];
  }

  /// Clears all saved preferences (useful for testing / reset).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
