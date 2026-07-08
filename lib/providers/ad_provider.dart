import 'package:flutter/foundation.dart';
import '../models/ad_offer.dart';
import '../services/supabase_service.dart';
import '../services/supabase_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AD PROVIDER
// Fetches active ad offers from public.ad_offers for a given placement.
// Falls back to an empty list when Supabase is not yet configured.
// ─────────────────────────────────────────────────────────────────────────────

class AdProvider extends ChangeNotifier {
  static final List<AdOffer> _curatedHomeOffers = [
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000001',
      'advertiser': 'Naivas',
      'accent_hex': '#1B8A4A',
      'product_name': 'Naivas Fino UHT Milk 500ML',
      'old_price_cents': 5200,
      'new_price_cents': 4900,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 1,
      'category': 'Dairy & Eggs',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000002',
      'advertiser': 'Naivas',
      'accent_hex': '#1B8A4A',
      'product_name': 'Celine Petals Tissue 10 Pack',
      'old_price_cents': 44500,
      'new_price_cents': 22500,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 2,
      'category': 'Personal Care',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000003',
      'advertiser': 'Naivas',
      'accent_hex': '#1B8A4A',
      'product_name': 'Celine Serviettes 100 Sheets',
      'old_price_cents': 14000,
      'new_price_cents': 9900,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 3,
      'category': 'Kitchen Cleaning',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000004',
      'advertiser': 'Naivas',
      'accent_hex': '#1B8A4A',
      'product_name': 'Sunrice Basmati Rice 5Kg',
      'old_price_cents': 182500,
      'new_price_cents': 129900,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 4,
      'category': 'Dry Foods & Cereals',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000005',
      'advertiser': 'Naivas',
      'accent_hex': '#1B8A4A',
      'product_name': 'Rina Vegetable Oil 5L',
      'old_price_cents': 160000,
      'new_price_cents': 139900,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 5,
      'category': 'Cooking Essentials',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000006',
      'advertiser': 'Carrefour',
      'accent_hex': '#E2001A',
      'product_name': 'Fresh Chicken Drumsticks (per kg)',
      'old_price_cents': 87900,
      'new_price_cents': 64900,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 6,
      'category': 'Meat & Protein',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000007',
      'advertiser': 'Carrefour',
      'accent_hex': '#E2001A',
      'product_name': 'Softleaf Virgin Toilet Paper Unwrap x10',
      'old_price_cents': 55700,
      'new_price_cents': 38900,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 7,
      'category': 'Personal Care',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000008',
      'advertiser': 'Carrefour',
      'accent_hex': '#E2001A',
      'product_name': 'Velvex Toilet Rolls White x10',
      'old_price_cents': 57700,
      'new_price_cents': 40300,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 8,
      'category': 'Personal Care',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000009',
      'advertiser': 'Carrefour',
      'accent_hex': '#E2001A',
      'product_name': 'Clorox Lemon Liquid 750ML',
      'old_price_cents': 41500,
      'new_price_cents': 29000,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 9,
      'category': 'Laundry & Cleaning',
    }),
    AdOffer.fromMap({
      'id': 'ad000000-0000-0000-0000-000000000010',
      'advertiser': 'Carrefour',
      'accent_hex': '#E2001A',
      'product_name': 'Huggies Dry Comfort Diapers Jumbo',
      'old_price_cents': 208900,
      'new_price_cents': 146200,
      'currency': 'KES',
      'placement': 'home',
      'display_order': 10,
      'category': 'Baby & Kids',
    }),
  ];

  List<AdOffer> _offers = [];
  bool _isLoading = false;
  String? _error;

  List<AdOffer> get offers => _offers;
  bool get isLoading => _isLoading;
  bool get isEmpty => _offers.isEmpty;

  List<AdOffer> _defaultOffersForPlacement(String placement) =>
      placement == 'home' ? _curatedHomeOffers : const [];

  Future<void> fetchOffers({String placement = 'home'}) async {
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) {
      _offers = _defaultOffersForPlacement(placement);
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await SupabaseService.client
          .from('ad_offers')
          .select()
          .eq('placement', placement)
          .eq('is_active', true)
          .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}')
          .order('display_order');

      _offers = (rows as List)
          .whereType<Map>()
          .map((row) => AdOffer.fromMap(Map<String, dynamic>.from(row)))
          .toList();
      if (placement == 'home') {
        _offers = _curatedHomeOffers;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('AdProvider.fetchOffers error: $_error');
      _offers = _defaultOffersForPlacement(placement);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
