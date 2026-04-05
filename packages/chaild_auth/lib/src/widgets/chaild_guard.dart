import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return widget.child;
  }
}
