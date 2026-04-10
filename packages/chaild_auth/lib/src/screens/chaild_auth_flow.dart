import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/chaild_theme.dart';
import '../controllers/auth_controller.dart';
import '../models/chaild_user.dart';
import '../services/two_factor_service.dart';
import 'login_screen.dart';
import 'two_factor_screen.dart';

/// The root widget to drop into any app.
/// Wraps everything in a ProviderScope + ChailTheme.
///
/// ```dart
/// ChailAuthFlow(
///   onAuthenticated: (user) => navigateToMyApp(user),
/// )
/// ```
class ChailAuthFlow extends StatelessWidget {
  final void Function(ChailUser user) onAuthenticated;
  final bool darkMode;

  const ChailAuthFlow({
    super.key,
    required this.onAuthenticated,
    this.darkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ChailTheme.light(),
        darkTheme: ChailTheme.dark(),
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        home: _AuthFlowRoot(onAuthenticated: onAuthenticated),
      ),
    );
  }
}

/// Internal root — listens to auth state and routes accordingly.
class _AuthFlowRoot extends ConsumerStatefulWidget {
  final void Function(ChailUser user) onAuthenticated;

  const _AuthFlowRoot({required this.onAuthenticated});

  @override
  ConsumerState<_AuthFlowRoot> createState() => _AuthFlowRootState();
}

class _AuthFlowRootState extends ConsumerState<_AuthFlowRoot> {
  @override
  void initState() {
    super.initState();
    // Handle session already active on widget mount (e.g. app resumed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(authControllerProvider);
      if (state.user != null && !state.requiresTwoFactor) {
        widget.onAuthenticated(state.user!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fire onAuthenticated whenever user transitions from null → non-null
    // (covers normal sign-in AND 2FA completion).
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (prev?.user == null && next.user != null && !next.requiresTwoFactor) {
        widget.onAuthenticated(next.user!);
      }
    });

    final authState = ref.watch(authControllerProvider);

    // 2FA challenge pending — show code entry before completing sign-in
    if (authState.requiresTwoFactor) {
      return TwoFactorChallengeScreen(
        factorId: authState.pendingTwoFactorId!,
        onSuccess: () =>
            ref.read(authControllerProvider.notifier).completeTwoFactor(),
      );
    }

    return LoginScreen(onAuthenticated: widget.onAuthenticated);
  }
}
