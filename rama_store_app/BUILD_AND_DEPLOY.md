# Rama Store Mobile Application - Build & Deployment Guide

This guide provides exact copy-pasteable terminal commands to run, build, sign, and deploy the **Rama Store** Flutter mobile app for Android and iOS.

---

## 1. Running Locally in Debug Mode

Make sure Flutter SDK is installed and an Android emulator or iOS simulator is running.

```bash
# 1. Navigate into project directory
cd rama_store_app

# 2. Install Dart & Flutter package dependencies
flutter pub get

# 3. Analyze code quality (0 errors / clean build check)
flutter analyze

# 4. Run on connected Android emulator or iOS simulator (Production Backend)
flutter run
```

### Environment Configurations

- **Production Live Backend (Default)**:
  ```bash
  flutter run --dart-define=BASE_URL=https://rama-store-3u49.onrender.com
  ```

- **Local Development Backend (e.g., localhost Flask server)**:
  ```bash
  # For Android Emulator: 10.0.2.2 points to host machine's localhost
  flutter run --dart-define=BASE_URL=http://10.0.2.2:5000

  # For iOS Simulator or physical device on local Wi-Fi:
  flutter run --dart-define=BASE_URL=http://192.168.1.100:5000
  ```

- **Offline Development / Mock Fallback Mode**:
  ```bash
  flutter run --dart-define=USE_MOCKS=true
  ```

---

## 2. Android Build & Deployment

### Step A: Generate Release Keystore (One-Time Setup)

Run the following command in terminal to create a production signing key:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Step B: Create `android/key.properties`

Create a file named `android/key.properties` with your keystore credentials:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

### Step C: Build Release APK (Direct File Distribution)

Generates a standalone APK for direct installation on Android devices.

```bash
flutter build apk --release --dart-define=BASE_URL=https://rama-store-3u49.onrender.com
```
**Output File Location**:
`build/app/outputs/flutter-apk/app-release.apk`

---

### Step D: Build Release Android App Bundle (Google Play Store)

Generates an Android App Bundle (`.aab`) for publishing on Google Play Console.

```bash
flutter build appbundle --release --dart-define=BASE_URL=https://rama-store-3u49.onrender.com
```
**Output File Location**:
`build/app/outputs/bundle/release/app-release.aab`

---

## 3. iOS Build & App Store Deployment (Requires macOS + Xcode)

### Step A: CocoaPods & Xcode Configuration
```bash
cd ios
pod install
cd ..
```

### Step B: Build Release IPA for App Store / TestFlight

```bash
flutter build ipa --release --dart-define=BASE_URL=https://rama-store-3u49.onrender.com
```

### Step C: Manual Xcode Archive Steps
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select target device: **Any iOS Device (arm64)**.
3. Go to **Product** -> **Archive**.
4. Click **Distribute App** -> Select **App Store Connect** / **TestFlight**.

---

## 4. Firebase App Distribution (Over-The-Air Beta Testing)

To share builds with testers before public store approval:

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Distribute Android APK:
   ```bash
   firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app YOUR_FIREBASE_APP_ID --groups "testers"
   ```

---

## 5. Pre-Release Verification Checklist

- [x] Base API URL defaults to live backend `https://rama-store-3u49.onrender.com`.
- [x] Application ID set to `com.ramastore.mobile`.
- [x] Zero debug print dumps or hardcoded credentials in production release paths.
- [x] Unified Flask session cookie synchronization verified across web and mobile.
