#!/usr/bin/env bash
# Run once from inside this folder, with Flutter installed (https://docs.flutter.dev/get-started/install).
# Usage: ./setup.sh com.yourname      (your reverse-domain org; final app id = <org>.pocket_ledger)
set -euo pipefail
ORG="${1:?Usage: ./setup.sh com.yourname}"
PKG="$ORG.pocket_ledger"

# Generates the android/ folder without touching lib/ or pubspec.yaml.
flutter create --org "$ORG" --project-name pocket_ledger --platforms=android .

# ---- Home-screen widget + quick-add popup + launcher shortcut (Android side) ----
KDIR="android/app/src/main/kotlin/$(echo "$PKG" | tr . /)"
mkdir -p "$KDIR"
for f in MainActivity QuickAddActivity QuickAddWidget; do
  sed "s/PACKAGE_NAME/$PKG/g" "android_overlay/kotlin/$f.kt" > "$KDIR/$f.kt"
done
cp -r android_overlay/res/. android/app/src/main/res/
sed -i.bak "s/PACKAGE_NAME/$PKG/g" android/app/src/main/res/xml/shortcuts.xml && rm android/app/src/main/res/xml/shortcuts.xml.bak
python3 - <<'PY'
p = 'android/app/src/main/AndroidManifest.xml'
s = open(p).read()
if 'QuickAddActivity' not in s:
    acts = open('android_overlay/manifest_application.xml').read()
    meta = open('android_overlay/manifest_shortcut_meta.xml').read()
    s = s.replace('</activity>', meta + '        </activity>', 1)   # MainActivity: launcher shortcut
    s = s.replace('</application>', acts + '    </application>', 1)  # quick-add activity + widget
    open(p, 'w').write(s)
PY

# Permissions + SDK level needed by cloud sync (release builds have no INTERNET by default).
python3 - <<'PY'
import re
p = 'android/app/src/main/AndroidManifest.xml'
s = open(p).read()
if 'android.permission.INTERNET' not in s:
    perm = open('android_overlay/manifest_permissions.xml').read()
    s = s.replace('<application', perm + '    <application', 1)
    open(p, 'w').write(s)
for g in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    try:
        t = open(g).read()
    except FileNotFoundError:
        continue
    t2 = t.replace('minSdk = flutter.minSdkVersion', 'minSdk = maxOf(23, flutter.minSdkVersion)')
    t2 = t2.replace('minSdkVersion flutter.minSdkVersion', 'minSdkVersion Math.max(23, flutter.minSdkVersion)')
    if t2 != t:
        open(g, 'w').write(t2)
PY

# Sign every build with the same permanent key (signing/release.keystore) so new APKs update the installed app
# and keep its data. (A fresh throwaway key each build would force an uninstall.)
python3 - <<'PY'
import os
kts = 'android/app/build.gradle.kts'
gr = 'android/app/build.gradle'
CFG_KTS = """    signingConfigs {
        create("release") {
            storeFile = file("../../signing/release.keystore")
            storePassword = "pocketledger"
            keyAlias = "pocket"
            keyPassword = "pocketledger"
        }
    }
    buildTypes {"""
CFG_GR = """    signingConfigs {
        release {
            storeFile file("../../signing/release.keystore")
            storePassword "pocketledger"
            keyAlias "pocket"
            keyPassword "pocketledger"
        }
    }
    buildTypes {"""
if os.path.exists(kts):
    t = open(kts).read()
    if 'signing/release.keystore' not in t:
        t = t.replace('    buildTypes {', CFG_KTS, 1)
        t = t.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        open(kts, 'w').write(t)
if os.path.exists(gr):
    t = open(gr).read()
    if 'signing/release.keystore' not in t:
        t = t.replace('    buildTypes {', CFG_GR, 1)
        t = t.replace('signingConfigs.debug', 'signingConfigs.release')
        open(gr, 'w').write(t)
PY

# Newer plugins (e.g. flutter_plugin_android_lifecycle) need compileSdk 36; force it for every Android library + the app.
python3 - <<'PY'
import os
KTS = """subprojects {
    if (project.name != "app") {
        afterEvaluate {
            val ext = project.extensions.findByName("android")
            if (ext is com.android.build.gradle.BaseExtension) {
                ext.compileSdkVersion(36)
            }
        }
    }
}

"""
GROOVY = """subprojects {
    if (project.name != 'app') {
        afterEvaluate { p ->
            if (p.hasProperty('android')) {
                p.android.compileSdkVersion 36
            }
        }
    }
}

"""
for f, block in (('android/build.gradle.kts', KTS), ('android/build.gradle', GROOVY)):
    if os.path.exists(f):
        t = open(f).read()
        if 'compileSdkVersion(36)' not in t and 'compileSdkVersion 36' not in t:
            open(f, 'w').write(block + t)
for g in ('android/app/build.gradle.kts', 'android/app/build.gradle'):
    if os.path.exists(g):
        t = open(g).read()
        t = t.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
        t = t.replace('compileSdkVersion flutter.compileSdkVersion', 'compileSdkVersion 36')
        t = t.replace('compileSdk flutter.compileSdkVersion', 'compileSdk 36')
        open(g, 'w').write(t)
PY

flutter pub add firebase_core firebase_auth cloud_firestore
flutter pub get
flutter analyze || echo "WARNING: analyze reported issues (continuing)"
flutter test || echo "WARNING: tests failed (continuing)"

echo
echo "Setup OK. App id: $PKG"
echo "Run on a phone: flutter run. Then long-press the home screen > Widgets > Pocket Ledger."
echo "Accounts & sync: run the Firebase steps in PLAY_STORE_GUIDE.md (section 2). Until then the app works without accounts."
echo "Next: follow PLAY_STORE_GUIDE.md (signing + build + upload)."
