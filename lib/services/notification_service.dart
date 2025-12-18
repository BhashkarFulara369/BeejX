import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. Request Permission (Critical for Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // 2. Subscribe to "schemes" topic
    // This allows sending ONE message to ALL users who are subscribed.
    await _fcm.subscribeToTopic('schemes');
    debugPrint("Subscribed to 'schemes' topic");

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        // Optionally show a local dialog or snackbar here
      }
    });
    
    // 4. Handle Background/Terminated Tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      // Navigate to Schemes Screen if needed
    });
  }

  // Get Token (For testing single device)
  Future<String?> getToken() async {
    return await _fcm.getToken();
  }
}
