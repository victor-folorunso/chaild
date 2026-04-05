import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ChailAuth — initialize once in main() before runApp().
class ChailAuth {
  ChailAuth._();

  static String? _partnerKey;
  static String? _appName;
  static Color? _accentColor;
  static bool _initialized = false;
  static String? _flutterwavePublicKey;
  static String? _supabaseUrl;

  static String? get partnerKey => _partnerKey;
  static String? get appName => _appName;
  static Color? get accentColor => _accentColor;
  static bool get isInitialized => _initialized;
  static String? get flutterwavePublicKey => _flutterwavePublicKey;
  static String? get supabaseUrl => _supabaseUrl;

  /// Initialize the SDK. Call this in main() before runApp().
  ///
  /// [supabaseUrl], [supabaseAnonKey] — from Supabase project settings.
  /// [revenueCatApiKey] — from RevenueCat dashboard (iOS or Android key).
  /// [flutterwavePublicKey] — Flutterwave public key for checkout.
  /// [partnerKey] — unique key from Chaild developer portal.
  ///   Every user who signs up through this app is attributed to this partner.
  /// [accentColor] — override the default purple brand color.
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String revenueCatApiKey,
    required String flutterwavePublicKey,
    required String partnerKey,
    String appName = 'App',
    Color? accentColor,
  }) async {
    // Supabase
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    // RevenueCat
    await Purchases.configure(
      PurchasesConfiguration(revenueCatApiKey),
    );

    _supabaseUrl = supabaseUrl;
    _partnerKey = partnerKey;
    _appName = appName;
    _accentColor = accentColor;
    _flutterwavePublicKey = flutterwavePublicKey;
    _initialized = true;
  }

  static SupabaseClient get client {
    assert(_initialized, 'Call ChailAuth.initialize() first.');
    return Supabase.instance.client;
  }

  static User? get currentUser => client.auth.currentUser;

  static Session? get currentSession => client.auth.currentSession;

  static bool get isSignedIn => currentUser != null;
}
