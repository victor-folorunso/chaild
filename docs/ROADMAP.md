# Chaild Implementation Roadmap

This document is for the Chaild platform owner. It covers everything that needs
to be built, fixed, or changed to bring Chaild to a production-ready state.
It does not repeat what is already working. Every item here is an action.

---

## How to Use This Document

Work top to bottom. Each section has numbered tasks. Tasks inside a section can
sometimes be done in parallel but the sections themselves must be completed in
order. Do not skip to storage or portal work until auth and payments are solid.

---

## Section 1 -- Wire Up Keys (Blocker)

Nothing runs until these are filled in. Do this before touching any code.

1. Create your Supabase project and copy the Project URL and anon public key
   into `packages/chaild_auth/lib/src/config/app_env.dart`.
2. Copy your Flutterwave public key into `app_env.dart`.
3. Get your RevenueCat iOS public key and paste it into `lib/main.dart`
   as `_revenueCatApiKey` when building for iOS.
4. Get your RevenueCat Android public key and use it when building for Android.
5. Run all four SQL patches in order in Supabase SQL Editor.
6. Install the Supabase CLI, link your project, and push all secret keys
   (Flutterwave secret, webhook hash, RevenueCat secret key, cron secret).
7. Deploy all three edge functions via the Supabase CLI.
8. Point your Flutterwave webhook URL at the deployed `flutterwave-webhook`
   function URL.

See `KEYS.md` for plain-English instructions on getting each key.

---

## Section 2 -- Critical Bug Fixes

These are crashes and missing pieces that will break the app at runtime.


### 2.1 -- Apple Sign In Platform Guard

Apple Sign In only works on iOS. The current `auth_service.dart` calls
`SignInWithApple.getAppleIDCredential()` regardless of platform. On Android
this will throw an exception immediately.

Tasks:
- Add a platform check before calling Apple Sign In.
- Hide the Apple Sign In button entirely on Android in the login screen UI.
- Use `dart:io` `Platform.isIOS` or the `defaultTargetPlatform` check
  from Flutter foundation.

### 2.2 -- Google Sign In Native Configuration

The Dart code for Google Sign In exists but the native files are missing.
Without these the app will crash on launch on both platforms.

Tasks:
- Android: generate a SHA-1 fingerprint for your debug keystore, register
  it in Google Cloud Console, download `google-services.json` and place it
  at `android/app/google-services.json`.
- Android: add the `google-services` classpath plugin to
  `android/build.gradle.kts` and apply it in `android/app/build.gradle.kts`.
- iOS: download `GoogleService-Info.plist` from Google Cloud Console and
  place it at `ios/Runner/GoogleService-Info.plist`.
- iOS: add the `GIDClientID` URL scheme to `ios/Runner/Info.plist`.

### 2.3 -- Missing delete_user RPC

`auth_service.dart` calls `_client.rpc('delete_user')` but no such function
exists in the database. Account deletion will crash.

Tasks:
- Write SQL patch `005_rpc_delete_user.sql` in `supabase_diary/patches/`.
- The function must run as SECURITY DEFINER, delete the row from `auth.users`
  where `id = auth.uid()`, and cascade will handle profiles automatically.
- Run the patch in Supabase SQL Editor.

### 2.4 -- Missing payout-webhook Edge Function

`process-payout` sends a `callback_url` pointing to a `payout-webhook`
function that does not exist. Payout status will never update to completed.

Tasks:
- Create `supabase_diary/functions/payout-webhook/index.ts`.
- This function receives Flutterwave transfer webhook events.
- On a `transfer.completed` event it updates the matching payout row status
  to `completed` using the `flutterwave_reference` to find the row.
- On a `transfer.failed` event it sets status to `failed` and stores the
  failure reason.
- Verify the request using `FLUTTERWAVE_SECRET_HASH` same as the payment
  webhook.
- Deploy the new function with the Supabase CLI.

