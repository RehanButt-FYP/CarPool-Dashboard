import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAnVsKpJfNwZdYXBgLzbImYZWGkeRV87lY',
    appId: '1:138983938126:android:c8e67b9a7eec8caa684b1f',
    messagingSenderId: '138983938126',
    projectId: 'carpool-61334',
    storageBucket: 'carpool-61334.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDYlWJYlGloFVbJ4GJ8AI_kBdKpc324Wrk',
    appId: '1:138983938126:ios:e3928899e0ecce96684b1f',
    messagingSenderId: '138983938126',
    projectId: 'carpool-61334',
    storageBucket: 'carpool-61334.firebasestorage.app',
    iosBundleId: 'com.carpoolingpk.carpool.dashboard',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAnVsKpJfNwZdYXBgLzbImYZWGkeRV87lY',
    appId: '1:138983938126:android:c8e67b9a7eec8caa684b1f',
    messagingSenderId: '138983938126',
    projectId: 'carpool-61334',
    storageBucket: 'carpool-61334.firebasestorage.app',
  );
}
