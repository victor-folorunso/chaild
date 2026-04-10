import 'package:flutter/material.dart';
import 'package:chaild_auth/chaild_auth.dart';
import 'package:chaild_storage/chaild_storage.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TEST RUNNER for the chaild_auth package.
///
/// Replace the RC key below with your actual RevenueCat key.
/// Everything else (Supabase, Flutterwave) is baked into ChaildAppEnv.
/// ─────────────────────────────────────────────────────────────────────────────

/// RevenueCat public key injected at build time.
/// Build commands:
///   iOS:     flutter run --dart-define=RC_KEY=appl_xxx
///   Android: flutter run --dart-define=RC_KEY=goog_xxx
const String _revenueCatApiKey = String.fromEnvironment('RC_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ChaildAuth.initialize(
    partnerKey: ChaildAppEnv.internalPartnerKey,
    revenueCatApiKey: _revenueCatApiKey,
    appName: 'Chaild',
  );

  await ChaildStorage.initialize(namespace: 'chaild_test');

  runApp(const ChaildTestApp());
}

class ChaildTestApp extends StatelessWidget {
  const ChaildTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chaild Auth Test',
      debugShowCheckedModeBanner: false,
      theme: ChaildTheme.light(),
      darkTheme: ChaildTheme.dark(),
      themeMode: ThemeMode.dark,
      home: ChaildAuthFlow(
        onAuthenticated: (ChaildUser user) {
          debugPrint('✅ Signed in: ${user.email}');
        },
      ),
    );
  }
}
