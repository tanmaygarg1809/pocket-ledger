// Your Firebase project's settings. Fill these four values in from the
// google-services.json file of your Firebase Android app (see FIREBASE_SETUP.md):
//   apiKey          -> client[0].api_key[0].current_key
//   appId           -> client[0].client_info.mobilesdk_app_id
//   projectId       -> project_info.project_id
//   messagingSenderId -> project_info.project_number
// Until they are filled in, the app works normally but without accounts / sync.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const String apiKey = '';
  static const String appId = '';
  static const String projectId = '';
  static const String messagingSenderId = '';

  static FirebaseOptions get currentPlatform {
    if (apiKey.isEmpty || appId.isEmpty || projectId.isEmpty) {
      throw UnsupportedError('Firebase is not configured yet. See FIREBASE_SETUP.md');
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
    );
  }
}
