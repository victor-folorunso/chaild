# Building the App

Platform-specific setup required to get Chaild running on iOS and Android.

---

## Android Setup

### Google Sign In

1. Find your debug keystore SHA-1:
   Run this in your terminal (Mac/Linux):
   ```
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   On Windows the keystore is at `%USERPROFILE%\.android\debug.keystore`.

2. Go to console.cloud.google.com, open your project (or create one),
   go to APIs and Services, then Credentials.

3. Create an OAuth Client ID of type Android. Enter your app package name
   (found in `android/app/build.gradle.kts`) and paste the SHA-1.

4. Also create a Web client ID. You will need this for Supabase.

5. Download `google-services.json` from the project overview page and place
   it at `android/app/google-services.json`.

6. In `android/build.gradle.kts` add to the `plugins` block:
   ```
   id("com.google.gms.google-services") version "4.4.0" apply false
   ```

7. In `android/app/build.gradle.kts` add to the `plugins` block:
   ```
   id("com.google.gms.google-services")
   ```

### Deep Link (Payment Return)

Add this inside the `<activity>` tag in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="chaild" />
</intent-filter>
```

### Biometrics

Add inside the `<manifest>` tag in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

---

## iOS Setup

### Google Sign In

1. In Google Cloud Console create an OAuth Client ID of type iOS.
   Enter your app bundle ID (found in `ios/Runner.xcodeproj`).

2. Download `GoogleService-Info.plist` and place it at
   `ios/Runner/GoogleService-Info.plist`.

3. Open `ios/Runner/Info.plist` and add:
   ```xml
   <key>GIDClientID</key>
   <string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```
   Replace `YOUR_IOS_CLIENT_ID` with the client ID from the downloaded plist.

### Apple Sign In

1. You need an Apple Developer account ($99/year).
2. In developer.apple.com go to Certificates, Identifiers and Profiles,
   then Identifiers.
3. Find your app ID and enable Sign In with Apple.
4. Create a Services ID (used as the OAuth client ID for web callbacks).
5. Create a Key with Sign In with Apple enabled. Download the .p8 file.
6. In Supabase, go to Authentication, Providers, Apple and fill in:
   - Client ID: your Services ID
   - Team ID: visible top right on developer.apple.com
   - Key ID: shown when you created the key
   - Private Key: the contents of the .p8 file you downloaded

### Deep Link (Payment Return)

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>chaild</string>
    </array>
  </dict>
</array>
```

### Biometrics (Face ID)

Add to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to unlock the app quickly and securely.</string>
```

---

## RevenueCat API Key Per Platform

You need different RevenueCat public keys for iOS and Android. The recommended
approach is to pass the key at build time using `--dart-define`.

Build command for iOS:
```
flutter build ios --dart-define=RC_KEY=appl_your_ios_key_here
```

Build command for Android:
```
flutter build apk --dart-define=RC_KEY=goog_your_android_key_here
```

In `main.dart` read the key like this:
```dart
const rcKey = String.fromEnvironment('RC_KEY');

await ChaildAuth.initialize(
  partnerKey: 'dev_your_key',
  revenueCatApiKey: rcKey,
  appName: 'Your App',
);
```

---

## Running Locally

```
flutter pub get
flutter run
```

For the app to work end-to-end locally you need the keys filled in and the
Supabase project configured. See `KEYS.md` for how to get each key.

