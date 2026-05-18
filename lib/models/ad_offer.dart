import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD OFFER MODEL
// Maps to public.ad_offers in Supabase.
// ─────────────────────────────────────────────────────────────────────────────

class AdOffer {
  final String id;
  final String advertiser;
  final Color accentColor;
  final String productName;
  final int oldPriceCents; // stored as KES × 100
  final int newPriceCents;
  final String currency;
  final String placement;
  final int displayOrder;
  /// Matches AppConstants.supplyCategories — used when adding to shopping cart.
  final String category;

  const AdOffer({
    required this.id,
    required this.advertiser,
    required this.accentColor,
    required this.productName,
    required this.oldPriceCents,
    required this.newPriceCents,
    required this.currency,
    required this.placement,
    required this.displayOrder,
    this.category = 'Other',
  });

  factory AdOffer.fromMap(Map<String, dynamic> map) {
    return AdOffer(
      id: map['id']?.toString() ?? '',
      advertiser: map['advertiser']?.toString() ?? '',
      accentColor: _hexToColor(map['accent_hex']?.toString() ?? '#1B8A4A'),
      productName: map['product_name']?.toString() ?? '',
      oldPriceCents: (map['old_price_cents'] as num?)?.toInt() ?? 0,
      newPriceCents: (map['new_price_cents'] as num?)?.toInt() ?? 0,
      currency: map['currency']?.toString() ?? 'KES',
      placement: map['placement']?.toString() ?? 'home',
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      category: map['category']?.toString() ?? 'Other',
    );
  }

  /// Human-readable price: KES 1,199 (cents ÷ 100, formatted with commas)
  String formatPrice(int cents) {
    final kes = (cents / 100).round();
    final formatted = kes
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m.group(1)},',
        );
    return '$currency $formatted';
  }

  String get formattedOldPrice => formatPrice(oldPriceCents);
  String get formattedNewPrice => formatPrice(newPriceCents);

  int get savingCents => oldPriceCents - newPriceCents;
  String get formattedSaving => formatPrice(savingCents);

  int get discountPercent =>
      ((savingCents / oldPriceCents) * 100).round();

  static Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse('FF$clean', radix: 16) ?? 0xFF1B8A4A;
    return Color(value);
  }
}
