import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chaild_user.dart';
import '../models/chaild_subscription.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoading;
  final ChailUser? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
  });

  bool get isSignedIn => user != null;

  AuthState copyWith({bool? isLoading, ChailUser? user, String? error}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        user: user ?? this.user,
        error: error,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(const AuthState()) {
    _init();
  }

  void _init() {
    AuthService.instance.authStateChanges.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn && event.session != null) {
        await _loadUser(event.session!.user.id);
      } else if (event.event == AuthChangeEvent.signedOut) {
        state = const AuthState();
      }
    });
  }

  Future<void> _loadUser(String userId) async {
    final user = await AuthService.instance.getProfile(userId);
    state = state.copyWith(user: user, isLoading: false);
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await AuthService.instance.signUpWithEmail(
          email: email, password: password, name: name);
      // Auth state listener handles the rest
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await AuthService.instance
          .signInWithEmail(email: email, password: password);
      if (res.user != null) await _loadUser(res.user!.id);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await AuthService.instance.signInWithApple();
      if (res.user != null) await _loadUser(res.user!.id);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await AuthService.instance.signInWithGoogle();
      if (res.user != null) await _loadUser(res.user!.id);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await AuthService.instance.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendly(e));
    }
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(error: null);

  String _friendly(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login')) return 'Incorrect email or password.';
    if (msg.contains('already registered')) return 'This email is already in use.';
    if (msg.contains('network')) return 'Check your internet connection.';
    if (msg.contains('cancelled')) return '';
    return 'Something went wrong. Please try again.';
  }
}

// ── Subscription State ────────────────────────────────────────────────────────

class SubscriptionState {
  final bool isLoading;
  final ChailSubscription? subscription;
  final String? error;

  const SubscriptionState({
    this.isLoading = false,
    this.subscription,
    this.error,
  });

  bool get isActive => subscription?.isActive ?? false;

  SubscriptionState copyWith({
    bool? isLoading,
    ChailSubscription? subscription,
    String? error,
  }) =>
      SubscriptionState(
        isLoading: isLoading ?? this.isLoading,
        subscription: subscription ?? this.subscription,
        error: error,
      );
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController() : super(const SubscriptionState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sub = await SubscriptionService.instance.getSubscription();
      state = state.copyWith(isLoading: false, subscription: sub);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (_) => AuthController(),
);

final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>(
  (_) => SubscriptionController(),
);
