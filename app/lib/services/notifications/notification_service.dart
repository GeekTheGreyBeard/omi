// Platform-aware notification service.
// Remote push delivery is intentionally disabled for the Splat-I platform build
// until the platform-owned notification contract replaces the legacy provider.

import 'package:omi/services/notifications/notification_interface.dart';
import 'package:omi/services/notifications/notification_service_basic.dart' as basic;

/// Factory function to create the notification service
NotificationInterface _createPlatformNotificationService() {
  return basic.createNotificationService();
}

/// Singleton notification service instance
/// Automatically selects the correct platform-specific implementation
class NotificationService {
  static NotificationInterface? _instance;

  /// Get the singleton notification service instance
  static NotificationInterface get instance {
    _instance ??= _createPlatformNotificationService();
    return _instance!;
  }

  /// Clear the instance (useful for testing)
  static void reset() {
    _instance = null;
  }
}
