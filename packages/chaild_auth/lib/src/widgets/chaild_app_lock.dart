import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/biometric_service.dart';

/// Wraps app content and enforces biometric re-auth after idle timeout.
///
/// Place this around the root of your app (inside ProviderScope):
/// ```dart
/// ChaildAppLock(
///   timeout: Duration(minutes: 5),
///   child: MyApp(),
/// )
/// ```
///
/// If [timeout] is null or zero, the lock is disabled.
class ChaildAppLock extends StatefulWidget {
  final Widget child;
  final Duration? timeout;

  const ChaildAppLock({super.key, required this.child, this.timeout});

  @override
  State<ChaildAppLock> createState() => _ChaildAppLockState();
}

class _ChaildAppLockState extends State<ChaildAppLock>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final timeout = widget.timeout;
    if (timeout == null || timeout == Duration.zero) return;

    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg != null && DateTime.now().difference(bg) >= timeout) {
        _checkAndLock();
      }
      _backgroundedAt = null;
    }
  }

  Future<void> _checkAndLock() async {
    final enabled = await BiometricService.instance.isEnabled();
    final available = await BiometricService.instance.isAvailable();
    if (enabled && available && mounted) {
      setState(() => _locked = true);
      _promptUnlock();
    }
  }

  Future<void> _promptUnlock() async {
    if (_authenticating) return;
    _authenticating = true;
    final ok = await BiometricService.instance.authenticate(
      reason: 'Unlock the app to continue',
    );
    _authenticating = false;
    if (ok && mounted) {
      setState(() => _locked = false);
    } else if (mounted) {
      // Re-prompt if failed — user must unlock to proceed
      _promptUnlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockOverlay(onUnlock: _promptUnlock),
          ),
      ],
    );
  }
}

// ── Lock overlay (opaque — hides content in app switcher) ───────────────────

class _LockOverlay extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockOverlay({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.background,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'App Locked',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Authenticate to continue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
