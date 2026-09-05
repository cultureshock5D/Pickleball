# 🛡️ Application Safety & Security Guidelines

This guide details the security practices and compliance standards required to ensure the RPI Reservation mobile application is safe, private, and trusted by Android Play Protect and iOS App Store security systems.

---

## 1. Release Signing Configuration
Never install or distribute an application signed with the default debug keystore (`debug.keystore`). Security systems flag debug-signed release builds as potential malware/unsafe.

### Setup Process
1. Generate a secure release upload key:
   ```bash
   keytool -genkey -v -keystore android/app/release.keystore -alias rpi-upload-key -keyalg RSA -keysize 2048 -validity 10000
   ```
2. Create a local, untracked configuration file `android/key.properties` containing:
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=rpi-upload-key
   storeFile=release.keystore
   ```
3. The Gradle build system automatically reads this file to secure your production build. `key.properties` is globally ignored in `.gitignore` to prevent secret leaks.

---

## 2. Restricting Network Cleartext Traffic
Cleartext (HTTP) traffic to arbitrary domains is disabled by default starting on Android 9 (API 28). Setting global `usesCleartextTraffic="true"` in `AndroidManifest.xml` triggers security warnings.

### Alignment Rule
* Enforce HTTPS globally via `network_security_config.xml`.
* Restrict HTTP cleartext traffic **only** to specific local IP ranges (e.g. `192.168.1.100` for the Raspberry Pi stream) and `localhost`.

**Implementation Reference:**
* Config location: `android/app/src/main/res/xml/network_security_config.xml`
* Reference in manifest: `android:networkSecurityConfig="@xml/network_security_config"`

---

## 3. Minimizing Permissions Footprint
Declaring sensitive permissions that are not actively requested or handled in application logic triggers immediate flags on modern mobile platforms.

### Audit Rules
* **Unused Permissions:** Remove unused permission requests (e.g., `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`) from `AndroidManifest.xml`.
* **Necessary Permissions:** Only declare `INTERNET` (standard networking), `CAMERA` (for scanning/photo attachments), and `POST_NOTIFICATIONS` (for booking reminders).

---

## 4. Secure Local Storage
Never store raw API keys, session tokens, or passwords in plain text using `shared_preferences` directly.

### Alignment Rule
* Use `flutter_secure_storage` or encrypt sensitive database caches.
* Use `shared_preferences` only for non-sensitive data (e.g. user theme preferences, onboarding completion).

---

## 5. Enable Code Obfuscation
Prevent reverse-engineering of the application code which could expose internal API routes, local algorithms, or Supabase endpoints.

### Alignment Rule
* Build the application with obfuscation enabled:
  ```bash
  flutter build apk --obfuscate --split-debug-info=build/app/outputs/symbols
  ```
