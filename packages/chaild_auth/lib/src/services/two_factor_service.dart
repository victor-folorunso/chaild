import 'package:supabase_flutter/supabase_flutter.dart';
import '../chaild_auth_config.dart';

/// Wraps Supabase's built-in TOTP 2FA API.
class TwoFactorService {
  TwoFactorService._();
  static final instance = TwoFactorService._();

  SupabaseClient get _client => ChaildAuth.client;

  /// Whether the current user has an active TOTP factor enrolled.
  Future<bool> isEnrolled() async {
    final res = await _client.auth.mfa.listFactors();
    return res.totp.any((f) => f.status == FactorStatus.verified);
  }

  /// Begin enrollment. Returns the TOTP URI (for QR code) and the factor id.
  Future<({String uri, String factorId})> enroll() async {
    final res = await _client.auth.mfa.enroll(
      issuer: 'Chaild',
      factorType: FactorType.totp,
    );
    return (uri: res.totp.qrCode, factorId: res.id);
  }

  /// Verify an enrollment with the first TOTP code the user enters.
  /// Call this after [enroll] to activate the factor.
  Future<void> verify({required String factorId, required String code}) async {
    final challengeRes =
        await _client.auth.mfa.challenge(factorId: factorId);
    await _client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challengeRes.id,
      code: code,
    );
  }

  /// Unenroll (remove) a factor by id. Pass the verified factor's id.
  Future<void> unenroll(String factorId) async {
    await _client.auth.mfa.unenroll(factorId: factorId);
  }

  /// Get the id of the first verified TOTP factor, or null if none.
  Future<String?> verifiedFactorId() async {
    final res = await _client.auth.mfa.listFactors();
    final factor = res.totp.where((f) => f.status == FactorStatus.verified).firstOrNull;
    return factor?.id;
  }

  /// Initiate a sign-in challenge and verify the code. Returns true on success.
  Future<bool> challenge({required String factorId, required String code}) async {
    try {
      final challengeRes =
          await _client.auth.mfa.challenge(factorId: factorId);
      await _client.auth.mfa.verify(
        factorId: factorId,
        challengeId: challengeRes.id,
        code: code,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
