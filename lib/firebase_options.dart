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
    return FirebaseOptions(
      apiKey: dotenv.env['NEXT_PUBLIC_FIREBASE_API_KEY'] ?? '',
      appId: dotenv.env['NEXT_PUBLIC_FIREBASE_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['NEXT_PUBLIC_FIREBASE_PROJECT_ID'] ?? '',
      storageBucket: dotenv.env['NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET'],
      authDomain: dotenv.env['NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN'],
    );
  }
}
