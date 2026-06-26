import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseMessagingService {
  FirebaseMessagingService() : _messaging = FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true, provisional: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  Stream<RemoteMessage> watchForegroundMessages() {
    return FirebaseMessaging.onMessage;
  }

  static Future<void> backgroundHandler(RemoteMessage message) async {
    return;
  }
}
