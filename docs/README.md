# Chaild SDK: Developer Documentation

Chaild is a drop-in Flutter SDK that handles authentication, subscriptions,
storage, and security for your app. You write a few lines of code. Your users
get a polished sign-in and subscription experience. You earn revenue for every
user who subscribes through your app.

---

## Requirements

- Flutter 3.27 or higher
- Dart 3.6 or higher
- A Chaild developer account at portal.chaild.app

Note: Chaild manages all payment infrastructure and RevenueCat centrally.
You do not need your own RevenueCat account.

---

## Quick Start

Add the SDK to your `pubspec.yaml`:

```yaml
dependencies:
  chaild_auth:
    git:
      url: https://github.com/yourorg/chaild
      path: packages/chaild_auth
  chaild_storage:
    git:
      url: https://github.com/yourorg/chaild
      path: packages/chaild_storage
```

Initialize in `main.dart`:

```dart
import 'package:chaild_auth/chaild_auth.dart';
import 'package:chaild_storage/chaild_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ChaildAuth.initialize(
    partnerKey: 'dev_your_key_here',
    appName: 'Your App Name',
  );

  await ChaildStorage.initialize(namespace: 'your_app_name');

  runApp(const MyApp());
}
```

Protect your app behind auth and subscription:

```dart
ChaildGuard(child: YourMainScreen())
```

That is everything required. The rest is optional customisation.

---

## Documentation Index

- [Authentication](AUTH.md): sign in, sign up, social login, password reset
- [Subscriptions](SUBSCRIPTIONS.md): payment flow, checking status
- [Storage](STORAGE.md): local key-value and collections
- [Security](SECURITY.md): biometrics, 2FA, app lock
- [Revenue and Referrals](REVENUE.md): how you earn, usage tracking, payouts
- [Building the App](BUILDING.md): platform config, build commands
- [Partner Agreement](PARTNER_AGREEMENT.md): terms for publishing under Chaild
- [Payment Compliance](COMPLIANCE.md): platform payment rules and decisions (internal)