### 2.5 -- Deep Link / URL Scheme Registration

`payment_service.dart` sets `redirect_url: 'chaild://payment-complete'` but
no URL scheme is registered to catch this. After payment the browser cannot
return the user to the app.

Tasks:
- Android: add an intent filter for the `chaild://` scheme in
  `android/app/src/main/AndroidManifest.xml`.
- iOS: add `chaild` as a URL scheme in `ios/Runner/Info.plist` under
  `CFBundleURLTypes`.
- The app does not need to do anything special when the link fires because
  payment confirmation is handled by polling. The redirect just closes the
  browser and returns focus to the app.


---

## Section 3 -- Payments: Complete the Native IAP Flow

RevenueCat is integrated for subscription checking but there is no UI path
to trigger a native in-app purchase through the App Store or Play Store.
Currently the only payment path is Flutterwave. Both must work.

### 3.1 -- Add Native IAP Purchase Flow in SubscriptionScreen

Tasks:
- Add a second payment option in `subscription_screen.dart` for native IAP
  (Apple In-App Purchase on iOS, Google Play Billing on Android).
- Show Flutterwave payment for all users as it works everywhere.
- Show native IAP as an alternative option labelled clearly by platform.
- Wire the native IAP button to call `Purchases.purchasePackage()` from
  the RevenueCat SDK.
- On successful purchase RevenueCat automatically grants the entitlement.
  Call `SubscriptionService.refreshAfterPayment()` after purchase completes.
- Handle `PurchasesErrorCode.purchaseCancelledError` silently (user backed out).
- Handle other errors with a user-friendly message.

### 3.2 -- RevenueCat Product Setup

Tasks:
- In App Store Connect create a subscription product with identifier `pro_monthly`
  and `pro_yearly`.
- In Google Play Console do the same.
- In RevenueCat dashboard create a Product for each, attach them to the `pro`
  Entitlement, and create an Offering called `default` containing both packages.
- The Flutter code fetches the `default` offering and displays packages
  dynamically so prices shown always match what the store reports.

### 3.3 -- Platform-Specific RevenueCat Key Injection

Tasks:
- Remove the hardcoded `_revenueCatApiKey` constant from `main.dart`.
- Use `--dart-define=RC_KEY=xxx` at build time per platform.
- Read it in code with `const String.fromEnvironment('RC_KEY')`.
- Document the build commands in `docs/BUILDING.md`.

---

## Section 4 -- Security Features

### 4.1 -- Biometric Authentication

Add optional biometric unlock (fingerprint, face ID) using the `local_auth`
package. This is an SDK feature so it lives inside `chaild_auth`.

Tasks:
- Add `local_auth` to `packages/chaild_auth/pubspec.yaml`.
- Create `services/biometric_service.dart` with:
  - `isAvailable()` returning bool
  - `authenticate(reason: String)` returning bool
  - `isEnabled()` reading from secure storage whether user opted in
  - `setEnabled(bool)` saving the preference to secure storage
- Add biometric toggle to `account_screen.dart`.
- Add a `ChaildAppLock` widget that wraps the partner's app content and
  re-prompts biometrics after a configurable idle timeout.
- The partner app passes the timeout to `ChaildAuth.initialize()` as an
  optional `appLockTimeout` duration. Default is no lock.
- Required native setup:
  - Android: add `USE_BIOMETRIC` and `USE_FINGERPRINT` permissions to
    `AndroidManifest.xml`.
  - iOS: add `NSFaceIDUsageDescription` to `Info.plist`.

### 4.2 -- Two-Factor Authentication (TOTP)

Supabase has built-in TOTP 2FA. Wire it up.

Tasks:
- Create `services/two_factor_service.dart` with:
  - `enroll()` returning the TOTP URI and QR code data for the user to scan
  - `verify(code)` completing enrollment
  - `challenge()` initiating a challenge on sign-in
  - `unenroll()` removing 2FA
  - `isEnrolled()` checking current status
