/// ─────────────────────────────────────────────────────────────────────────────
/// ChailAppEnv — Chaild's own credentials, baked into the SDK.
///
/// WHO MANAGES THESE: You (the Chaild platform owner).
/// WHO SEES THESE: They ship inside the compiled SDK package.
///
/// SAFE TO SHIP IN APP:
///   supabaseUrl      — public, not secret. Supabase RLS protects your data.
///   supabaseAnonKey  — public, not secret. Only allows what RLS permits.
///   flutterwavePublicKey — public, only initiates checkout UI.
///
/// SECRET (NEVER IN FLUTTER CODE — live in Supabase edge function secrets):
///   FLUTTERWAVE_SECRET_KEY    → used server-side for payouts
///   FLUTTERWAVE_SECRET_HASH   → used server-side to verify webhooks
///   REVENUECAT_API_KEY        → used server-side to grant entitlements
///   CRON_SECRET               → used server-side to secure payout trigger
///
/// HOW TO GET EACH KEY:
///   supabaseUrl + supabaseAnonKey:
///     → supabase.com → your project → Settings → API
///       "Project URL" and "anon public" key
///
///   flutterwavePublicKey:
///     → dashboard.flutterwave.com → Settings → API Keys
///       Use "Public Key" (starts with FLWPUBK_TEST or FLWPUBK-)
///
/// HOW TO PUSH SECRET KEYS TO SUPABASE:
///   supabase secrets set FLUTTERWAVE_SECRET_KEY=your_key
///   supabase secrets set FLUTTERWAVE_SECRET_HASH=your_hash
///   supabase secrets set REVENUECAT_API_KEY=your_key
///   supabase secrets set CRON_SECRET=any_strong_random_string
///   (SUPABASE_SERVICE_ROLE_KEY and SUPABASE_URL are auto-available in functions)
///
/// ─────────────────────────────────────────────────────────────────────────────
class ChailAppEnv {
  ChailAppEnv._();

  // ── Your Supabase project credentials ────────────────────────────────────
  // supabase.com → your project → Settings → API
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // ── Your Flutterwave public key ───────────────────────────────────────────
  // dashboard.flutterwave.com → Settings → API Keys → Public Key
  static const String flutterwavePublicKey = 'YOUR_FW_PUBLIC_KEY';

  // ── Subscription prices in NGN ────────────────────────────────────────────
  // Update these when you change pricing. Mirror in your Flutterwave dashboard.
  static const int priceMonthlyNgn = 2500;
  static const int priceYearlyNgn = 24000;

  // ── RevenueCat entitlement identifier ────────────────────────────────────
  // RevenueCat dashboard → Entitlements → create one called "pro"
  static const String rcEntitlement = 'pro';

  // ── Internal partner key used by your own apps ────────────────────────────
  // This is what Contact Sync and your own apps use as partnerKey.
  // Revenue share for this key is 0% (set in DB patch 001).
  static const String internalPartnerKey = 'chaild_internal';
}
