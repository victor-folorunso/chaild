import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps local_auth with enable/disable preference stored in secure storage.
class BiometricService {
  BiometricService._();
  static final instance = BiometricService._();

  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();
  static const _key = 'chaild_biometric_enabled';

  /// Whether the device has biometric hardware and enrolled biometrics.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  /// Whether the user has opted in to biometric unlock.
  Future<bool> isEnabled() async {
    final val = await _storage.read(key: _key);
    return val == 'true';
  }

  /// Save the user's opt-in preference.
  Future<void> setEnabled(bool enabled) =>
      _storage.write(key: _key, value: enabled.toString());

  /// Prompt biometric authentication. Returns true on success.
  Future<bool> authenticate({String reason = 'Confirm your identity'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN as fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