- Add a 2FA setup screen `screens/two_factor_screen.dart` that shows a QR code
  (use the `qr_flutter` package) and a verification code input.
- Add 2FA entry to `account_screen.dart`.
- Update the sign-in flow in `auth_controller.dart` to detect when a 2FA
  challenge is required after email/password sign-in and route to a code
  entry screen before completing authentication.


### 4.3 -- App Lock (Idle Timeout)

Tasks:
- Create `widgets/chaild_app_lock.dart`.
- This widget wraps any content the partner passes in.
- It listens to app lifecycle state changes.
- When the app goes to background, it records the timestamp.
- When the app returns to foreground, it checks elapsed time against the
  configured `appLockTimeout`.
- If timeout has elapsed and biometrics are enabled, it covers the screen
  with a lock overlay and prompts biometric authentication.
- If biometrics are not available it falls back to asking for the account
  password via a minimal overlay screen.
- The lock overlay must be visually opaque so app content cannot be seen
  in the app switcher.

### 4.4 -- Optional ID Verification (Scaffold Only)

ID verification requires a third-party KYC provider (Smile Identity,
Dojah, or similar). The full integration is a separate project. For now:

Tasks:
- Add `id_verified` boolean column to the `profiles` table in a new SQL
  patch `006_id_verification.sql`. Default false.
- Add `requiresIdVerification` optional bool to `ChaildAuth.initialize()`.
  Default false.
- Add `requires_id_verification` boolean to the `partners` table so each
  partner app can declare its requirement independently.
- In `ChaildGuard`, after confirming the user is subscribed, check if the
  partner requires ID verification and if the user's profile has
  `id_verified = false`. If so, show a placeholder screen explaining
  verification is coming.
- This scaffold means the flag is in the database and the check is in the
  gating logic. When a real KYC provider is chosen, only the placeholder
  screen needs to be replaced with the actual flow.

---

## Section 5 -- Storage Package

Create a new package `packages/chaild_storage` following the same pattern
as `chaild_auth`.

### 5.1 -- Package Scaffold

Tasks:
- Create `packages/chaild_storage/pubspec.yaml` with dependencies on
  `shared_preferences` and `flutter_secure_storage`.
- Create `packages/chaild_storage/lib/chaild_storage.dart` as the public
  export file.
- Add `chaild_storage: path: packages/chaild_storage` to the root
  `pubspec.yaml` dependencies.

### 5.2 -- Core Key-Value API

Tasks:
- Create `lib/src/chaild_storage_config.dart` with the `ChaildStorage` class.
- Implement `initialize(namespace: String)` which must be called once
  alongside `ChaildAuth.initialize()` in `main()`.
- Implement `set(key, value)` serializing to JSON and saving via
  `shared_preferences` with the namespace prefix applied to the key.
- Implement `get(key)` deserializing from JSON. Returns null if not found.
- Implement `setSecure(key, value)` saving via `flutter_secure_storage`.
- Implement `getSecure(key)` reading from `flutter_secure_storage`.
- Implement `delete(key)` removing a key from `shared_preferences`.
- Implement `deleteSecure(key)` removing from `flutter_secure_storage`.
- Implement `has(key)` returning bool.
- Implement `clear()` removing all keys under this app's namespace only.
  It must not wipe keys belonging to other namespaces.

### 5.3 -- Collection API

Tasks:
- Create `lib/src/chaild_collection.dart` with the `ChaildCollection` class.
- `ChaildStorage.collection(name)` returns a `ChaildCollection` instance.
- Collections store their data as a single JSON-encoded list under the key
  `__collection__namespacename__collectionname` in `shared_preferences`.
- Each item in the collection is a `Map<String, dynamic>` with an auto-
  generated `_id` field (use `DateTime.now().microsecondsSinceEpoch`
  as a simple unique id).
- Implement `add(Map)` appending to the list and saving. Returns the
  generated id.
