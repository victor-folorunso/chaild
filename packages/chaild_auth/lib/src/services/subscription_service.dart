import 'package:purchases_flutter/purchases_flutter.dart';
import '../chaild_auth_config.dart';
import '../config/app_env.dart';
import '../models/chaild_subscription.dart';

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  /// Check subscription status.
  /// RevenueCat is the primary source; Supabase DB is the fallback.
  Future<ChailSubscription?> getSubscription() async {
    final userId = ChailAuth.currentUser?.id;
    if (userId == null) return null;

    try {
      // ── RevenueCat check ────────────────────────────────────────────────
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement =
          customerInfo.entitlements.active[ChailAppEnv.rcEntitlement];

      if (entitlement != null) {
        return ChailSubscription(
          id: entitlement.productIdentifier,
          userId: userId,
          status: SubscriptionStatus.active,
          plan: entitlement.periodType == PeriodType.annual
              ? ChailConstants.planYearly
              : ChailConstants.planMonthly,
          expiresAt: entitlement.expirationDate != null
              ? DateTime.tryParse(entitlement.expirationDate!)
              : null,
          source: 'revenuecat',
        );
      }

      // ── Supabase fallback ────────────────────────────────────────────────
      final data = await ChailAuth.client
          .from(ChailConstants.tableSubscriptions)
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .maybeSingle();

      if (data == null) return null;

      final sub = ChailSubscription.fromMap(data);
      if (!sub.isActive) return null;
      return sub;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isSubscribed() async {
    final sub = await getSubscription();
    return sub?.isActive ?? false;
  }

  /// Called after Flutterwave payment to refresh RevenueCat customer info.
  Future<void> refreshAfterPayment() async {
    await Purchases.invalidateCustomerInfoCache();
    await Purchases.getCustomerInfo();
  }

  /// Stream that fires on subscription change (auth events only — poll for RC).
  Stream<ChailSubscription?> get subscriptionStream async* {
    yield await getSubscription();
  }
}
