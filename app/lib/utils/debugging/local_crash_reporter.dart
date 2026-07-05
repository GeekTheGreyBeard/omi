import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:omi/utils/debug_log_manager.dart';
import 'package:omi/utils/debugging/crash_reporter.dart';
import 'package:omi/utils/logger.dart';
import 'package:omi/utils/platform/platform_service.dart';

class LocalCrashReporter implements CrashReporter {
  static final LocalCrashReporter _instance = LocalCrashReporter._internal();
  static LocalCrashReporter get instance => _instance;

  LocalCrashReporter._internal();

  factory LocalCrashReporter() {
    return _instance;
  }

  static Future<void> init() async {
    Logger.debug('Crash reporting initialized with local debug logging');
  }

  @override
  void identifyUser(String email, String name, String userId) {
    PlatformService.executeIfSupported(true, () async {
      if (kDebugMode) Logger.debug('Crash reporter user context set for $userId');
    });
  }

  @override
  void logInfo(String message) {
    PlatformService.executeIfSupported(true, () => DebugLogManager.logInfo(message));
  }

  @override
  void logError(String message) {
    PlatformService.executeIfSupported(true, () => DebugLogManager.logError(message));
  }

  @override
  void logWarn(String message) {
    PlatformService.executeIfSupported(true, () => DebugLogManager.logWarning(message));
  }

  @override
  void logDebug(String message) {
    PlatformService.executeIfSupported(true, () => DebugLogManager.logInfo(message));
  }

  @override
  void logVerbose(String message) {
    PlatformService.executeIfSupported(true, () => DebugLogManager.logInfo(message));
  }

  @override
  void setUserAttribute(String key, String value) {
    PlatformService.executeIfSupported(true, () {
      if (kDebugMode) Logger.debug('Crash reporter attribute $key set');
    });
  }

  @override
  void setEnabled(bool isEnabled) {}

  @override
  Future<void> reportCrash(Object exception, StackTrace stackTrace, {Map<String, String>? userAttributes}) async {
    await PlatformService.executeIfSupportedAsync(true, () async {
      DebugLogManager.logError(exception, stackTrace, userAttributes?.toString());
    });
  }

  @override
  NavigatorObserver? getNavigatorObserver() {
    return null;
  }

  @override
  bool get isSupported => true;
}
