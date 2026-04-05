import 'package:flutter/material.dart';
import 'package:chaild_auth/chaild_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ChailAuth.initialize(
    supabaseUrl: 'YOUR_SUPABASE_URL',       // TODO: replace
    supabaseAnonKey: 'YOUR_SUPABASE_ANON_KEY', // TODO: replace
    partnerKey: 'chaild_internal',          // internal key for first-party apps
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
      home: ChailAuthFlow(
        onAuthenticated: (ChailUser user) {
          debugPrint('✅ Signed in: ${user.email}');
        },
      ),
    );
  }
}
