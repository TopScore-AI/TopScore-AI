# topscore_ai

The TopScore AI Flutter mobile app (Android + iOS).

## Prerequisites

- Flutter SDK ≥ 3.27.0 (Dart ≥ 3.5.0)
- JDK 17 (Android Gradle Plugin requirement)
- Android SDK with build-tools for compileSdk 36
- Xcode 15+ and CocoaPods (for iOS)
- Firebase project access (config files in `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist`)

## Local development

```bash
flutter pub get
flutter run
```

## Build configuration

The backend URL and Paystack callback are read at build time via `--dart-define`
with production defaults baked in. Override per environment:

```bash
flutter run --dart-define=BACKEND_BASE_URL=https://staging.agent.topscoreapp.ai
```

| Define                  | Default                              |
| ----------------------- | ------------------------------------ |
| `BACKEND_BASE_URL`      | `https://agent.topscoreapp.ai`       |
| `PAYSTACK_CALLBACK_URL` | `https://topscoreapp.ai/payment/callback` |

## Release builds — Android

### One-time keystore setup

The release `signingConfig` reads `android/key.properties`, which is gitignored.
Generate an upload keystore once:

```bash
cd android
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Copy `key.properties.example` to `key.properties` and fill in the values:

```properties
storeFile=upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

`upload-keystore.jks` and `key.properties` are both gitignored. **Back them up
to a password manager** — losing them prevents future Play Store updates.

If `key.properties` is missing, release builds fall back to debug signing so
`flutter run --release` keeps working locally.

### Build commands

```bash
# Play Store (App Bundle, recommended)
flutter build appbundle --release

# Sideload / direct distribution (arm64 only saves ~130 MB)
flutter build apk --release --target-platform android-arm64
```

Outputs:

- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-release.apk`

## Release builds — iOS

Open `ios/Runner.xcworkspace` in Xcode and configure under *Signing &
Capabilities*:

- Team
- Bundle Identifier (matches Firebase iOS app)
- Provisioning profile (Distribution / App Store)

Then:

```bash
flutter build ipa --release
```

Upload `build/ios/ipa/*.ipa` via Transporter or `xcrun altool`.

## Firebase

`google-services.json` and `GoogleService-Info.plist` must be present locally
but are gitignored. Pull them from the Firebase console for the
`topscore-ai` project.

## Crash reporting

Crashlytics is wired up in `lib/main.dart` for non-web builds. Errors flow
through `FlutterError.onError` and `PlatformDispatcher.onError`.
