import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/chaild_constants.dart';
import '../config/chaild_theme.dart';
import '../controllers/auth_controller.dart';
import '../models/chaild_user.dart';
import '../widgets/chaild_button.dart';
import '../widgets/chaild_text_field.dart';
import 'login_screen.dart' show _ChaildLogo, _ErrorBanner;
import 'login_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final void Function(ChaildUser user) onAuthenticated;

  const SignupScreen({super.key, required this.onAuthenticated});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signUpWithEmail(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
        );
    final user = ref.read(authControllerProvider).user;
    if (user != null && mounted) widget.onAuthenticated(user);
  }

  Future<void> _signInApple() async {
    await ref.read(authControllerProvider.notifier).signInWithApple();
    final user = ref.read(authControllerProvider).user;
    if (user != null && mounted) widget.onAuthenticated(user);
  }

  Future<void> _signInGoogle() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    final user = ref.read(authControllerProvider).user;
    if (user != null && mounted) widget.onAuthenticated(user);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ChaildConstants.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                _ChaildLogo(),
                const SizedBox(height: 32),

                Text('Create account',
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 6),
                Text(
                  'Get started in seconds',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
                const SizedBox(height: 32),

                if (auth.error != null && auth.error!.isNotEmpty)
                  _ErrorBanner(auth.error!),

                // ── Social first (lower friction) ────────────────────────
                if (Platform.isIOS)
                  ChaildAppleButton(
                      isLoading: auth.isLoading, onPressed: _signInApple),
                if (Platform.isIOS) const SizedBox(height: 12),
                ChaildGoogleButton(
                    isLoading: auth.isLoading, onPressed: _signInGoogle),
                const SizedBox(height: 24),
                const ChaildDividerOr(),
                const SizedBox(height: 24),

                // ── Fields ───────────────────────────────────────────────
                ChaildTextField(
                  label: 'Full name',
                  hint: 'Your name',
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                ChaildTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.mail_outline, size: 18),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                ChaildTextField(
                  label: 'Password',
                  hint: 'Min. 8 characters',
                  controller: _password,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                ChaildTextField(
                  label: 'Confirm password',
                  hint: '••••••••',
                  controller: _confirm,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _signUp,
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  validator: (v) {
                    if (v != _password.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                ChaildButton(
                  label: 'Create Account',
                  isLoading: auth.isLoading,
                  onPressed: _signUp,
                ),
                const SizedBox(height: 24),

                // ── Terms ─────────────────────────────────────────────────
                Text(
                  'By signing up you agree to our Terms of Service and Privacy Policy.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?',
                        style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(
                              onAuthenticated: widget.onAuthenticated),
                        ),
                      ),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
