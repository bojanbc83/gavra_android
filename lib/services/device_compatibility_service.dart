/// 📱 DEVICE COMPATIBILITY SERVICE
/// Koristi standardni Firebase FCM za sve Android telefone
class DeviceCompatibilityService {
  /// Proveri koji notification sistem koristiti - uvek Firebase FCM
  static Future<NotificationSystem> getNotificationSystem() async {
    // Koristi standardni Firebase FCM za sve Android telefone
    return NotificationSystem.fcm;
  }
}

enum NotificationSystem {
  fcm, // Standard Firebase FCM za sve telefone
}
