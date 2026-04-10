import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../chaild_auth_config.dart';
import '../config/chaild_constants.dart';
import '../models/chaild_user.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => ChailAuth.client;

  // ── Email / Password ─────────────────────────────────────────────────────

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
    if (response.user != null) {
      await _setPartnerKey(response.user!.id);
    }
    return response;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  // ── Apple Sign In ─────────────────────────────────────────────────────────

  Future<AuthResponse> signInWithApple() async {
    if (!Platform.isIOS && defaultTargetPlatform != TargetPlatform.macOS) {
      throw UnsupportedError('Apple Sign In is only supported on iOS and macOS.');
    }
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final idToken = credential.identityToken;
    if (idToken == null) throw Exception('Apple sign in failed: no identity token');

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );

    if (response.user != null) {
      await _setPartnerKey(response.user!.id);
      // Update name from Apple if available
      final name = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
      if (name.isNotEmpty) {
        await _client
            .from(ChailConstants.tableProfiles)
            .update({'name': name})
            .eq('id', response.user!.id);
      }
    }
    return response;
  }

  // ── Google Sign In ────────────────────────────────────────────────────────

  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) throw Exception('Google sign in failed: no ID token');

    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    if (response.user != null) {
      await _setPartnerKey(response.user!.id);
    }
    return response;
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() => _client.auth.signOut();

  // ── Profile ───────────────────────────────────────────────────────────────

  Future<ChailUser?> getProfile(String userId) async {
    final data = await _client
        .from(ChailConstants.tableProfiles)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return ChailUser.fromMap(data);
  }

  Future<void> updateProfile(String userId, {String? name, String? avatarUrl}) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (name != null) updates['name'] = name;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    await _client.from(ChailConstants.tableProfiles).update(updates).eq('id', userId);
  }

  Future<void> deleteAccount() async {
    final userId = ChailAuth.currentUser?.id;
    if (userId == null) return;
    // Supabase: deleting the auth user cascades to profiles via FK
    await _client.rpc('delete_user'); // requires a custom RPC function
    await signOut();
  }

  // ── Auth State Stream ─────────────────────────────────────────────────────

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Private ───────────────────────────────────────────────────────────────

  /// Stamps the partner key on a new user's profile.
  Future<void> _setPartnerKey(String userId) async {
    final partnerKey = ChailAuth.partnerKey;
    if (partnerKey == null) return;

    // Only set once — don't overwrite if already set
    final existing = await _client
        .from(ChailConstants.tableProfiles)
        .select('partner_key')
        .eq('id', userId)
        .maybeSingle();

    if (existing != null && existing['partner_key'] == null) {
      await _client
          .from(ChailConstants.tableProfiles)
          .update({'partner_key': partnerKey})
          .eq('id', userId);

      // Create referral record
      await _client.from(ChailConstants.tableReferrals).insert({
        'partner_key': partnerKey,
        'referred_user_id': userId,
      }).onConflict('referred_user_id').ignoreDuplicates();
    }
  }
}
