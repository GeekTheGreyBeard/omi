import 'package:url_launcher/url_launcher.dart';

import 'package:omi/backend/http/api/apps.dart' as apps_api;
import 'package:omi/backend/preferences.dart';
import 'package:omi/providers/base_provider.dart';
import 'package:omi/services/auth_service.dart';
import 'package:omi/utils/alerts/app_snackbar.dart';
import 'package:omi/utils/logger.dart';
import 'package:omi/utils/platform/platform_manager.dart';

class AuthenticationProvider extends BaseProvider {
  String? authToken;
  bool _loading = false;
  @override
  bool get loading => _loading;

  AuthenticationProvider() {
    Future.microtask(() async {
      authToken = await AuthService.instance.getPlatformToken();
      if (authToken != null) {
        await AuthService.instance.restoreProfileState();
      }
      Logger.debug('AuthProvider initialized with platform session=${authToken != null}');
      notifyListeners();
    });
  }

  bool isSignedIn() {
    return AuthService.instance.hasValidPlatformSession();
  }

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<void> onAccountCodeSubmit({
    required OmiAuthDeviceIdentity identity,
    required String accountCode,
    required Function() onSignIn,
  }) async {
    if (loading) return;
    setLoadingState(true);
    try {
      final paired = await AuthService.instance.claimAccountCode(
        identity: identity,
        accountCode: accountCode,
      );
      if (paired) {
        authToken = SharedPreferencesUtil().authToken;
        PlatformManager.instance.analytics.identify();
        onSignIn();
      } else {
        AppSnackbar.showSnackbarError('Registration failed. Check the phone number and code, then try again.');
      }
    } catch (e, stackTrace) {
      Logger.debug('Account-code pairing error: $e');
      PlatformManager.instance.crashReporter.reportCrash(e, stackTrace);
      AppSnackbar.showSnackbarError('Registration failed. Check the phone number and code, then try again.');
    } finally {
      setLoadingState(false);
    }
  }

  void openTermsOfService() {
    _launchUrl('https://www.omi.me/pages/terms-of-service');
  }

  void openPrivacyPolicy() {
    _launchUrl('https://www.omi.me/pages/privacy');
  }

  void _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      Logger.debug('Invalid URL');
      return;
    }

    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  Future<bool> migrateAppOwnerId(String oldId) async {
    return await apps_api.migrateAppOwnerId(oldId);
  }
}
