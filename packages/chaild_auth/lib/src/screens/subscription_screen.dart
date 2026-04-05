import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chaild_auth_config.dart';
import '../config/chaild_constants.dart';
import '../config/chaild_theme.dart';
import '../controllers/auth_controller.dart';
import '../services/payment_service.dart';
import '../services/subscription_service.dart';
import '../widgets/chaild_button.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSubscribed;

  const SubscriptionScreen({super.key, this.onSubscribed});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String _selectedPlan = ChailConstants.planMonthly;
  bool _isLoading = false;
  String? _pendingTxRef;
  Timer? _pollTimer;

  static const _prices = {
    ChailConstants.planMonthly: 2500,
    ChailConstants.planYearly: 24000,
  };

  static const _features = [
    'Full access to all features',
    'Sync across unlimited devices',
    'Priority customer support',
    'New features as they ship',
  ];

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _subscribe() async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: ChailColors.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _startPolling(String txRef) {
    // Poll every 5 seconds for up to 5 minutes
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

  @override
  Widget build(BuildContext context) {
    final appName = ChailAuth.appName ?? 'Pro';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header gradient ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ChailColors.primaryDark, ChailColors.primary],
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
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(ChailConstants.paddingL),
                child: Column(
                  children: [
                    // ── Features ─────────────────────────────────────────
                    ..._features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: ChailColors.primary.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  size: 14, color: ChailColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Text(f,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Plan Toggle ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Row(
                        children: [
                          _PlanTab(
                            label: 'Monthly',
                            price: '₦${_prices[ChailConstants.planMonthly]}',
                            isSelected:
                                _selectedPlan == ChailConstants.planMonthly,
                            onTap: () => setState(
                                () => _selectedPlan = ChailConstants.planMonthly),
                          ),
                          _PlanTab(
                            label: 'Yearly',
                            price: '₦${_prices[ChailConstants.planYearly]}',
                            badge: 'Save 20%',
                            isSelected:
                                _selectedPlan == ChailConstants.planYearly,
                            onTap: () => setState(
                                () => _selectedPlan = ChailConstants.planYearly),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── CTA ──────────────────────────────────────────────
                    if (_pendingTxRef != null && _isLoading)
                      Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Waiting for payment confirmation...',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () async {
                              final verified = await PaymentService.instance
                                  .verifyPayment(_pendingTxRef!);
                              if (verified && mounted) {
                                await SubscriptionService.instance
                                    .refreshAfterPayment();
                                widget.onSubscribed?.call();
                              }
                            },
                            child: const Text("I've paid — check again"),
                          ),
                        ],
                      )
                    else
                      ChailButton(
                        label: _isLoading
                            ? 'Opening payment...'
                            : 'Subscribe — ₦${_prices[_selectedPlan]}/${_selectedPlan == ChailConstants.planYearly ? "yr" : "mo"}',
                        isLoading: _isLoading,
                        onPressed: _subscribe,
                      ),

                    const SizedBox(height: 16),
                    Text(
                      'Secure payment via Flutterwave. Cancel anytime.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          duration: ChailConstants.animFast,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? ChailColors.primary : Colors.transparent,
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
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
                        : ChailColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : ChailColors.primary,
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
