# Pocket Ledger: from this folder to the Play Store

## 1. Build and run it
1. Install Flutter and Android Studio (for the Android SDK): https://docs.flutter.dev/get-started/install
2. In this folder: `chmod +x setup.sh && ./setup.sh com.yourname`
   (use your own reverse-domain name; it becomes your permanent app id, e.g. `com.yourname.pocket_ledger`. It cannot be changed after publishing.)
3. Plug in a phone (USB debugging on) and run `flutter run`.
4. Quick entry without opening the app: long-press the home screen > Widgets > **Pocket Ledger** to add the widget (shows today's spending; tap it to open a small add-expense popup). Long-pressing the app icon also offers an **Add expense** shortcut.
5. Fix anything `flutter analyze` reports. The code was written without a compiler, so expect to tweak a line or two.

## 2. Turn on accounts and cloud sync (Firebase, free tier)
Without this the app still works, just without sign-in. To enable it:
1. Create a project at https://console.firebase.google.com
2. Build > Authentication > Get started > enable **Email/Password**.
3. Build > Firestore Database > Create database (production mode, pick a region near your users).
4. In Firestore > Rules, paste the contents of `firestore.rules` (this folder) and Publish. It lets each person read and write only their own data.
5. Install the tools once: `npm i -g firebase-tools`, `dart pub global activate flutterfire_cli`, then `firebase login`.
6. In this folder run `flutterfire configure`, pick your project and the Android platform. It overwrites `lib/firebase_options.dart` with your settings.
7. `flutter run`, then Settings > Sign in to sync. Sign in on a second phone to see the same data.

How sync behaves: everything is saved on the phone first and works offline; changes upload in the background and download when you open the app. If the same entry was edited in two places, the newest edit wins.

Shared family ledger (planned next) will build on this same setup.

## 3. Make it yours
- Rename the app: edit `android:label` in `android/app/src/main/AndroidManifest.xml`.
- App icon: add `flutter_launcher_icons` and a 1024x1024 PNG (https://pub.dev/packages/flutter_launcher_icons).
- Version: bump `version: 1.0.0+1` in `pubspec.yaml` for every upload (the number after `+` must increase each time).

## 4. Create a signing key (keep this safe; losing it is painful)
```
keytool -genkey -v -keystore ~/pocket-ledger-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `android/key.properties` (never commit it):
```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/pocket-ledger-upload.jks
```
Edit `android/app/build.gradle.kts`:
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ...existing config...
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```
(Replace the existing `buildTypes { release { ... } }` block rather than duplicating it.)

## 5. Build the upload bundle
```
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

## 6. Play Console
1. Create a developer account: https://play.google.com/console (one-time US$25 fee, identity verification).
   **Personal accounts created after Nov 2023 must run a closed test with at least 12 testers for 14 days before applying for production access.** Check the current rules in the Console, as they change.
2. Create app, choose Free, category Finance (or Productivity).
3. Upload the `.aab` to a Closed testing track first, then Production.
4. Store listing: short description (80 chars), full description, 512x512 icon, 1024x500 feature graphic, 2+ phone screenshots. Draft text is in `STORE_LISTING.md`.
5. Complete: Privacy policy URL (host `PRIVACY_POLICY.md` as a web page, e.g. GitHub Pages), Content rating questionnaire, Target audience (18+), and the Financial features declaration (select "none": the app is a personal tracker with no loans, banking or payments).
   - **Data safety form** (the app now has accounts): data collected = *Email address* (account management) and *Other financial info* (the entries users save for sync). Both are optional, encrypted in transit, not shared, and users can request deletion. 
   - **Account deletion**: Play requires (a) the in-app option (Settings > Delete account, already built) and (b) a public web page explaining how to request deletion, e.g. "email YOUR_EMAIL_HERE from your account address". Enter that page's URL in the Data safety > Account deletion section.
6. Enable Play App Signing when prompted (default).

## 7. Before you scale to other people
- Backups: users can sign in (cloud copy) or use Settings > Back up to a file.
- Firestore free tier (Spark) covers roughly 50k reads and 20k writes per day; plenty for thousands of users with a few entries a day. Watch usage in the Firebase console.
- Add a feedback email in the store listing.
