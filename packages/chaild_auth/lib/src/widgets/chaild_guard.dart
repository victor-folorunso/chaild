import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chaild_auth_config.dart';
import '../controllers/auth_controller.dart';
import '../screens/chaild_auth_flow.dart';
import '../screens/subscription_screen.dart';

/// Drop this anywhere in your widget tree to protect content.
///
/// ```dart
/// ChailGuard(child: MyProtectedScreen())
/// ```
///
/// - If user is not signed in → shows sign in/up flow
/// - If user is signed in but not subscribed → shows paywall
/// - If user is signed in and subscribed → shows [child]
///
/// [requireSubscription] defaults to true. Set to false to only
/// require authentication (no paywall).
class ChailGuard extends ConsumerStatefulWidget {
  final Widget child;
  final bool requireSubscription;
  final void Function(dynamic user)? onAuthenticated;

  const ChailGuard({
    super.key,
    required this.child,
    this.requireSubscription = true,
    this.onAuthenticated,
  });

  @override
  ConsumerState<ChailGuard> createState() => _ChailGuardState();
}

class _ChailGuardState extends ConsumerState<ChailGuard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final subState = ref.watch(subscriptionControllerProvider);

    // ── Not signed in → auth flow ──────────────────────────────────────────
    if (!authState.isSignedIn) {
      return ChailAuthFlow(
        onAuthenticated: (user) {
          widget.onAuthenticated?.call(user);
          ref.read(subscriptionControllerProvider.notifier).load();
        },
      );
    }

    // ── Signed in, checking subscription ──────────────────────────────────
    if (widget.requireSubscription) {
      if (subState.isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (!subState.isActive) {
        return SubscriptionScreen(
          onSubscribed: () {
            ref.read(subscriptionControllerProvider.notifier).refresh();
          },
        );
      }
    }

    // ── All good → show the actual app ────────────────────────────────────
    // ── ID verification scaffold check ────────────────────────────────────
    if (ChailAuth.requiresIdVerification) {
      // Placeholder: when a KYC provider is integrated, replace this screen
      // with the real verification flow. The flag + gating logic are in place.
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Identity Verification Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                    'This app requires identity verification. '
                    'This feature will be available soon.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
