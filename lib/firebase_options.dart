// File generated manually based on Firebase MCP configuration
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBAR7kjLghzoU-hERmbtuXhuHfunFSOJdw',
    appId: '1:46162926481:web:4b67b999d3191caf269830',
    messagingSenderId: '46162926481',
    projectId: 'gozai-app',
    authDomain: 'gozai-app.firebaseapp.com',
    storageBucket: 'gozai-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCJ0GOYn0O1v759yv9k61hKGamA-S65uvs',
    appId: '1:46162926481:android:e01f0128fa4f0388269830',
    messagingSenderId: '46162926481',
    projectId: 'gozai-app',
    storageBucket: 'gozai-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBOcoHymgIvoBkDs6CHMYYNktGwdOkw5dM',
    appId: '1:46162926481:ios:5842a62c143be9df269830',
    messagingSenderId: '46162926481',
    projectId: 'gozai-app',
    storageBucket: 'gozai-app.firebasestorage.app',
    iosBundleId: 'com.gozai.gozai',
  );
}
