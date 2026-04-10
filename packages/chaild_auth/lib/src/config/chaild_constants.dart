import 'package:flutter/material.dart';

/// All hardcoded values live here.
/// Reference this instead of magic strings/numbers anywhere in the package.
class ChaildConstants {
  ChaildConstants._();

  // ── RevenueCat ──────────────────────────────────────────────────────────
  static const String rcEntitlement = 'pro';

  // ── Subscription Plans ──────────────────────────────────────────────────
  static const String planMonthly = 'monthly';
  static const String planYearly = 'yearly';

  // ── Flutterwave ─────────────────────────────────────────────────────────
  /// Format: chaild_{userId}_{timestamp}
  static String flutterwaveTxRef(String userId) =>
      'chaild_${userId}_${DateTime.now().millisecondsSinceEpoch}';

  // ── Supabase Table Names ─────────────────────────────────────────────────
  static const String tableProfiles = 'profiles';
  static const String tableSubscriptions = 'subscriptions';
  static const String tablePartners = 'partners';
  static const String tableReferrals = 'referrals';
  static const String tablePartnerEarnings = 'partner_earnings';
  static const String tablePayouts = 'payouts';

  // ── Supabase Edge Functions ──────────────────────────────────────────────
  static const String fnVerifySubscription = 'verify-subscription';
  static const String fnFlutterwaveWebhook = 'flutterwave-webhook';

  // ── Animation Durations ─────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);

  // ── Layout ───────────────────────────────────────────────────────────────
  static const double paddingXS = 8.0;
  static const double paddingS = 12.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  static const double paddingXXL = 48.0;

  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 100.0;

  static const double buttonHeight = 52.0;
  static const double inputHeight = 52.0;
}
