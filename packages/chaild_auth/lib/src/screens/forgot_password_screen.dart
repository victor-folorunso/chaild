import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/chaild_constants.dart';
import '../controllers/auth_controller.dart';
import '../widgets/chaild_button.dart';
import '../widgets/chaild_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .resetPassword(_email.text.trim());
    if (mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ChaildConstants.paddingL),
          child: _sent
              ? _SuccessView(_email.text)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text('Reset password',
                          style: Theme.of(context).textTheme.displayMedium),
                      const SizedBox(height: 8),
                      Text(
                        "We'll send a reset link to your email.",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                      const SizedBox(height: 32),
                      if (auth.error != null && auth.error!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF450A0A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFEF4444).withOpacity(0.4)),
                          ),
                          child: Text(auth.error!,
                              style:
                                  const TextStyle(color: Color(0xFFEF4444))),
                        ),
                      ChaildTextField(
                        label: 'Email',
                        hint: 'you@example.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _send,
                        prefixIcon: const Icon(Icons.mail_outline, size: 18),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ChaildButton(
                        label: 'Send Reset Link',
                        isLoading: auth.isLoading,
                        onPressed: _send,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  const _SuccessView(this.email);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_read_outlined,
              size: 64, color: Color(0xFF22C55E)),
          const SizedBox(height: 24),
          Text('Check your inbox',
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'We sent a reset link to $email',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ChaildButton(
            label: 'Back to Sign In',
            onPressed: () => Navigator.pop(context),
            variant: ChaildButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}
