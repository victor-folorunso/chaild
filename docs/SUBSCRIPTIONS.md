# Subscriptions

Chaild manages subscriptions on behalf of your app. Users pay a single Chaild
subscription that unlocks every app using the Chaild SDK. You earn a share of
that subscription revenue for every user you bring in.

You do not set prices. You do not manage payment providers. You do not build
a paywall UI. Chaild handles all of it.

---

## How the Paywall Works

When `ChaildGuard` detects an authenticated but unsubscribed user, it
automatically shows the Chaild subscription screen. The user chooses a plan,
pays, and your content unlocks. You receive a callback.

If you want to trigger the subscription screen yourself:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => SubscriptionScreen(
    onSubscribed: () {
      // subscription confirmed, do what you need
    },
  ),
));
```

---

## Checking Subscription Status

```dart
final subscriptionState = ref.watch(subscriptionControllerProvider);

if (subscriptionState.isActive) {
  // user has an active subscription
}
```

Or imperatively:

```dart
final isSubscribed = await SubscriptionService.instance.isSubscribed();
```

---

## The ChaildSubscription Object

```dart
final sub = subscriptionState.subscription;

sub.status      // active, expired, cancelled, grace_period, none
sub.plan        // 'monthly' or 'yearly'
sub.expiresAt   // DateTime when subscription ends, null if no expiry set
sub.isActive    // convenience bool, checks status and expiry together
sub.source      // 'revenuecat' or 'supabase'
```

---

## Payment Methods

Users can pay via:

- Card, bank transfer, or USSD through Flutterwave (works everywhere)
- Apple In-App Purchase on iOS (billed through the App Store)
- Google Play Billing on Android (billed through the Play Store)

The correct options appear automatically based on the platform. You do not
control which payment method the user picks.

---

## RevenueCat Setup

Chaild uses RevenueCat to track native IAP subscriptions. You need your own
RevenueCat project because App Store and Play Store billing is tied to the
developer account that published the app.

1. Create a free account at app.revenuecat.com.
2. Create a project and add your iOS and/or Android app.
3. Create an Entitlement with the identifier `pro`.
4. Create products in App Store Connect and Google Play Console (both named
   `pro_monthly` and `pro_yearly`), then attach them to the `pro` entitlement
   in RevenueCat.
5. Create an Offering called `default` containing both packages.
6. Copy your public API key (starts with `appl_` for iOS, `goog_` for Android)
   and pass it to `ChaildAuth.initialize()` as `revenueCatApiKey`.

The RevenueCat secret key is a server-side key used only by Chaild's backend.
You do not manage that. It is already configured on the Chaild platform.

---

## After Payment

You do not need to poll or verify payment yourself. If you used `ChaildGuard`
or `SubscriptionScreen` with an `onSubscribed` callback, that fires once
payment is confirmed. If you need to re-check at any point:

```dart
await ref.read(subscriptionControllerProvider.notifier).refresh();
```

