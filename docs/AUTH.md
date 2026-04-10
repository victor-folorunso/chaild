# Authentication

Chaild handles all authentication for your users. You do not interact with
Supabase directly. Everything goes through the `ChaildAuth` SDK.

---

## How It Works

When a user opens your app for the first time, Chaild shows a sign-in screen.
The user creates a Chaild account or signs in with an existing one. Once
authenticated, your app unlocks. Chaild does not ask for authentication again
until the session expires or the user signs out.

The user's account is a Chaild account, not an account specific to your app.
This means if they install another app that also uses Chaild, they sign in with
the same account. They do not create a new account per app.

---

## The Simplest Integration

```dart
ChaildAuthFlow(
  onAuthenticated: (ChaildUser user) {
    // user is signed in, take them to your app
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => YourHomeScreen(),
    ));
  },
)
```

Or use `ChaildGuard` which handles the routing automatically:

```dart
ChaildGuard(child: YourHomeScreen())
```

`ChaildGuard` shows the auth flow if the user is not signed in, shows the
subscription screen if they are signed in but not subscribed, and shows
your content when both conditions are met.

---

## The ChaildUser Object

Once authenticated you receive a `ChaildUser`:

```dart
user.id          // unique user ID (UUID)
user.email       // email address
user.name        // display name, may be null
user.avatarUrl   // profile picture URL, may be null
user.createdAt   // when they joined Chaild
```

---

## Checking Auth State in Your App

Use the Riverpod provider anywhere in your widget tree:

```dart
final authState = ref.watch(authControllerProvider);

if (authState.isSignedIn) {
  final user = authState.user;
}
```

---

## Accessing the Current User Directly

```dart
final user = ChaildAuth.currentUser; // returns Supabase User or null
final isSignedIn = ChaildAuth.isSignedIn;
```

---

## Sign Out

```dart
await ref.read(authControllerProvider.notifier).signOut();
```

Or directly:

```dart
await AuthService.instance.signOut();
```

---

## Account Deletion

The account screen built into Chaild includes a delete account option.
You do not need to implement this yourself. Deleting the account removes all
Chaild data for that user and signs them out of your app automatically.

---

## Social Sign In

Chaild supports Google Sign In and Apple Sign In out of the box. They appear
automatically in the sign-in screen. Apple Sign In is shown only on iOS.
Google Sign In is shown on both platforms.

You do not need any code to enable these. They require native configuration
in your project. See [Building the App](BUILDING.md) for the setup steps.

---

## Customising the Accent Color

```dart
await ChaildAuth.initialize(
  partnerKey: 'dev_your_key',
  revenueCatApiKey: 'appl_your_key',
  appName: 'Your App',
  accentColor: Colors.teal, // optional, defaults to Chaild purple
);
```

