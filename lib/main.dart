import 'package:flutter/material.dart';
import 'package:chaild_auth/chaild_auth.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TEST RUNNER for the chaild_auth package.
///
/// Replace the RC key below with your actual RevenueCat key.
/// Everything else (Supabase, Flutterwave) is baked into ChailAppEnv.
/// ─────────────────────────────────────────────────────────────────────────────

/// YOUR RevenueCat public key — get it from:
/// revenuecat.com → Projects → your project → API Keys
/// Use the iOS key when building for iOS, Android key for Android.
/// Typically you'd inject this via --dart-define per platform, but for
/// testing you can hardcode the key here temporarily.
const String _revenueCatApiKey = 'YOUR_REVENUECAT_PUBLIC_KEY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ChailAuth.initialize(
    partnerKey: ChailAppEnv.internalPartnerKey,
    revenueCatApiKey: _revenueCatApiKey,
    appName: 'Chaild',
  );

  runApp(const ChailTestApp());
}

class ChailTestApp extends StatelessWidget {
  const ChailTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chaild Auth Test',
      debugShowCheckedModeBanner: false,
      theme: ChailTheme.light(),
      darkTheme: ChailTheme.dark(),
      themeMode: ThemeMode.dark,
      home: ChailAuthFlow(
        onAuthenticated: (ChailUser user) {
          debugPrint('✅ Signed in: ${user.email}');
        },
      ),
    );
  }
}
