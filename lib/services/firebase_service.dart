import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart';

class FirebaseService {
  static bool _initialized = false;

  /// Whether Firebase was initialized by the app.
  static bool get initialized => _initialized;

  static Future<void> init() async {
    if (_initialized) return;
    // Initialize Firebase with the best available configuration in this order:
    // 1. Use generated `DefaultFirebaseOptions.currentPlatform` (FlutterFire CLI)
    // 2. Fall back to native resource-based init (e.g. `google-services.json`)
    // If neither is available, log clear instructions for the developer.
    try {
      // Try generated options first. This will throw UnsupportedError on
      // platforms that were not configured by the FlutterFire CLI.
      try {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
        _initialized = true;
        return;
      } on UnsupportedError catch (e) {
        // Not configured via FlutterFire for this platform — fall through.
        // ignore: avoid_print
        print('DefaultFirebaseOptions not available for this platform: $e');
      }

      // Next try platform-native initialization (reads google-services.json /
      // GoogleService-Info.plist). This works when native files are present in
      // the Android/iOS project but FlutterFire options were not generated.
      try {
        await Firebase.initializeApp();
        _initialized = true;
        return;
      } catch (e) {
        // ignore: avoid_print
        print('Firebase.initializeApp() failed: $e');
      }

      // If we reach here Firebase is not initialized. Provide a clear, actionable
      // message so developers can fix their environment.
      // ignore: avoid_print
      print(
          'Firebase was not initialized. To fix: run `flutterfire configure` or add platform Firebase config (android: google-services.json, iOS: GoogleService-Info.plist) and restart the app.');
    } catch (e) {
      // Unexpected error during init — log and continue with _initialized=false
      // ignore: avoid_print
      print('Unexpected error while initializing Firebase: $e');
    }
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;
}
