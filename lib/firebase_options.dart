import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    String? getEnv(String key) {
      if (dotenv.isInitialized) {
        return dotenv.env[key];
      }
      return null;
    }

    return FirebaseOptions(
      apiKey: getEnv('NEXT_PUBLIC_FIREBASE_API_KEY') ?? 'AIzaSyCUvhADzPjS1hI-n0vgYOjUk8K-dcjG5Wc',
      appId: getEnv('NEXT_PUBLIC_FIREBASE_APP_ID') ?? '1:1018683728162:web:7b0a0a927ca0b6a614057b',
      messagingSenderId: getEnv('NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID') ?? '1018683728162',
      projectId: getEnv('NEXT_PUBLIC_FIREBASE_PROJECT_ID') ?? 'borneo-hackhathon-richi',
      storageBucket: getEnv('NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET') ?? 'borneo-hackhathon-richi.firebasestorage.app',
      authDomain: getEnv('NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN') ?? 'borneo-hackhathon-richi.firebaseapp.com',
    );
  }
}
