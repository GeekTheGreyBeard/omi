import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:omi/backend/http/api/apps.dart' as apps_api;
import 'package:omi/backend/preferences.dart';
import 'package:omi/providers/base_provider.dart';
import 'package:omi/services/auth_service.dart';
import 'package:omi/utils/alerts/app_snackbar.dart';
import 'package:omi/utils/logger.dart';
import 'package:omi/utils/platform/platform_manager.dart';

class AuthenticationProvider extends BaseProvider {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  User? user;
  String? authToken;
  bool _loading = false;
  @override
  bool get loading => _loading;

  AuthenticationProvider() {
    _initializeAuthListeners();
  }

  void _initializeAuthListeners() {
    // DEBUG: Log initial state
    Logger.debug(
      'DEBUG AuthProvider: Initial currentUser=${_auth.currentUser?.uid}, isAnonymous=${_auth.currentUser?.isAnonymous}',
    );

    Future.microtask(() {
      _auth.authStateChanges().distinct((p, n) => p?.uid == n?.uid).listen((User? user) {
        Logger.debug(
          'DEBUG AuthProvider: authStateChanges fired - user=${user?.uid}, isAnonymous=${user?.isAnonymous}',
        );
        this.user = user;
        // Only update SharedPreferences if Firebase has a user
        // Don't clear cached credentials - allows fallback for dev builds
        if (user != null) {
          SharedPreferencesUtil().uid = user.uid;
          SharedPreferencesUtil().email = user.email ?? '';
          SharedPreferencesUtil().givenName = user.displayName?.split(' ')[0] ?? '';
        }
      });
      _auth.idTokenChanges().distinct((p, n) => p?.uid == n?.uid).listen((User? user) async {
        if (user == null) {
          Logger.debug('User is currently signed out or the token has been revoked!');
          if (AuthService.instance.hasValidPlatformSession()) {
            authToken = SharedPreferencesUtil().authToken;
          } else {
            SharedPreferencesUtil().authToken = '';
            SharedPreferencesUtil().tokenExpirationTime = 0;
            authToken = null;
          }
        } else {
          Logger.debug('User is signed in at ${DateTime.now()} with user ${user.uid}');
          try {
            if (SharedPreferencesUtil().authToken.isEmpty ||
                DateTime.now().millisecondsSinceEpoch > SharedPreferencesUtil().tokenExpirationTime) {
              authToken = await AuthService.instance.getIdToken();
            }
          } catch (e) {
            authToken = null;
            Logger.debug('Failed to get token: $e');
          }
        }
        notifyListeners();
      });
    });
  }

  bool isSignedIn() {
    return (_auth.currentUser != null && !_auth.currentUser!.isAnonymous) ||
        AuthService.instance.hasValidPlatformSession();
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
