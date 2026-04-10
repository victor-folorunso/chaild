# Payment Compliance Reference

This document is for the Chaild platform owner. It captures the compliance
research, platform-specific payment rules, and implementation decisions for
the Chaild subscription model. Read this before making changes to the payment
flow or expanding to new regions.

---

## The Core Model and Why It Is Compliant

Chaild publishes all partner apps under a single Chaild developer account on
both the App Store and Google Play. This is the key architectural decision that
makes the shared-subscription model work legally.

Apple explicitly permits auto-renewable subscriptions that are accessible
through multiple apps, provided all apps are published under the same developer
account. Google Play has no restriction on a single developer account offering
one subscription that unlocks multiple apps, with server-side entitlement
verification as the accepted mechanism.

The model passes because:
- All apps share one developer account (not independent accounts)
- RevenueCat manages entitlements centrally across all apps
- Each partner app delivers distinct functionality (not duplicates)
- Native IAP is offered as the primary path globally

---

## iOS Payment Rules

Apple enforces payment rules based on the end user's App Store storefront
(the country tied to their Apple ID), not where the developer account is
registered. A Nigerian developer account does not change what payment methods
you may offer inside apps.

### By Region

**United States storefront only:**
Apps may include buttons or links directing users to an external web checkout
such as Flutterwave, with zero Apple commission on those transactions. Native
IAP must still be offered as an option. This is the result of the 2025 court
ruling enforcement.

**European Union / EEA:**
External purchase links are allowed via the StoreKit External Purchase Link
Entitlement under DMA rules. Apple applies a reduced commission (approximately
27% or the Core Technology Fee structure). This requires a separate entitlement
application.

**All other regions including Nigeria:**
External links or calls-to-action directing users to non-IAP payment for
digital subscriptions are prohibited under Guideline 3.1.1. Native IAP via
RevenueCat must be the only path.

### Flutterwave Apple Pay on iOS

Flutterwave's hosted checkout supports Apple Pay natively. The flow works like
this:

1. Your backend calls the Flutterwave charge API with type `applepay`.
2. Flutterwave returns an `auth_url` pointing to its hosted checkout page.
3. Your app opens the `auth_url` in a WebView or SFSafariViewController.
4. On the hosted page, Flutterwave surfaces an Apple Pay button automatically
   (visible only on supported iOS devices with a card in Wallet).
5. The user authenticates with Face ID or Touch ID.
6. Apple tokenizes the payment. No raw card details reach Flutterwave or your
   servers.
7. Flutterwave processes the tokenized payment like a standard card transaction.
8. Flutterwave fires a `charge.completed` webhook to your backend.
9. Your backend verifies the webhook signature and grants the subscription.

Apple Pay here is used as a wallet/tokenization layer by Flutterwave, not as
Apple IAP. Apple receives zero commission. You do not need any Apple Pay
configuration on your end since Flutterwave holds the merchant certificate.

**Compliance note:** This flow is still classified by Apple as an external
payment method. It is compliant for US users (where external payments are
permitted) and for physical goods or exempt categories. For digital
subscriptions outside the US, it carries review risk. The safest approach
for non-US iOS users remains native IAP via RevenueCat.

### Recommended iOS Implementation

- Default to native IAP via RevenueCat for all users globally.
- Detect the user's storefront using `Storefront.current.countryCode` or
  equivalent.
- Show the Flutterwave / Apple Pay option only for US storefront users.
- For all other storefronts, present the native IAP flow only.

---

## Android Payment Rules

Google Play's policies are meaningfully more permissive than Apple's. Google
allows developers to use alternative billing systems alongside Google Play
Billing in many markets. In Africa and most emerging markets, Google has not
enforced strict IAP-only requirements for digital subscriptions in the way
Apple has.

### Practical Reality for Nigeria

Many Nigerian Android apps use Flutterwave for digital subscriptions and
remain on the Play Store without issue. Google's own Alternative Billing
Choice program formalizes this, with reduced service fees when you use your
own processor. Nigerian users strongly prefer Flutterwave-based payment
(card, bank transfer, USSD, mobile money) over Google Pay.

### Recommended Android Implementation

- Offer Flutterwave as a prominent, equal payment option for all Android users.
- Keep Google Play Billing available alongside Flutterwave (do not disable it).
- The subscription screen should show both options with clear labels.
- Do not restrict Flutterwave to the US on Android. This is not required by
  Google's current policies and would unnecessarily hurt the Nigerian user
  experience.

The risk profile of Flutterwave on Android is substantially lower than on iOS.
This is a deliberate and defensible product decision based on actual Play Store
enforcement patterns, not a workaround.

---

## Subscription Screen Decision Matrix

| Platform | Region | Primary Option | Secondary Option |
|---|---|---|---|
| iOS | US storefront | Native IAP (RevenueCat) | Flutterwave / Apple Pay |
| iOS | All other regions | Native IAP (RevenueCat) | None |
| Android | All regions | Flutterwave | Google Play Billing |

---

## RevenueCat Configuration

RevenueCat is managed centrally by Chaild. Partner developers do not interact
with RevenueCat or hold RevenueCat accounts.

In App Store Connect and Google Play Console (under the Chaild developer
account), configure:
- Subscription products: `pro_monthly` and `pro_yearly`
- RevenueCat entitlement: `pro`
- RevenueCat offering: `default` containing both packages

The `default` offering is fetched dynamically by the SDK so pricing always
reflects what the store reports. Do not hardcode prices in the Flutter code.

---

## Partner App Compliance Requirements

Each app published under Chaild must meet these requirements to avoid review
flags:

- Distinct functionality from all other partner apps (Guideline 4.3 spam check)
- No misleading claims about the subscription scope or pricing
- Clear disclosure that the subscription is a Chaild platform subscription
- Privacy policy and terms of service linked in the store listing
- App content must comply with the store guidelines for its category

Partner apps that fail these requirements may be rejected or removed. Chaild
reserves the right to decline publication of any app.

---

## Ongoing Monitoring

Apple and Google update their policies regularly. The current favorable stance
on external links (Apple US) and alternative billing (Google) stems from
2024-2025 court rulings and regulatory action. These rules may change.

Review official guidelines before every major release:
- Apple: developer.apple.com/app-store/review/guidelines/
- Google Play: play.google.com/about/developer-content-policy/

The compliance decisions in this document were made based on policy as of
April 2026. Update this file whenever policies materially change.
