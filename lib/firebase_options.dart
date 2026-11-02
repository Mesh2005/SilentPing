import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'Cloud connection is configured for Android and web.',
    );
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyCbvR6fW0HibbUjTyIbc8aGrn4twk9W1gI',
    appId: '1:842167862336:web:71700ef9607328facccba5',
    messagingSenderId: '842167862336',
    projectId: 'silentping-app',
    authDomain: 'silentping-app.firebaseapp.com',
    storageBucket: 'silentping-app.firebasestorage.app',
  );
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAp33KokHBlPYMkMY9HK-bhEg_R46aN0JY',
    appId: '1:842167862336:android:be0fde50c3378d86cccba5',
    messagingSenderId: '842167862336',
    projectId: 'silentping-app',
    storageBucket: 'silentping-app.firebasestorage.app',
  );
}
