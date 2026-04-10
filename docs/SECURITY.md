# Security

Chaild provides optional security features that you can enable for your app.
All of them are opt-in. None of them require you to implement authentication
logic yourself.

---

## Biometric Authentication

Allow users to unlock your app with their fingerprint or face instead of
typing their password every time.

Enable it when initialising:

```dart
await ChaildAuth.initialize(
  partnerKey: 'dev_your_key',
  revenueCatApiKey: 'appl_your_key',
  appName: 'Your App',
  appLockTimeout: Duration(minutes: 5),
);
```

Setting `appLockTimeout` activates app locking. When the user returns to
your app after being away longer than the timeout, Chaild prompts biometric
authentication before showing any content.

The user can also toggle biometrics on or off themselves from the Chaild
account screen inside your app. You do not need to build a settings UI for this.

If the device does not support biometrics, the option is hidden automatically.
If biometrics fail or are unavailable in a session, Chaild falls back to
asking for the account password.

Required setup:

Android -- add to `AndroidManifest.xml` inside the `<manifest>` tag:
```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

iOS -- add to `Info.plist`:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to unlock the app quickly and securely.</string>
```

---

## Two-Factor Authentication (2FA)

2FA adds a second verification step using an authenticator app like Google
Authenticator or Authy. When a user enables 2FA on their Chaild account,
they must enter a code from their authenticator app every time they sign in.

You do not build any of this UI. It lives in the Chaild account screen.
The sign-in flow in Chaild handles the 2FA challenge step automatically.

There is nothing you need to configure to support 2FA. It is available to
all users by default.

---

## App Lock

App lock re-authenticates the user after a period of inactivity. Set the
timeout in `ChaildAuth.initialize()`:

```dart
appLockTimeout: Duration(minutes: 5)  // lock after 5 minutes in background
appLockTimeout: Duration(seconds: 30) // lock after 30 seconds
```

If you do not pass `appLockTimeout`, app lock is disabled.

When the lock triggers, a full-screen overlay covers your app content.
The overlay uses biometrics if enabled, falls back to password if not.
The user cannot see any of your app content until they authenticate.

This also means your app content is not visible in the system app switcher
when the lock is active.

---

## ID Verification

Some types of apps may require users to verify their identity before accessing
certain features. Chaild includes optional ID verification support.

To require ID verification for your app:

```dart
await ChaildAuth.initialize(
  partnerKey: 'dev_your_key',
  revenueCatApiKey: 'appl_your_key',
  appName: 'Your App',
  requiresIdVerification: true,
);
```

When this is set, users who have not completed ID verification will be shown
a verification screen before accessing your app content. Users who have already
verified their identity on any other Chaild app will not be asked again.

ID verification is completely optional. Most apps do not need it. Calculators,
note-taking apps, and utilities should not use it. It is intended for apps
that handle sensitive personal information or financial transactions.

