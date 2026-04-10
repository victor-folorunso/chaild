/// Chaild Auth — drop-in auth, subscriptions & affiliate SDK for Flutter.
///
/// ## Quick start
/// ```dart
/// // 1. Initialize once in main()
/// await ChaildAuth.initialize(
///   supabaseUrl: '...',
///   supabaseAnonKey: '...',
///   revenueCatApiKey: '...',
///   flutterwavePublicKey: '...',
///   partnerKey: 'your_partner_key', // from chaild developer portal
///   appName: 'My App',
/// );
///
/// // 2a. Protect an entire screen
/// ChaildGuard(child: MyScreen())
///
/// // 2b. Or handle the flow yourself
/// ChaildAuthFlow(onAuthenticated: (user) { ... })
/// ```
library chaild_auth;

// ── Config ────────────────────────────────────────────────────────────────────
export 'src/chaild_auth_config.dart';
export 'src/config/chaild_theme.dart';
export 'src/config/chaild_constants.dart';
export 'src/config/app_env.dart';

// ── Models ────────────────────────────────────────────────────────────────────
export 'src/models/chaild_user.dart';
export 'src/models/chaild_subscription.dart';

// ── Controllers (Riverpod providers) ──────────────────────────────────────────
export 'src/controllers/auth_controller.dart';

// ── Services (advanced / direct access) ──────────────────────────────────────
export 'src/services/auth_service.dart';
export 'src/services/subscription_service.dart';
export 'src/services/payment_service.dart';
export 'src/services/biometric_service.dart';
export 'src/services/two_factor_service.dart';
export 'src/services/usage_tracking_service.dart';

// ── Screens (use directly for custom flows) ───────────────────────────────────
export 'src/screens/chaild_auth_flow.dart';
export 'src/screens/login_screen.dart';
export 'src/screens/signup_screen.dart';
export 'src/screens/forgot_password_screen.dart';
export 'src/screens/subscription_screen.dart';
export 'src/screens/account_screen.dart';
export 'src/screens/two_factor_screen.dart';

// ── Widgets ───────────────────────────────────────────────────────────────────
export 'src/widgets/chaild_button.dart';
export 'src/widgets/chaild_text_field.dart';
export 'src/widgets/chaild_guard.dart';
export 'src/widgets/chaild_app_lock.dart';
