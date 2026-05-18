/// ─────────────────────────────────────────────────────────────────────────────
/// M-PESA DARAJA CREDENTIALS
/// ─────────────────────────────────────────────────────────────────────────────
/// Paste your Daraja API credentials below.
/// Get them from: https://developer.safaricom.co.ke/MyApps
///
/// For SANDBOX testing use the sandbox app credentials.
/// For PRODUCTION switch [environment] to MpesaEnvironment.production
/// and use your live app credentials.
/// ─────────────────────────────────────────────────────────────────────────────

enum MpesaEnvironment { sandbox, production }

class MpesaConfig {
  // ── Paste your credentials here ──────────────────────────────────────────

  /// Consumer Key from your Daraja app
  static const String consumerKey = 'T1MzocA6nSaadcQeDAaqqIqhUt7NqQG02O6kotDPcGqPEzap';

  /// Consumer Secret from your Daraja app
  static const String consumerSecret = '1pF4lVHB9AGxv8EgmwFqiosP3FsEIR9Ew3M4kVoCGEJTiBuUARpWzsS3LUeS1AGy';

  /// Your Paybill / Till number (Business Short Code)
  static const String businessShortCode = '4139537';

  /// Lipa na M-Pesa Online Passkey (from Daraja portal → Go Live → Lipa na Mpesa)
  /// Sandbox passkey: bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919
  static const String passkey =
      'bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919';

  /// Callback URL — receives payment confirmation from Safaricom.
  /// For testing you can use a free service like https://webhook.site
  /// or a Supabase Edge Function URL.
  static const String callbackUrl = 'https://homeflowapp.innovapp.co.ke/mpesa/callback';

  /// The name shown on the M-Pesa prompt (max 12 chars)
  static const String accountReference = 'HomeFlow';

  /// Description shown in customer's M-Pesa transaction history
  static const String transactionDesc = 'Grocery order';

  // ── Environment ───────────────────────────────────────────────────────────

  static const MpesaEnvironment environment = MpesaEnvironment.sandbox;

  // ── Derived (do not edit) ─────────────────────────────────────────────────

  static String get baseUrl => environment == MpesaEnvironment.sandbox
      ? 'https://sandbox.safaricom.co.ke'
      : 'https://api.safaricom.co.ke';

  static String get tokenUrl => '$baseUrl/oauth/v1/generate?grant_type=client_credentials';

  static String get stkPushUrl => '$baseUrl/mpesa/stkpush/v1/processrequest';
}
