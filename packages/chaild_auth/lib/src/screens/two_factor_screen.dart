import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/chaild_theme.dart';
import '../config/chaild_constants.dart';
import '../services/two_factor_service.dart';
import '../widgets/chaild_button.dart';
import '../widgets/chaild_text_field.dart';

/// Full 2FA setup screen — shows QR code, accepts verification code.
/// Used both for initial enrollment and re-configuration.
class TwoFactorSetupScreen extends StatefulWidget {
  final VoidCallback? onDone;

  const TwoFactorSetupScreen({super.key, this.onDone});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  String? _uri;
  String? _factorId;
  final _codeCtrl = TextEditingController();
  bool _loading = true;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startEnroll();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startEnroll() async {
    try {
      final result = await TwoFactorService.instance.enroll();
      if (mounted) {
        setState(() {
          _uri = result.uri;
          _factorId = result.factorId;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your authenticator app.');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      await TwoFactorService.instance.verify(factorId: _factorId!, code: code);
      if (mounted) widget.onDone?.call();
    } catch (_) {
      if (mounted) {
        setState(() { _verifying = false; _error = 'Invalid code. Try again.'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Up Two-Factor Auth')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ChaildConstants.paddingL),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _uri == null
                  ? Center(child: Text(_error!, style: const TextStyle(color: ChaildColors.error)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan this QR code',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Open your authenticator app (Google Authenticator, Authy, etc.) and scan the code below.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: QrImageView(
                            data: _uri!,
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('Enter verification code',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ChaildTextField(
                          controller: _codeCtrl,
                          label: '6-digit code',
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: const TextStyle(color: ChaildColors.error, fontSize: 13)),
                        ],
                        const SizedBox(height: 24),
                        ChaildButton(
                          label: 'Verify and Enable',
                          isLoading: _verifying,
                          onPressed: _verify,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

// ── 2FA Challenge screen (shown during sign-in when 2FA is required) ─────────

class TwoFactorChallengeScreen extends StatefulWidget {
  final String factorId;
  final VoidCallback onSuccess;

  const TwoFactorChallengeScreen({
    super.key,
    required this.factorId,
    required this.onSuccess,
  });

  @override
  State<TwoFactorChallengeScreen> createState() => _TwoFactorChallengeScreenState();
}

class _TwoFactorChallengeScreenState extends State<TwoFactorChallengeScreen> {
  final _codeCtrl = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    final ok = await TwoFactorService.instance.challenge(
      factorId: widget.factorId,
      code: code,
    );
    if (ok) {
      widget.onSuccess();
    } else if (mounted) {
      setState(() { _verifying = false; _error = 'Invalid code. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ChaildConstants.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_rounded, size: 48, color: ChaildColors.primary),
              const SizedBox(height: 24),
              Text('Two-Factor Authentication',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Enter the code from your authenticator app.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              ChaildTextField(
                controller: _codeCtrl,
                label: '6-digit code',
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(color: ChaildColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              ChaildButton(
                label: 'Verify',
                isLoading: _verifying,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
