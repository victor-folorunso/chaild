# Keys -- How to Get Everything You Need

This file is for you, the Chaild platform owner. Plain English, no jargon.
These are YOUR keys that run the Chaild backend. Not for developers using
the SDK.

---

## Supabase URL and Anon Key

These go into `packages/chaild_auth/lib/src/config/app_env.dart`.

1. Go to supabase.com and sign in.
2. Open your project (or create one if you have not yet).
3. Click Settings in the left sidebar.
4. Click API.
5. You will see two things you need:
   - "Project URL" -- this is your supabaseUrl. Looks like
     https://abcdefghijk.supabase.co
   - Under "Project API Keys" find the row that says "anon public" and
     copy the key next to it. This is your supabaseAnonKey.

Paste both into app_env.dart where it says YOUR_SUPABASE_URL and
YOUR_SUPABASE_ANON_KEY.

---

## Flutterwave Public Key

This also goes into app_env.dart.

1. Go to dashboard.flutterwave.com and sign in.
2. Click Settings in the left sidebar.
3. Click API Keys.
4. Copy the key labelled "Public Key". It starts with FLWPUBK_TEST
   while you are in test mode and FLWPUBK- when you go live.

Paste it into app_env.dart where it says YOUR_FW_PUBLIC_KEY.

---

## Flutterwave Secret Key

This is a server-only key. Do NOT put it in any Flutter file.

1. Same page as above (Flutterwave Settings, API Keys).
2. Copy the key labelled "Secret Key". It starts with FLWSECK_TEST
   in test mode.

You will push this to Supabase using the CLI (see the "Pushing to Supabase"
section below).

---

## Flutterwave Webhook Hash

This is a password you create yourself. Flutterwave uses it to prove that
a webhook request really came from them.

1. Go to dashboard.flutterwave.com.
2. Click Settings, then Webhooks.
3. Add a new webhook.
4. The URL is:
   https://YOUR_SUPABASE_PROJECT_REF.supabase.co/functions/v1/flutterwave-webhook
   (replace YOUR_SUPABASE_PROJECT_REF with your project ref -- see below for
   how to find that)
5. In the "Secret Hash" field type any strong password you make up.
   Write it down. You will push it to Supabase as FLUTTERWAVE_SECRET_HASH.

---

## Supabase Project Ref

You need this for the CLI and for constructing function URLs.

1. Go to supabase.com, open your project.
2. Click Settings, then General.
3. You will see "Reference ID" -- that is your project ref.
   It is the same string that appears in your Project URL.
   Example: if your URL is https://abcdefghijk.supabase.co then your
   project ref is abcdefghijk.

---

## RevenueCat Secret Key (server-side)

This goes to Supabase only. Never in Flutter code.

1. Go to app.revenuecat.com and sign in.
2. Open your project.
3. Click API Keys in the left sidebar.
4. Find the key that starts with sk_. That is the secret key.

You will push it to Supabase as REVENUECAT_API_KEY.

---

## RevenueCat Public Key for iOS

This goes into your Flutter build command (not hardcoded in files).

1. Same page -- app.revenuecat.com, your project, API Keys.
2. Find the key that starts with appl_. That is for iOS.

---

## RevenueCat Public Key for Android

1. Same page.
2. Find the key that starts with goog_. That is for Android.

---

## Cron Secret

This is another password you make up. It protects the payout trigger from
being called by anyone other than you.

Open your terminal and run:
```
openssl rand -hex 32
```

Copy the output. That is your CRON_SECRET.
If you do not have openssl, just type a long random string of letters and
numbers. No one else will ever see it.

---

## Pushing Keys to Supabase

You do this once using the Supabase CLI. Install it first:

```
npm install -g supabase
```

Then log in and link to your project:

```
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

Then push all your secret keys:

```
supabase secrets set FLUTTERWAVE_SECRET_KEY=paste_your_flw_secret_here
supabase secrets set FLUTTERWAVE_SECRET_HASH=paste_your_webhook_hash_here
supabase secrets set REVENUECAT_API_KEY=paste_your_rc_secret_here
supabase secrets set REVENUECAT_ENTITLEMENT=pro
supabase secrets set CRON_SECRET=paste_your_cron_secret_here
```

You do not need to set SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.
Supabase injects those automatically inside edge functions.

---

## Deploying Edge Functions

After pushing secrets, deploy the functions:

```
supabase functions deploy flutterwave-webhook
supabase functions deploy verify-subscription
supabase functions deploy process-payout
supabase functions deploy payout-webhook
supabase functions deploy attribute-user
supabase functions deploy record-usage
supabase functions deploy distribute-revenue
```

Note: `payout-webhook`, `attribute-user`, `record-usage`, and
`distribute-revenue` are listed in the roadmap to be built. Deploy them
once they exist.

---

## Summary Table

| Key | Where it goes | How to get it |
|---|---|---|
| supabaseUrl | app_env.dart | Supabase project Settings, API, Project URL |
| supabaseAnonKey | app_env.dart | Supabase project Settings, API, anon public |
| flutterwavePublicKey | app_env.dart | Flutterwave Settings, API Keys, Public Key |
| FLUTTERWAVE_SECRET_KEY | Supabase CLI secrets | Flutterwave Settings, API Keys, Secret Key |
| FLUTTERWAVE_SECRET_HASH | Supabase CLI secrets | You create this in Flutterwave Webhooks |
| REVENUECAT_API_KEY | Supabase CLI secrets | RevenueCat project, API Keys, secret key (sk_) |
| REVENUECAT_ENTITLEMENT | Supabase CLI secrets | Always the word: pro |
| CRON_SECRET | Supabase CLI secrets | You generate this with openssl rand -hex 32 |
| RC iOS public key | Flutter build --dart-define | RevenueCat API Keys, starts with appl_ |
| RC Android public key | Flutter build --dart-define | RevenueCat API Keys, starts with goog_ |

