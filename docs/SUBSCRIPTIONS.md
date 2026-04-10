# Subscriptions

Chaild manages subscriptions on behalf of your app. Users pay a single Chaild
subscription ($3/month) that unlocks every app using the Chaild SDK. You earn
70% of subscription revenue for users you bring to the platform.

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

What the user sees depends on their platform:

**On Android:** Users can pay via Flutterwave (card, bank transfer, USSD,
mobile money) or Google Play Billing. Flutterwave is shown prominently as it
covers the widest range of payment options for users globally.

**On iOS (US App Store):** Users can pay via native App Store In-App Purchase
or Flutterwave / Apple Pay.

**On iOS (all other regions):** Users can pay via native App Store In-App
Purchase only.

You do not control which payment methods are shown. Chaild determines this
based on platform and region.

---

## How Payments Are Managed

All apps using Chaild are published under Chaild's developer accounts on the
App Store and Google Play. This is what makes the single-subscription model
possible and keeps everything compliant with App Store and Google Play policies.

When you register through portal.chaild.app and submit your app, Chaild
handles publication, store submissions, and all billing configuration. You
retain full ownership of your code.

RevenueCat is used internally by Chaild to manage native IAP subscriptions.
You do not need a RevenueCat account. You do not pass any RevenueCat keys.
All of that is managed centrally on the Chaild platform.

---

## After Payment

You do not need to poll or verify payment yourself. If you used `ChaildGuard`
or `SubscriptionScreen` with an `onSubscribed` callback, that fires once
payment is confirmed. If you need to re-check at any point:

```dart
await ref.read(subscriptionControllerProvider.notifier).refresh();
```
