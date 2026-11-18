// Firebase settings for the manyhandsflutter project.
// Values come from android/app/google-services.json and ios/Runner/GoogleService-Info.plist,
// which `flutterfire configure` downloaded. To regenerate this file:
//
//   flutterfire configure --project=manyhandsflutter --platforms=android,ios
//
// These values are public by design: firestore.rules is what protects the data.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Many Hands is set up for Android and iOS only.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCYYu7OxKq0r96ZuKZbvG1g3CaYgBcQKYQ',
    appId: '1:673418348561:android:1fcd138e623dc44544c9b0',
    messagingSenderId: '673418348561',
    projectId: 'manyhandsflutter',
    storageBucket: 'manyhandsflutter.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD5JDOnDrJuF2Vg6wK2G4BXkHCWtByvDak',
    appId: '1:673418348561:ios:95b15d3fc9ede2e044c9b0',
    messagingSenderId: '673418348561',
    projectId: 'manyhandsflutter',
    storageBucket: 'manyhandsflutter.firebasestorage.app',
    iosBundleId: 'com.manyhands.manyHands',
  );
}
