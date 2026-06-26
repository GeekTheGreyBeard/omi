import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import 'package:omi/backend/http/api/users.dart';
import 'package:omi/backend/preferences.dart';
import 'package:omi/env/env.dart';
import 'package:omi/utils/logger.dart';

class OmiAuthDeviceIdentity {
  final String phoneNumber;
  final String deviceIdentifier;
  final String deviceIdentifierType;

  const OmiAuthDeviceIdentity({
    required this.phoneNumber,
    required this.deviceIdentifier,
    required this.deviceIdentifierType,
  });

  bool get isComplete => phoneNumber.trim().isNotEmpty && deviceIdentifier.trim().isNotEmpty;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  AuthService._internal();

  bool isSignedIn() =>
      FirebaseAuth.instance.currentUser != null && !FirebaseAuth.instance.currentUser!.isAnonymous ||
      hasValidPlatformSession();

  getFirebaseUser() {
    return FirebaseAuth.instance.currentUser;
  }

  Future<void> signOut() async {
    _clearCachedAuth();
    await FirebaseAuth.instance.signOut();
  }

  void _clearCachedAuth() {
    SharedPreferencesUtil().authToken = '';
    SharedPreferencesUtil().tokenExpirationTime = 0;
  }

  Future<String?> getIdToken() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        if (hasValidPlatformSession()) {
          Logger.debug('getIdToken: using cached platform session token');
          return SharedPreferencesUtil().authToken;
        }
        Logger.debug('getIdToken: currentUser is null and no platform session is cached');
        return null;
      }
      IdTokenResult? newToken = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
      if (newToken?.token != null) {
        var user = FirebaseAuth.instance.currentUser!;
        SharedPreferencesUtil().uid = user.uid;
        SharedPreferencesUtil().tokenExpirationTime = newToken?.expirationTime?.millisecondsSinceEpoch ?? 0;
        SharedPreferencesUtil().authToken = newToken?.token ?? '';
        if (SharedPreferencesUtil().email.isEmpty) {
          SharedPreferencesUtil().email = user.email ?? '';
        }

        if (SharedPreferencesUtil().givenName.isEmpty) {
          SharedPreferencesUtil().givenName = user.displayName?.split(' ')[0] ?? '';
          if ((user.displayName?.split(' ').length ?? 0) > 1) {
            SharedPreferencesUtil().familyName = user.displayName?.split(' ')[1] ?? '';
          } else {
            SharedPreferencesUtil().familyName = '';
          }
        }
        return newToken?.token;
      }
      Logger.debug('getIdToken: token refresh returned null');
      return null;
    } on FirebaseAuthException catch (e) {
      Logger.debug('getIdToken: FirebaseAuthException: ${e.code} - $e');
      if (e.code == 'user-not-found' || e.code == 'user-disabled' || e.code == 'user-token-expired') {
        _clearCachedAuth();
      }
      return null;
    } catch (e) {
      Logger.debug('getIdToken: token refresh failed (transient): $e');
      return null;
    }
  }

  bool hasValidPlatformSession() {
    final token = SharedPreferencesUtil().authToken;
    final expiresAt = SharedPreferencesUtil().tokenExpirationTime;
    if (token.isEmpty || expiresAt == 0) return false;
    return DateTime.fromMillisecondsSinceEpoch(expiresAt).isAfter(DateTime.now().add(const Duration(minutes: 5)));
  }

  static const _deviceIdentityChannel = MethodChannel('com.omi/device_identity');

  Future<OmiAuthDeviceIdentity> getOmiAuthDeviceIdentity() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.phone.request();
      final raw = await _deviceIdentityChannel.invokeMapMethod<String, String>('getAuthIdentity');
      return OmiAuthDeviceIdentity(
        phoneNumber: (raw?['phoneNumber'] ?? '').trim(),
        deviceIdentifier: (raw?['deviceIdentifier'] ?? '').trim(),
        deviceIdentifierType: (raw?['deviceIdentifierType'] ?? 'device').trim(),
      );
    }

    return const OmiAuthDeviceIdentity(phoneNumber: '', deviceIdentifier: '', deviceIdentifierType: 'unsupported');
  }

  Future<bool> claimAccountCode({
    required OmiAuthDeviceIdentity identity,
    required String accountCode,
  }) async {
    final normalizedPhone = identity.phoneNumber.trim();
    final deviceIdentifier = identity.deviceIdentifier.trim();
    final normalizedCode = accountCode.trim().toUpperCase();
    if (normalizedPhone.isEmpty || deviceIdentifier.isEmpty || normalizedCode.isEmpty) {
      return false;
    }

    final baseUrl = const String.fromEnvironment(
      'SPLATI_AUTH_BASE_URL',
      defaultValue: 'http://omi-auth-staging.gtgb.io',
    ).replaceFirst(RegExp(r'/+$'), '');
    const claimPath = String.fromEnvironment(
      'SPLATI_AUTH_CLAIM_PATH',
      defaultValue: '/api/account-codes/claim/',
    );
    final normalizedClaimPath = claimPath.startsWith('/') ? claimPath : '/$claimPath';

    final response = await http.post(
      Uri.parse('$baseUrl$normalizedClaimPath'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'code': normalizedCode,
        'phoneNumber': normalizedPhone,
        'phone_number': normalizedPhone,
        'deviceIdentifier': deviceIdentifier,
        'imei': deviceIdentifier,
        'deviceIdentifierType': identity.deviceIdentifierType,
        'phoneVerificationRequired': false,
      }),
    );

    Logger.debug('Account-code claim response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      Logger.debug('Account-code claim failed: ${response.body}');
      return false;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final platformToken = body['platformToken'] as String? ?? '';
    if (platformToken.isEmpty) {
      Logger.debug('Account-code claim succeeded without a platformToken');
      return false;
    }

    final expiresAt = _parsePlatformTokenExpiry(body);
    SharedPreferencesUtil().authToken = platformToken;
    SharedPreferencesUtil().tokenExpirationTime = expiresAt.millisecondsSinceEpoch;
    SharedPreferencesUtil().uid = (body['uid'] as String?) ?? SharedPreferencesUtil().uid;
    SharedPreferencesUtil().email = '';
    final displayName = (body['displayName'] as String?) ?? '';
    if (displayName.isNotEmpty) {
      final parts = displayName.trim().split(RegExp(r'\s+'));
      SharedPreferencesUtil().givenName = parts.first;
      SharedPreferencesUtil().familyName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    return true;
  }

  Future<bool> approvePortalPairingCode({
    required OmiAuthDeviceIdentity identity,
    required String pairingCode,
  }) async {
    final normalizedCode = pairingCode.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    if (normalizedCode.isEmpty || !identity.isComplete) {
      return false;
    }

    final baseUrl = (Env.apiBaseUrl ?? Env.defaultSplatIApiBaseUrl).replaceFirst(RegExp(r'/+$'), '');
    final response = await http.post(
      Uri.parse('$baseUrl/v1/portal-pairing/${Uri.encodeComponent(normalizedCode)}/approve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': SharedPreferencesUtil().uid.isNotEmpty ? SharedPreferencesUtil().uid : 'splati-internal-user',
        'account_id': SharedPreferencesUtil().uid.isNotEmpty ? SharedPreferencesUtil().uid : 'splati-internal-user',
        'phoneNumber': identity.phoneNumber,
        'phone_number': identity.phoneNumber,
        'deviceIdentifier': identity.deviceIdentifier,
        'device_identifier': identity.deviceIdentifier,
        'deviceIdentifierType': identity.deviceIdentifierType,
        'device_identifier_type': identity.deviceIdentifierType,
        'deviceName': defaultTargetPlatform.name,
      }),
    );

    Logger.debug('Portal pairing approval response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      Logger.debug('Portal pairing approval failed: ${response.body}');
      return false;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['status'] == 'approved';
  }

  DateTime _parsePlatformTokenExpiry(Map<String, dynamic> body) {
    final expiresAt = body['expiresAt'] as String?;
    if (expiresAt != null) {
      final parsed = DateTime.tryParse(expiresAt);
      if (parsed != null) return parsed;
    }

    final expiresInSeconds = body['expiresInSeconds'];
    if (expiresInSeconds is int) {
      return DateTime.now().add(Duration(seconds: expiresInSeconds));
    }
    if (expiresInSeconds is num) {
      return DateTime.now().add(Duration(seconds: expiresInSeconds.toInt()));
    }

    return DateTime.now().add(const Duration(hours: 24));
  }

  /// Restore onboarding state from server. Call this on app startup when using cached credentials.
  Future<void> restoreOnboardingState() async {
    return _restoreOnboardingState();
  }

  Future<void> _restoreOnboardingState() async {
    try {
      Logger.debug('DEBUG _restoreOnboardingState: fetching from server...');
      final state = await getUserOnboardingState();
      Logger.debug('DEBUG _restoreOnboardingState: got state=$state');
      if (state != null) {
        if (state['completed'] == true) {
          Logger.debug('DEBUG _restoreOnboardingState: setting onboardingCompleted=true');
          SharedPreferencesUtil().onboardingCompleted = true;
        }
        final acquisitionSource = state['acquisition_source'] as String? ?? '';
        if (acquisitionSource.isNotEmpty) {
          SharedPreferencesUtil().foundOmiSource = acquisitionSource;
        }
        // Restore language from server if not already set locally
        final serverLanguage = await getUserPrimaryLanguage();
        if (serverLanguage != null && serverLanguage.isNotEmpty) {
          SharedPreferencesUtil().userPrimaryLanguage = serverLanguage;
          SharedPreferencesUtil().hasSetPrimaryLanguage = true;
        }
        Logger.debug(
          'DEBUG _restoreOnboardingState: done, onboardingCompleted=${SharedPreferencesUtil().onboardingCompleted}',
        );
      }
    } catch (e) {
      Logger.debug('DEBUG _restoreOnboardingState: error=$e');
    }
  }

  Future<void> updateGivenName(String fullName) async {
    try {
      var user = FirebaseAuth.instance.currentUser;

      SharedPreferencesUtil().givenName = fullName.split(' ')[0];
      if (fullName.split(' ').length > 1) {
        SharedPreferencesUtil().familyName = fullName.split(' ').sublist(1).join(' ');
      }

      if (user == null) {
        Logger.debug('Firebase user is null, skipping Firebase profile update');
        return;
      }

      // Try to update Firebase profile with platform-specific handling
      try {
        Logger.debug('Attempting to update Firebase user profile...');

        if (kIsWeb) {
          Logger.debug('Web platform detected - attempting updateProfile with caution');

          // Try with a timeout to prevent hanging
          await user.updateProfile(displayName: fullName).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              Logger.debug('updateProfile timed out on web platform');
              throw TimeoutException('updateProfile timed out', const Duration(seconds: 5));
            },
          );
        } else {
          await user.updateProfile(displayName: fullName);
        }
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
      } catch (updateError) {
        Logger.debug('Firebase updateProfile failed: $updateError');
      }
    } catch (e) {
      Logger.debug('Error in updateGivenName: $e');

      // Ensure SharedPreferences are updated even if everything else fails
      try {
        SharedPreferencesUtil().givenName = fullName.split(' ')[0];
        if (fullName.split(' ').length > 1) {
          SharedPreferencesUtil().familyName = fullName.split(' ').sublist(1).join(' ');
        }
        Logger.debug('SharedPreferences updated despite error');
      } catch (prefError) {
        Logger.debug('Failed to update SharedPreferences: $prefError');
      }
    }
  }

}
