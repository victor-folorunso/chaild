import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_env.dart';
import 'services/usage_tracking_service.dart';

/// ChailAuth — the SDK entry point.
///
/// ─────────────────────────────────────────────────────────────────────────
/// DEVELOPER USAGE (anyone integrating chaild_auth into their app):
///
/// ```dart
/// await ChailAuth.initialize(
///   partnerKey: 'your_partner_key',     // from chaild.app developer portal
///   revenueCatApiKey: 'appl_xxxxx',     // your RC public key for this platform
///   appName: 'My App',
/// );
/// ```
///
/// That's all developers need. Supabase, Flutterwave, and pricing are
/// managed entirely by Chaild infrastructure.
///
/// ─────────────────────────────────────────────────────────────────────────
/// YOUR OWN APPS (Contact Sync, etc.) use:
///
/// ```dart
/// await ChailAuth.initialize(
///   partnerKey: ChailAppEnv.internalPartnerKey,
///   revenueCatApiKey: 'appl_xxxxx',
///   appName: 'Contact Sync',
/// );
/// ```
/// ─────────────────────────────────────────────────────────────────────────
class ChailAuth {
  ChailAuth._();

  static String? _partnerKey;
  static String? _appName;
  static Color? _accentColor;
  static bool _initialized = false;
  static Duration? _appLockTimeout;
  static bool _requiresIdVerification = false;
  static String? _bundleId;

  static String? get partnerKey => _partnerKey;
  static String? get appName => _appName;
  static Color? get accentColor => _accentColor;
  static bool get isInitialized => _initialized;
  static Duration? get appLockTimeout => _appLockTimeout;
  static bool get requiresIdVerification => _requiresIdVerification;
  static String? get bundleId => _bundleId;

  /// Initialize ChailAuth. Call once in main() before runApp().
  ///
  /// [partnerKey] — your unique key from the Chaild developer portal.
  ///   Every user who signs up through your app is attributed to you
  ///   for revenue sharing. Get yours at chaild.app/developers.
  ///
  /// [revenueCatApiKey] — your RevenueCat public API key.
  ///   RevenueCat dashboard → Projects → your project → API Keys.
  ///   Use the iOS key for iOS builds, Android key for Android builds.
  ///   Typically handled with dart-define or flutter_config per platform.
  ///
  /// [appName] — displayed in the auth UI and payment screens.
  ///
  /// [accentColor] — optional brand color override (default: Chaild purple).
  static Future<void> initialize({
    required String partnerKey,
    required String revenueCatApiKey,
    String appName = 'App',
    Color? accentColor,
    Duration? appLockTimeout,
    bool requiresIdVerification = false,
  }) async {
    // Supabase — uses Chaild's own credentials baked into the SDK
    await Supabase.initialize(
      url: ChailAppEnv.supabaseUrl,
      anonKey: ChailAppEnv.supabaseAnonKey,
    );

    // RevenueCat — uses the developer's own RC key for their platform
    await Purchases.configure(
      PurchasesConfiguration(revenueCatApiKey),
    );

    // Read bundle ID from the host app at runtime
    final packageInfo = await PackageInfo.fromPlatform();

    _partnerKey = partnerKey;
    _appName = appName;
    _accentColor = accentColor;
    _appLockTimeout = appLockTimeout;
    _requiresIdVerification = requiresIdVerification;
    _bundleId = packageInfo.packageName;
    _initialized = true;

    // Start usage tracking — sends heartbeats to record-usage on background
    UsageTrackingService.instance.attach();
  }

  static SupabaseClient get client {
    assert(_initialized, 'Call ChailAuth.initialize() first.');
    return Supabase.instance.client;
  }

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isSignedIn => currentUser != null;
}
