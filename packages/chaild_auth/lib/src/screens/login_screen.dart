import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/chaild_constants.dart';
import '../config/chaild_theme.dart';
import '../controllers/auth_controller.dart';
import '../models/chaild_user.dart';
import '../widgets/chaild_button.dart';
import '../widgets/chaild_text_field.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final void Function(ChaildUser user) onAuthenticated;

  const LoginScreen({super.key, required this.onAuthenticated});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signInWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  Future<void> _signInApple() async {
    await ref.read(authControllerProvider.notifier).signInWithApple();
  }

  Future<void> _signInGoogle() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final appName = 'Sign in'; // could use ChaildAuth.appName

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

                // ── Logo / Brand ─────────────────────────────────────────
                _ChaildLogo(),
                const SizedBox(height: 32),

                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                ),
                const SizedBox(height: 32),

                // ── Error ────────────────────────────────────────────────
                if (auth.error != null && auth.error!.isNotEmpty)
                  _ErrorBanner(auth.error!),

                // ── Fields ───────────────────────────────────────────────
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
                  hint: '••••••••',
                  controller: _password,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _signIn,
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return null;
                  },
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen()),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Sign In Button ───────────────────────────────────────
                ChaildButton(
                  label: 'Sign In',
                  isLoading: auth.isLoading,
                  onPressed: _signIn,
                ),
                const SizedBox(height: 24),

                // ── Divider ──────────────────────────────────────────────
                const ChaildDividerOr(),
                const SizedBox(height: 24),

                // ── Social Buttons ───────────────────────────────────────
                if (Platform.isIOS) ...[
                  ChaildAppleButton(
                    isLoading: auth.isLoading,
                    onPressed: _signInApple,
                  ),
                  const SizedBox(height: 12),
                ],
                ChaildGoogleButton(
                  isLoading: auth.isLoading,
                  onPressed: _signInGoogle,
                ),
                const SizedBox(height: 32),

                // ── Sign Up Link ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SignupScreen(onAuthenticated: widget.onAuthenticated),
                        ),
                      ),
                      child: const Text('Sign up'),
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

// ── Shared small widgets ──────────────────────────────────────────────────────

class _ChaildLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ChaildColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text('C',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
          ),
        ),
        const SizedBox(width: 8),
        const Text('chaild',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ChaildColors.errorSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ChaildColors.error.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: ChaildColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: ChaildColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
