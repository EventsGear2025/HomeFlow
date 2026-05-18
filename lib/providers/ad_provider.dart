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
  List<AdOffer> _offers = [];
  bool _isLoading = false;
  String? _error;

  List<AdOffer> get offers => _offers;
  bool get isLoading => _isLoading;
  bool get isEmpty => _offers.isEmpty;

  Future<void> fetchOffers({String placement = 'home'}) async {
    if (!SupabaseConfig.isConfigured || !SupabaseService.isInitialized) return;

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
    } catch (e) {
      _error = e.toString();
      debugPrint('AdProvider.fetchOffers error: $_error');
      _offers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
