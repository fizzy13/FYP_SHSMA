import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are only supported on web.\n'
      'For other platforms, configure Firebase separately or use platform-specific files.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDNAY5wM3FBGgLQo0yafyAs7XwxIVDpZNk',
    authDomain: 'shsma-db2b4.firebaseapp.com',
    projectId: 'shsma-db2b4',
    storageBucket: 'shsma-db2b4.firebasestorage.app',
    messagingSenderId: '1056016918200',
    appId: '1:1056016918200:web:bd162415a4cd7f5321364d',
    measurementId: 'G-XJSM32YEWJ',
  );
}
