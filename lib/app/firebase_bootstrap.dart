import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/services/firebase_messaging_service.dart';
import '../core/services/notification_service.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static Future<void> initialize() async {
    await NotificationService().initialize();
    await FirebaseMessagingService().initialize();
    FirebaseMessaging.onBackgroundMessage(FirebaseMessagingService.backgroundHandler);
  }
}