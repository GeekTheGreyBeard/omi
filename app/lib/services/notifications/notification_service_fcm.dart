import 'package:omi/services/notifications/notification_interface.dart';
import 'package:omi/services/notifications/notification_service_basic.dart' as basic;

/// Compatibility shim for legacy imports.
///
/// Remote push delivery is no longer backed by the previous provider in the
/// Splat-I platform build. Local notifications remain available while the
/// platform-owned login request delivery contract is wired in.
NotificationInterface createNotificationService() => basic.createNotificationService();