- Implement `getAll()` returning `List<Map<String, dynamic>>`.
- Implement `getById(id)` returning `Map<String, dynamic>?`.
- Implement `update(id, Map)` merging the new map into the existing item.
- Implement `delete(id)` removing the item with matching `_id`.
- Implement `clear()` wiping the entire collection for this namespace.


### 5.4 -- Query Builder (where / and / or)

Tasks:
- Create `lib/src/chaild_query.dart` with the `ChaildQuery` class.
- `ChaildCollection.where(field, {isEqualTo, isGreaterThan, isLessThan, contains})`
  returns a `ChaildQuery` instance holding the collection reference and the
  first condition.
- `ChaildQuery.and(field, {isEqualTo, isGreaterThan, isLessThan, contains})`
  appends an AND condition and returns `this` for chaining.
- `ChaildQuery.or(field, {isEqualTo, isGreaterThan, isLessThan, contains})`
  appends an OR condition and returns `this`.
- `ChaildQuery.andGroup(QueryBuilder builder)` appends a grouped AND condition.
  `QueryBuilder` is a typedef for `ChaildQuery Function(ChaildQuery)`.
- `ChaildQuery.orGroup(QueryBuilder builder)` same but OR.
- Calling `await query` (making `ChaildQuery` implement `Future`) executes the
  query, loads all items from the collection, evaluates the condition tree
  in memory, and returns `List<Map<String, dynamic>>`.
- Internally represent the condition tree as a simple sealed class hierarchy:
  `_Condition`, `_AndGroup`, `_OrGroup`. Keep this private.
- When cloud storage is added later, the same tree is walked to produce
  Supabase query operators. The public API never changes.

### 5.5 -- Export and Integration

Tasks:
- Export all public classes from `chaild_storage.dart`.
- Update the demo `lib/main.dart` to call `ChaildStorage.initialize()` after
  `ChaildAuth.initialize()` to confirm it compiles and runs.
- Write a short usage example in `docs/STORAGE.md`.

---

## Section 6 -- Bundle ID Enforcement

Prevents partner key theft. Implemented server-side so it cannot be bypassed
in Flutter code.

### 6.1 -- Database Changes

Tasks:
- Add SQL patch `007_bundle_id_enforcement.sql`.
- Add `allowed_bundle_ids` text array column to the `partners` table.
  Default empty array.
- Add `app_platform` text column to `profiles` (ios / android / web) to
  record what platform a user signed up from.

### 6.2 -- SDK Sends Bundle ID on Initialize

Tasks:
- Add `bundleId` as a required parameter to `ChaildAuth.initialize()`.
- Use the `package_info_plus` package to read the actual bundle ID at
  runtime so the developer does not have to hardcode it.
- Store the bundle ID in `ChaildAuth` alongside `partnerKey`.
- Pass the bundle ID in the header or body of any request to Supabase edge
  functions that handle user signup attribution.

### 6.3 -- Verify Bundle ID in Edge Function

Tasks:
- Update the partner attribution logic (currently in `auth_service.dart`
  client-side inside `_setPartnerKey`) to instead call a new edge function
  `attribute-user`.
- Create `supabase_diary/functions/attribute-user/index.ts`.
- This function receives `partner_key`, `user_id`, and `bundle_id`.
- It looks up the partner by key, checks that `bundle_id` is in
  `allowed_bundle_ids`. If not, it returns 403 and does not write any
  referral or partner key to the user profile.
- It writes the `partner_key` and `app_platform` to the profile and creates
  the referral record.
- Remove the client-side `_setPartnerKey` logic from `auth_service.dart`.

### 6.4 -- Developer Portal Registration Support

Tasks:
- Add an endpoint or Supabase RPC `register_bundle_id(partner_key, bundle_id)`
  that appends a bundle ID to the partner's `allowed_bundle_ids` array.
- This is called from the developer portal when a developer registers a new app.
- A partner can have multiple bundle IDs (multiple apps).

