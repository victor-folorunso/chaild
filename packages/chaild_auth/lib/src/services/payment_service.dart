import 'package:url_launcher/url_launcher.dart';
import '../chaild_auth_config.dart';
import '../config/app_env.dart';
import '../config/chaild_constants.dart';

/// Handles initiating Flutterwave payment via browser.
/// Flow:
///   1. App calls [initiatePayment] → stores tx_ref in Supabase
///   2. Opens browser to Flutterwave hosted checkout
///   3. User pays → Flutterwave fires webhook to our edge function
///   4. Edge function grants RC entitlement + updates Supabase
///   5. App polls [verifyPayment] to confirm and refresh
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  static const Map<String, int> _planAmounts = {
    ChaildConstants.planMonthly: ChaildAppEnv.priceMonthlyNgn,
    ChaildConstants.planYearly: ChaildAppEnv.priceYearlyNgn,
  };

  /// Initiates a Flutterwave payment by opening the browser.
  /// Returns the tx_ref so the app can poll for completion.
  Future<String> initiatePayment({
    required String plan,
    required String userEmail,
    String? userName,
  }) async {
    final userId = ChaildAuth.currentUser?.id;
    if (userId == null) throw Exception('User not signed in');

    final txRef = ChaildConstants.flutterwaveTxRef(userId);
    final amount = _planAmounts[plan] ?? _planAmounts[ChaildConstants.planMonthly]!;
    const publicKey = ChaildAppEnv.flutterwavePublicKey;

    // Store pending tx_ref in Supabase so webhook can find the user
    await ChaildAuth.client.from(ChaildConstants.tableSubscriptions).upsert({
      'user_id': userId,
      'status': 'none',
      'plan': plan,
      'amount_ngn': amount,
      'flutterwave_ref': txRef,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    // Build Flutterwave hosted checkout URL
    final params = {
      'public_key': publicKey,
      'tx_ref': txRef,
      'amount': amount.toString(),
      'currency': 'NGN',
      'payment_options': 'card,banktransfer,ussd',
      'redirect_url': 'chaild://payment-complete',
      'customer[email]': userEmail,
      if (userName != null) 'customer[name]': userName,
      'customizations[title]': ChaildAuth.appName ?? 'Chaild',
      'customizations[description]': '${_planLabel(plan)} subscription',
      'meta[plan]': plan,
      'meta[user_id]': userId,
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final url = Uri.parse('https://checkout.flutterwave.com/v3.html?$queryString');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open payment page');
    }

    return txRef;
  }

  /// Poll Supabase to check if the webhook has activated the subscription.
  Future<bool> verifyPayment(String txRef) async {
    final userId = ChaildAuth.currentUser?.id;
    if (userId == null) return false;

    final data = await ChaildAuth.client
        .from(ChaildConstants.tableSubscriptions)
        .select('status, expires_at')
        .eq('user_id', userId)
        .eq('flutterwave_ref', txRef)
        .maybeSingle();

    if (data == null) return false;
    final status = data['status'] as String?;
    final expiresAt = data['expires_at'] != null
        ? DateTime.tryParse(data['expires_at'])
        : null;

    return status == 'active' &&
        (expiresAt == null || expiresAt.isAfter(DateTime.now()));
  }

  String _planLabel(String plan) =>
      plan == ChaildConstants.planYearly ? 'Annual' : 'Monthly';
}
