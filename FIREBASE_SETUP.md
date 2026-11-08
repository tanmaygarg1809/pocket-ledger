# Turning on accounts and sync (about 10 minutes, works from a phone browser)

1. Go to https://console.firebase.google.com and sign in with your Google account.
2. **Create a project** (name it Pocket Ledger). Google Analytics can be off.
3. **Add an Android app** (the Android icon on the project home page).
   - Android package name: `com.pocketledger.app.pocket_ledger`
   - Nickname: Pocket Ledger. Skip the SHA-1 box.
   - Tap **Register app**, then **Download google-services.json**.
4. **Authentication** (left menu, Build): Get started, **Email/Password**, switch it on, Save.
5. **Firestore Database** (Build): Create database, choose a location near you (for example
   `europe-west2` London), **Production mode**.
   - Open the **Rules** tab, replace everything with the contents of `firestore.rules`, and **Publish**.
6. Open the downloaded `google-services.json` and send its contents to Claude, who fills in
   `lib/firebase_options.dart` and builds the app. (These values identify your project; they are
   not passwords. The rules above stop anyone else reading your data.)