---

## Section 7 -- Revenue Split and Usage Tracking

### 7.1 -- Usage Tracking Service

Tasks:
- Create `services/usage_tracking_service.dart` in `chaild_auth`.
- On app foreground, record a session start timestamp in secure storage.
- On app background, compute elapsed seconds and send a heartbeat to a new
  edge function `record-usage`.
- Create `supabase_diary/functions/record-usage/index.ts` that upserts a
  row in a new `app_usage` table.


### 7.2 -- App Usage Table

Tasks:
- Write SQL patch `008_app_usage.sql`.
- Create table `app_usage` with columns:
  `id, user_id, partner_key, month (YYYY-MM text), seconds_used bigint,
  weighted_seconds bigint, updated_at`.
- `weighted_seconds` is `seconds_used * referral_weight` where
  `referral_weight` is 2 if this user was directly referred by this
  partner, 1 otherwise.
- Create a unique index on `(user_id, partner_key, month)`.
- The `record-usage` edge function uses an upsert on this index, incrementing
  `seconds_used` by the heartbeat duration.

### 7.3 -- Monthly Revenue Distribution Function

Tasks:
- Create edge function `distribute-revenue` triggered on a monthly schedule
  via Supabase pg_cron (run on the 1st of each month).
- For each active subscription that renewed in the past month, look up all
  `app_usage` rows for that user in that month.
- Sum all `weighted_seconds` across apps for that user.
- For each partner that has usage for that user, compute:
  `(partner_weighted_seconds / total_weighted_seconds) * subscription_amount_ngn`
- Insert a `partner_earnings` row for each partner for each user.
- Update `partners.total_earned` accordingly.
- The referral multiplier of 2 is already baked into `weighted_seconds` at
  write time so no special logic is needed here.

### 7.4 -- Referral Availability

Tasks:
- Referrals are only available to registered developer partners.
  Regular users cannot have a referral/partner key.
- Enforce this in the `attribute-user` edge function: reject any `partner_key`
  that does not exist in the `partners` table.
- Add a link inside the Chaild app account screen pointing users to
  `portal.chaild.app` to register as a developer if they want referral income.

---

## Section 8 -- Developer Portal (Separate Web App)

The portal is a separate web application at `portal.chaild.app`. It connects
to the same Supabase backend as the Flutter SDK. Developers log in with their
email and manage their apps from there. They never access user data directly.

### 8.1 -- Portal Authentication

Tasks:
- The portal uses Supabase Auth (email/password for developers).
- Developers are distinct from end users. Create a separate `developer_accounts`
  table (or use a `role` column on the existing `partners` table) so a
  developer login session cannot access user data.
- RLS on `partners` must allow a developer to read and update only their own row.
- RLS on `partner_earnings` must allow a developer to read only their own
  earnings rows (by `partner_key`).
- RLS on `payouts` must allow a developer to read only their own payouts.

### 8.2 -- Portal Features (Minimum Viable)

Tasks:
- Register page: developer provides name, email, password, app name, bundle ID.
  Creates a `partners` row with a generated `key` (uuid-based, prefixed
  with `dev_`).
- Dashboard page: shows total users referred, total earned, total paid out,
  unpaid balance.
- Apps page: lists registered bundle IDs, allows adding new bundle IDs.
- Payout settings page: developer enters bank account details (bank code,
  account number). These are stored in `partners.bank_account` as JSON.
- Earnings history page: list of `partner_earnings` rows with dates and amounts.
- Payout history page: list of `payouts` rows with status.

### 8.3 -- Portal Tech Stack Decision

Tasks:
- Choose between Next.js, SvelteKit, or plain HTML with Supabase JS SDK.
  All are valid. Next.js is recommended for long-term maintainability.
- Create a new repository separate from the Flutter project.
- The portal does not live inside the `chaild` Flutter project folder.


---

## Section 9 -- Multiple Payout Options

Currently payout only supports Flutterwave bank transfer. Add crypto.

