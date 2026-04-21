class SupabaseConfig {
  static const url = 'https://gmjttroimogdelumblgb.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtanR0cm9pbW9nZGVsdW1ibGdiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyODU3MjMsImV4cCI6MjA4OTg2MTcyM30.yYMgVqHniMvY0YNzbxsnkQ2PAXt7HbhWBL4KtikP1oE';

  static bool get isConfigured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      !url.contains('YOUR_SUPABASE_URL') &&
      !anonKey.contains('YOUR_SUPABASE_ANON_KEY');
}
