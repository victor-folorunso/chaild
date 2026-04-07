# Chaild — Keys, Secrets & Supabase Setup Guide

## Key Ownership: Who Manages What

### YOUR KEYS (Platform Owner — you manage these)

| Key | Where it lives | How to get it |
|---|---|---|
| `supabaseUrl` | `app_env.dart` (baked in SDK) | supabase.com → project → Settings → API → Project URL |
| `supabaseAnonKey` | `app_env.dart` (baked in SDK) | supabase.com → project → Settings → API → anon public |
| `flutterwavePublicKey` | `app_env.dart` (baked in SDK) | dashboard.flutterwave.com → Settings → API Keys → Public Key |
| `FLUTTERWAVE_SECRET_KEY` | **Supabase secrets only** | dashboard.flutterwave.com → Settings → API Keys → Secret Key |
| `FLUTTERWAVE_SECRET_HASH` | **Supabase secrets only** | dashboard.flutterwave.com → Webhooks → create webhook → copy the secret hash you set |
| `REVENUECAT_API_KEY` | **Supabase secrets only** | app.revenuecat.com → project → API Keys → Secret key (starts with sk_) |
| `CRON_SECRET` | **Supabase secrets only** | Make up any strong random string (e.g. openssl rand -hex 32) |

### DEVELOPER KEYS (Partners integrating your SDK provide these)

| Key | Where it lives | How to get it |
|---|---|---|
| `partnerKey` | Their app's `main.dart` | Chaild developer portal (you generate and give to them) |
| `revenueCatApiKey` | Their app's `main.dart` | Their own RevenueCat project → API Keys → Public key (starts with appl_ for iOS, goog_ for Android) |

---

## Step 1 — Create Your Supabase Project

1. Go to **supabase.com** → New Project
2. Choose a region close to Nigeria (e.g. eu-west-1 or af-south-1 if available)
3. Save your database password somewhere safe
4. Go to **Settings → API** and copy:
   - `Project URL` → paste into `ChailAppEnv.supabaseUrl`
   - `anon public` key → paste into `ChailAppEnv.supabaseAnonKey`

---

## Step 2 — Run SQL Patches

Run these IN ORDER in **Supabase → SQL Editor**:

```
001_initial_schema.sql    ← profiles, partners, triggers
002_subscriptions.sql     ← subscriptions table + is_subscribed()
003_partners_referrals.sql ← referrals, partner_earnings, auto-attribution trigger
004_payouts.sql           ← payouts table + payout completion trigger
```

Paste each file's contents and click **Run**.

---

## Step 3 — Set Up Supabase Auth Providers

### Email/Password
**Supabase → Authentication → Providers → Email** — enabled by default.

### Apple Sign In
1. You need an Apple Developer account ($99/year)
2. **developer.apple.com** → Certificates → Identifiers → App IDs → your app → Sign In with Apple ✓
3. Create a **Services ID** (for web OAuth callback)
4. Create a **Key** with Sign In with Apple capability → download the .p8 file
5. **Supabase → Authentication → Providers → Apple**:
   - Client ID: your Services ID (e.g. com.yourdomain.chaild.web)
   - Team ID: your Apple Team ID (top right in developer.apple.com)
   - Key ID: from the key you created
   - Private Key: contents of the .p8 file

### Google Sign In
1. **console.cloud.google.com** → New Project (or use existing)
2. APIs & Services → OAuth consent screen → configure
3. Credentials → Create OAuth Client ID:
   - iOS: bundle ID of your Flutter app
   - Android: package name + SHA-1 fingerprint
   - Web: for Supabase redirect URL
4. **Supabase → Authentication → Providers → Google**:
   - Client ID: your Web client ID
   - Client Secret: your Web client secret
5. Add your iOS/Android client IDs to your Flutter app's native config

---

## Step 4 — Set Up Flutterwave

1. **dashboard.flutterwave.com** → Settings → API Keys
   - Copy **Public Key** → paste into `ChailAppEnv.flutterwavePublicKey`
   - Copy **Secret Key** → this goes to Supabase secrets ONLY (Step 6)

2. **Webhooks** → Add webhook:
   - URL: `https://YOUR_SUPABASE_PROJECT.supabase.co/functions/v1/flutterwave-webhook`
   - Set a **Secret Hash** (make one up, e.g. a strong random string)
   - Save the Secret Hash for Supabase secrets (Step 6)

---

## Step 5 — Set Up RevenueCat

1. **app.revenuecat.com** → New Project → name it "Chaild"
2. Add your iOS app (bundle ID) and/or Android app (package name)
3. **Entitlements** → New Entitlement → identifier: `pro`
4. **API Keys**:
   - Copy **Secret key** (starts with `sk_`) → Supabase secrets only (Step 6)
   - Copy **Public key** for iOS (starts with `appl_`) → your iOS `main.dart`
   - Copy **Public key** for Android (starts with `goog_`) → your Android `main.dart`

---

## Step 6 — Push Secret Keys to Supabase Edge Functions

Install Supabase CLI first:
```bash
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```
(Project ref is in supabase.com → your project → Settings → General)

Then push your secrets:
```bash
supabase secrets set FLUTTERWAVE_SECRET_KEY=FLWSECK-xxxxxxxx
supabase secrets set FLUTTERWAVE_SECRET_HASH=your_webhook_hash
supabase secrets set REVENUECAT_API_KEY=sk_xxxxxxxxxxxxxxxx
supabase secrets set REVENUECAT_ENTITLEMENT=pro
supabase secrets set CRON_SECRET=any_strong_random_string_here
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available
inside edge functions — you do NOT need to set these manually.

---

## Step 7 — Deploy Edge Functions

```bash
supabase functions deploy flutterwave-webhook
supabase functions deploy verify-subscription
supabase functions deploy process-payout
```

Your function URLs will be:
```
https://YOUR_PROJECT_REF.supabase.co/functions/v1/flutterwave-webhook
https://YOUR_PROJECT_REF.supabase.co/functions/v1/verify-subscription
https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-payout
```

Point your Flutterwave webhook at the first URL.

---

## Developer Integration (what partners do)

Once you're live, a developer using your SDK just does:

```dart
// their main.dart
await ChailAuth.initialize(
  partnerKey: 'dev_abc123',          // you give them this from your portal
  revenueCatApiKey: 'appl_xxxxxx',   // their own RC key
  appName: 'Their App Name',
);

// protect any screen
ChailGuard(child: TheirScreen())
```

They never see your Supabase URL, Flutterwave keys, or RevenueCat secret.
They only need their partner key and their own RC public key.

---

## Security Summary

```
Flutter app (ships to users)          Safe — only public keys
  ChailAppEnv.supabaseUrl             ✅ public
  ChailAppEnv.supabaseAnonKey         ✅ public (RLS protects data)
  ChailAppEnv.flutterwavePublicKey    ✅ public (only opens checkout)
  revenueCatApiKey (dev's own key)    ✅ public (RC public key only)

Supabase Edge Function Secrets        🔒 never leaves server
  FLUTTERWAVE_SECRET_KEY              🔒 server-side payouts only
  FLUTTERWAVE_SECRET_HASH             🔒 webhook verification only
  REVENUECAT_API_KEY                  🔒 granting entitlements only
  CRON_SECRET                         🔒 payout trigger only
  SUPABASE_SERVICE_ROLE_KEY           🔒 auto-injected, never set manually
```