### 9.1 -- Payout Method on Partner Profile

Tasks:
- Add `payout_method` enum column to `partners` table in a new patch:
  values `bank_transfer` and `crypto`. Default `bank_transfer`.
- Add `crypto_wallet` JSONB column to `partners` for wallet address and
  network (e.g. `{address: '0x...', network: 'USDT-TRC20'}`).
- Update the portal payout settings page to let developers choose their
  payout method and fill in the relevant details.

### 9.2 -- Crypto Payout Path in process-payout

Tasks:
- In `process-payout`, after checking unpaid balance, check `payout_method`.
- If `bank_transfer`, use the existing Flutterwave transfer flow.
- If `crypto`, use a crypto payment provider API (Binance Pay, Coinbase
  Commerce, or manual USDT transfer depending on chosen provider).
- Log the transaction reference regardless of method.
- The `payouts` table already has a generic `flutterwave_reference` column.
  Rename it to `transfer_reference` in a migration and update the function.

---

## Section 10 -- UI Polish and Progressive Disclosure

Chaild should never feel cluttered even as features grow.

### 10.1 -- Account Screen Structure

Tasks:
- Organise `account_screen.dart` into collapsible sections: Security,
  Subscription, About.
- Security section contains: biometrics toggle, 2FA setup, app lock timeout.
- Subscription section contains: current plan, expiry, manage/upgrade.
- About section contains: link to Chaild website, link to developer portal,
  version number.
- Never show a feature toggle if the feature is not available on the device
  (e.g. hide biometrics toggle if `local_auth` reports no hardware).

### 10.2 -- Subscription Screen

Tasks:
- The subscription screen currently only shows Flutterwave.
- Add native IAP as a second option after the Flutterwave button.
- Label them clearly: "Pay with card / bank transfer" and "Pay with
  App Store / Play Store".
- Show only the relevant native option per platform (App Store on iOS,
  Play Store on Android).

### 10.3 -- ChaildGuard Subscription Check

Tasks:
- Read `chaild_guard.dart` and verify it checks subscription status and not
  just authentication.
- If it only checks auth, update it to also check `SubscriptionService.isSubscribed()`.
- If the user is authenticated but not subscribed, show `SubscriptionScreen`
  instead of the protected content.
- If the user is neither authenticated nor subscribed, show the auth flow first,
  then the subscription screen.

---

## Section 11 -- SQL Patches Needed (Summary)

These patches do not yet exist and must be written and run in order after the
existing 004 patch:

- `005_rpc_delete_user.sql` -- delete_user RPC function
- `006_id_verification.sql` -- id_verified on profiles, requires_id_verification
  on partners
- `007_bundle_id_enforcement.sql` -- allowed_bundle_ids on partners, app_platform
  on profiles
- `008_app_usage.sql` -- app_usage table for time-weighted revenue split
- `009_rename_transfer_reference.sql` -- rename flutterwave_reference to
  transfer_reference on payouts, add payout_method and crypto_wallet to partners

---

## Section 12 -- Edge Functions Needed (Summary)

These functions do not yet exist:

- `payout-webhook` -- handles Flutterwave transfer status callbacks
- `attribute-user` -- replaces client-side _setPartnerKey, enforces bundle ID
- `record-usage` -- receives usage heartbeats from the SDK
- `distribute-revenue` -- monthly cron job for revenue split calculation

---

## Definition of Production Ready

Chaild is production ready when:
- All keys are filled in and edge functions are deployed
- The app runs without crashes on both iOS and Android
- A new user can sign up, subscribe via Flutterwave, and access a partner app
- A developer can register on the portal, get a key, and integrate the SDK
- Biometrics and 2FA work on supported devices
- Partners receive automatic monthly payouts above the minimum threshold
- Bundle ID enforcement prevents key theft
- All SQL patches from 001 to 009 have been run
- ChaildStorage works locally with key-value and collections

