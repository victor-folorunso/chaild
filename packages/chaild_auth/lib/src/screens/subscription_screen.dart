import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../chaild_auth_config.dart';
import '../config/chaild_constants.dart';
import '../config/chaild_theme.dart';
import '../controllers/auth_controller.dart';
import '../services/payment_service.dart';
import '../services/subscription_service.dart';
import '../widgets/chaild_button.dart';

// ─── Platform / storefront detection ────────────────────────────────────────

enum _PaymentMode {
  /// iOS non-US: App Store IAP only.
  iapOnly,

  /// iOS US: App Store IAP primary, Flutterwave secondary.
  iapPrimary,

  /// Android all: Flutterwave primary, Google Play Billing secondary.
  flutterwavePrimary,
}

Future<_PaymentMode> _detectPaymentMode() async {
  if (Platform.isIOS) {
    try {
      final storefront = await Purchases.currentStorefront;
      if (storefront?.countryCode == 'USA') {
        return _PaymentMode.iapPrimary;
      }
    } catch (_) {
      // If storefront detection fails, default to safest IAP-only.
    }
    return _PaymentMode.iapOnly;
  }
  // Android (and any other platform)
  return _PaymentMode.flutterwavePrimary;
}

// ─── Widget ─────────────────────────────────────────────────────────────────

class SubscriptionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSubscribed;

  const SubscriptionScreen({super.key, this.onSubscribed});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _selectedPlan = ChaildConstants.planMonthly;
  bool _isLoading = false;
  String? _pendingTxRef;
  Timer? _pollTimer;
  _PaymentMode? _paymentMode;
  Offering? _offering;

  // Flutterwave prices (fallback / Android primary)
  static const _fwPrices = {
    ChaildConstants.planMonthly: 2500,
    ChaildConstants.planYearly: 24000,
  };

  static const _features = [
    'Full access to all features',
    'Sync across unlimited devices',
    'Priority customer support',
    'New features as they ship',
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      final mode = await _detectPaymentMode();
      Offering? offering;
      if (mode != _PaymentMode.flutterwavePrimary) {
        // Pre-load RevenueCat offering for IAP flows.
        try {
          final offerings = await Purchases.getOfferings();
          offering = offerings.current;
        } catch (_) {
          // Offering unavailable — IAP UI will show an error state.
        }
      }
      if (mounted) {
        setState(() {
          _paymentMode = mode;
          _offering = offering;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── IAP via RevenueCat ───────────────────────────────────────────────────

  Package? get _selectedPackage {
    if (_offering == null) return null;
    return _selectedPlan == ChaildConstants.planYearly
        ? _offering!.annual
        : _offering!.monthly;
  }

  Future<void> _purchaseIAP() async {
    final pkg = _selectedPackage;
    if (pkg == null) {
      _showError('Store product not available. Please try again later.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Purchases.purchasePackage(pkg);
      await SubscriptionService.instance.refreshAfterPayment();
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onSubscribed?.call();
      }
    } on PurchasesError catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) {
        // User backed out — silent.
      } else {
        _showError('Purchase failed: ${e.message}');
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _showError('An unexpected error occurred.');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Flutterwave ──────────────────────────────────────────────────────────

  Future<void> _subscribeFlutterwave() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    setState(() => _isLoading = true);
    try {
      final txRef = await PaymentService.instance.initiatePayment(
        plan: _selectedPlan,
        userEmail: user.email,
        userName: user.name,
      );
      setState(() => _pendingTxRef = txRef);
      _startPolling(txRef);
    } catch (e) {
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _startPolling(String txRef) {
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      attempts++;
      if (attempts > 60) {
        timer.cancel();
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final verified = await PaymentService.instance.verifyPayment(txRef);
      if (verified) {
        timer.cancel();
        await SubscriptionService.instance.refreshAfterPayment();
        if (mounted) {
          setState(() => _isLoading = false);
          widget.onSubscribed?.call();
        }
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: ChaildColors.error),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appName = ChaildAuth.appName ?? 'Pro';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header gradient ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ChaildColors.primaryDark, ChaildColors.primary],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unlock $appName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Everything you need, one simple subscription.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(ChaildConstants.paddingL),
                child: _isLoading && _paymentMode == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _buildBody(appName),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String appName) {
    return Column(
      children: [
        // ── Features ───────────────────────────────────────────────────
        ..._features.map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: ChaildColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      size: 14, color: ChaildColors.primary),
                ),
                const SizedBox(width: 12),
                Text(f, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Plan Toggle ────────────────────────────────────────────────
        _buildPlanToggle(),

        const SizedBox(height: 24),

        // ── Payment buttons ────────────────────────────────────────────
        _buildPaymentButtons(),

        const SizedBox(height: 12),
        _buildFooterNote(),
      ],
    );
  }

  Widget _buildPlanToggle() {
    // For IAP modes, show prices from the RevenueCat offering when available.
    String monthlyLabel = '₦${_fwPrices[ChaildConstants.planMonthly]}';
    String yearlyLabel  = '₦${_fwPrices[ChaildConstants.planYearly]}';
    if (_offering != null) {
      final mp = _offering!.monthly?.storeProduct.priceString;
      final yp = _offering!.annual?.storeProduct.priceString;
      if (mp != null) monthlyLabel = mp;
      if (yp != null) yearlyLabel  = yp;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          _PlanTab(
            label: 'Monthly',
            price: monthlyLabel,
            isSelected: _selectedPlan == ChaildConstants.planMonthly,
            onTap: () =>
                setState(() => _selectedPlan = ChaildConstants.planMonthly),
          ),
          _PlanTab(
            label: 'Yearly',
            price: yearlyLabel,
            badge: 'Save 20%',
            isSelected: _selectedPlan == ChaildConstants.planYearly,
            onTap: () =>
                setState(() => _selectedPlan = ChaildConstants.planYearly),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButtons() {
    // Show polling state if awaiting Flutterwave confirmation.
    if (_pendingTxRef != null && _isLoading) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Waiting for payment confirmation...',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              final verified =
                  await PaymentService.instance.verifyPayment(_pendingTxRef!);
              if (verified && mounted) {
                await SubscriptionService.instance.refreshAfterPayment();
                widget.onSubscribed?.call();
              }
            },
            child: const Text("I've paid — check again"),
          ),
        ],
      );
    }

    final mode = _paymentMode ?? _PaymentMode.iapOnly;

    switch (mode) {
      // ── Android: Flutterwave primary, Google Play Billing secondary ──
      case _PaymentMode.flutterwavePrimary:
        return Column(
          children: [
            ChaildButton(
              label: _isLoading
                  ? 'Opening payment...'
                  : 'Pay with Flutterwave — ₦${_fwPrices[_selectedPlan]}/'
                      '${_selectedPlan == ChaildConstants.planYearly ? "yr" : "mo"}',
              isLoading: _isLoading,
              onPressed: _subscribeFlutterwave,
            ),
            const SizedBox(height: 12),
            ChaildButton(
              label: 'Google Play Billing',
              isLoading: _isLoading,
              variant: ChaildButtonVariant.secondary,
              onPressed: _purchaseIAP,
            ),
          ],
        );

      // ── iOS US: App Store primary, Flutterwave secondary ────────────
      case _PaymentMode.iapPrimary:
        return Column(
          children: [
            ChaildButton(
              label: _isLoading ? 'Opening App Store...' : 'Subscribe with App Store',
              isLoading: _isLoading,
              onPressed: _purchaseIAP,
            ),
            const SizedBox(height: 12),
            ChaildButton(
              label: 'Pay with Flutterwave / Apple Pay',
              isLoading: _isLoading,
              variant: ChaildButtonVariant.secondary,
              onPressed: _subscribeFlutterwave,
            ),
          ],
        );

      // ── iOS non-US: App Store only ───────────────────────────────────
      case _PaymentMode.iapOnly:
        return ChaildButton(
          label: _isLoading ? 'Opening App Store...' : 'Subscribe with App Store',
          isLoading: _isLoading,
          onPressed: _purchaseIAP,
        );
    }
  }

  Widget _buildFooterNote() {
    final mode = _paymentMode;
    String note;
    if (mode == _PaymentMode.flutterwavePrimary) {
      note = 'Secure payment via Flutterwave or Google Play. Cancel anytime.';
    } else if (mode == _PaymentMode.iapPrimary) {
      note = 'Billed through App Store or Flutterwave. Cancel anytime.';
    } else {
      note = 'Billed through the App Store. Cancel anytime in Settings.';
    }
    return Text(
      note,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
      textAlign: TextAlign.center,
    );
  }
}

// ─── _PlanTab ────────────────────────────────────────────────────────────────

class _PlanTab extends StatelessWidget {
  final String label;
  final String price;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanTab({
    required this.label,
    required this.price,
    this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ChaildConstants.animFast,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? ChaildColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white.withOpacity(0.85)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : ChaildColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : ChaildColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
