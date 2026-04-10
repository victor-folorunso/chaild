import 'package:flutter/material.dart';
import 'package:chaild_auth/chaild_auth.dart';
import 'package:chaild_storage/chaild_storage.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TEST RUNNER for the chaild_auth package.
///
/// Replace the RC key below with your actual RevenueCat key.
/// Everything else (Supabase, Flutterwave) is baked into ChailAppEnv.
/// ─────────────────────────────────────────────────────────────────────────────

/// RevenueCat public key injected at build time.
/// Build commands:
///   iOS:     flutter run --dart-define=RC_KEY=appl_xxx
///   Android: flutter run --dart-define=RC_KEY=goog_xxx
const String _revenueCatApiKey = String.fromEnvironment('RC_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ChailAuth.initialize(
    partnerKey: ChailAppEnv.internalPartnerKey,
    revenueCatApiKey: _revenueCatApiKey,
    appName: 'Chaild',
  );

  await ChaildStorage.initialize(namespace: 'chaild_test');

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
