import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class SupabaseService {
  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      debugPrint('Supabase is not configured yet. Skipping initialization.');
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } on AssertionError {
      // Prevent duplicate initialization during hot restart/dev cycles.
    } catch (error) {
      debugPrint('Supabase initialization failed: $error');
      rethrow;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;
}
