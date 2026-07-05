import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

class PortalLoginRequest {
  final String id;
  final String code;
  final String status;
  final String phoneNumber;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String userAgent;

  const PortalLoginRequest({
    required this.id,
    required this.code,
    required this.status,
    required this.phoneNumber,
    required this.createdAt,
    required this.expiresAt,
    required this.userAgent,
  });

  factory PortalLoginRequest.fromJson(Map<String, dynamic> json) {
    return PortalLoginRequest(
      id: (json['id'] as String?) ?? '',
      code: (json['code'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      phoneNumber: (json['requested_phone_number'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? ''),
      userAgent: (json['user_agent'] as String?) ?? '',
    );
  }
}

class PortalAccessStatus {
  final bool registered;
  final bool locked;
  final bool renewalRequired;
  final int deviceCount;

  const PortalAccessStatus({
    required this.registered,
    required this.locked,
    required this.renewalRequired,
    required this.deviceCount,
  });

  factory PortalAccessStatus.fromJson(Map<String, dynamic> json) {
    return PortalAccessStatus(
      registered: json['registered'] == true,
      locked: json['locked'] == true,
      renewalRequired: json['renewal_required'] == true || json['error'] == 'portal_registration_renewal_required',
      deviceCount: (json['device_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  AuthService._internal();

  bool isSignedIn() => hasValidPlatformSession();

  Future<void> signOut() async {
    _clearCachedAuth();
  }

  void _clearCachedAuth() {
    SharedPreferencesUtil().authToken = '';
    SharedPreferencesUtil().tokenExpirationTime = 0;
  }

  void applyRegistrationRenewalHold() {
    final preferences = SharedPreferencesUtil();
    preferences.splatIRegistrationRenewalRequired = true;
    preferences.authToken = '';
    preferences.tokenExpirationTime = 0;
    preferences.uid = '';
    preferences.onboardingCompleted = false;
    preferences.permissionsCompleted = false;
    preferences.aiConsentGiven = false;
    preferences.hasSetPrimaryLanguage = false;
    preferences.hasSpeakerProfile = false;
  }

  Future<String?> getPlatformToken() async {
    if (hasValidPlatformSession()) {
      Logger.debug('getPlatformToken: using cached platform session token');
      return SharedPreferencesUtil().authToken;
    }
    Logger.debug('getPlatformToken: no valid platform session is cached');
    _clearCachedAuth();
    return null;
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

  Future<bool> enforceRegistrationRenewalIfRequired() async {
    OmiAuthDeviceIdentity identity;
    try {
      identity = await getOmiAuthDeviceIdentity();
    } catch (e) {
      Logger.debug('Portal renewal preflight identity lookup failed: $e');
      final cachedPhoneNumber = SharedPreferencesUtil().splatIAccountPhoneNumber;
      if (cachedPhoneNumber.isEmpty) return SharedPreferencesUtil().splatIRegistrationRenewalRequired;
      identity = OmiAuthDeviceIdentity(
        phoneNumber: cachedPhoneNumber,
        deviceIdentifier: '',
        deviceIdentifierType: 'device',
      );
    }

    final phoneNumber = identity.phoneNumber.trim();
    if (phoneNumber.isEmpty) return SharedPreferencesUtil().splatIRegistrationRenewalRequired;
    SharedPreferencesUtil().splatIAccountPhoneNumber = phoneNumber;

    final status = await getPortalAccessStatus(identity: identity);
    if (status?.renewalRequired == true) {
      Logger.debug('Portal renewal preflight: renewal is required; clearing cached app session');
      applyRegistrationRenewalHold();
      return true;
    }
    return SharedPreferencesUtil().splatIRegistrationRenewalRequired;
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
    SharedPreferencesUtil().splatIAccountPhoneNumber = normalizedPhone;

    final legacyClaimed = await _claimLegacyAccountCode(
      identity: identity,
      normalizedPhone: normalizedPhone,
      deviceIdentifier: deviceIdentifier,
      normalizedCode: normalizedCode,
    );
    if (legacyClaimed) return true;

    Logger.debug('Account-code claim did not complete; trying portal-pairing approval fallback');
    return approvePortalPairingCode(identity: identity, pairingCode: normalizedCode);
  }

  Future<bool> _claimLegacyAccountCode({
    required OmiAuthDeviceIdentity identity,
    required String normalizedPhone,
    required String deviceIdentifier,
    required String normalizedCode,
  }) async {
    final baseUrl = const String.fromEnvironment(
      'SPLATI_AUTH_BASE_URL',
      defaultValue: 'http://omi-auth-staging.gtgb.io',
    ).replaceFirst(RegExp(r'/+$'), '');
    const claimPath = String.fromEnvironment(
      'SPLATI_AUTH_CLAIM_PATH',
      defaultValue: '/api/account-codes/claim/',
    );
    final normalizedClaimPath = claimPath.startsWith('/') ? claimPath : '/$claimPath';

    late final http.Response response;
    try {
      response = await http.post(
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
    } catch (e) {
      Logger.debug('Account-code claim request failed: $e');
      return false;
    }

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

    _storePlatformSession(body: body, token: platformToken);
    final portalAccessStatus = await registerPortalAccess(identity: identity);
    if (portalAccessStatus?.renewalRequired == true) {
      applyRegistrationRenewalHold();
      return false;
    }
    SharedPreferencesUtil().splatIRegistrationRenewalRequired = false;
    return true;
  }

  Future<bool> approvePortalPairingCode({
    required OmiAuthDeviceIdentity identity,
    required String pairingCode,
  }) async {
    return decidePortalPairingCode(identity: identity, pairingCode: pairingCode, approve: true);
  }

  Future<List<PortalLoginRequest>> getPendingPortalLoginRequests({
    required OmiAuthDeviceIdentity identity,
  }) async {
    final phoneNumber = identity.phoneNumber.trim();
    if (phoneNumber.isEmpty) return [];
    SharedPreferencesUtil().splatIAccountPhoneNumber = phoneNumber;

    final baseUrl = (Env.apiBaseUrl ?? Env.defaultSplatIApiBaseUrl).replaceFirst(RegExp(r'/+$'), '');
    final query = {
      'phoneNumber': phoneNumber,
      'status': 'pending',
      'deviceIdentifier': identity.deviceIdentifier,
      'deviceIdentifierType': identity.deviceIdentifierType,
      'deviceName': defaultTargetPlatform.name,
    };
    final response = await http.get(
      Uri.parse('$baseUrl/v1/portal-pairing').replace(queryParameters: query),
      headers: {'Content-Type': 'application/json'},
    );

    Logger.debug('Portal pairing pending request response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      Logger.debug('Portal pairing pending request failed: ${response.body}');
      return [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final requests = (body['requests'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PortalLoginRequest.fromJson)
        .where((request) => request.id.isNotEmpty)
        .toList();
    return requests;
  }

  Future<PortalAccessStatus?> getPortalAccessStatus({
    required OmiAuthDeviceIdentity identity,
  }) async {
    final phoneNumber = identity.phoneNumber.trim();
    if (phoneNumber.isEmpty) return null;

    final baseUrl = (Env.apiBaseUrl ?? Env.defaultSplatIApiBaseUrl).replaceFirst(RegExp(r'/+$'), '');
    final query = {
      'phoneNumber': phoneNumber,
      if (identity.deviceIdentifier.trim().isNotEmpty) 'deviceIdentifier': identity.deviceIdentifier,
      if (identity.deviceIdentifierType.trim().isNotEmpty) 'deviceIdentifierType': identity.deviceIdentifierType,
      'deviceName': defaultTargetPlatform.name,
    };
    final response = await http.get(
      Uri.parse('$baseUrl/v1/portal-access').replace(queryParameters: query),
      headers: {'Content-Type': 'application/json'},
    );

    Logger.debug('Portal access status response: ${response.statusCode}');
    if (response.statusCode != 200) {
      Logger.debug('Portal access status failed: ${response.body}');
      try {
        return PortalAccessStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }

    return PortalAccessStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PortalAccessStatus?> registerPortalAccess({
    required OmiAuthDeviceIdentity identity,
  }) async {
    if (!identity.isComplete) return null;
    SharedPreferencesUtil().splatIAccountPhoneNumber = identity.phoneNumber.trim();

    final baseUrl = (Env.apiBaseUrl ?? Env.defaultSplatIApiBaseUrl).replaceFirst(RegExp(r'/+$'), '');
    final response = await http.post(
      Uri.parse('$baseUrl/v1/portal-access'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phoneNumber': identity.phoneNumber,
        'phone_number': identity.phoneNumber,
        'deviceIdentifier': identity.deviceIdentifier,
        'device_identifier': identity.deviceIdentifier,
        'deviceIdentifierType': identity.deviceIdentifierType,
        'device_identifier_type': identity.deviceIdentifierType,
        'deviceName': defaultTargetPlatform.name,
      }),
    );

    Logger.debug('Portal access registration response: ${response.statusCode}');
    if (response.statusCode != 200) {
      Logger.debug('Portal access registration failed: ${response.body}');
      try {
        return PortalAccessStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }

    return PortalAccessStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PortalAccessStatus?> setPortalAccessLocked({
    required OmiAuthDeviceIdentity identity,
    required bool locked,
  }) async {
    if (!identity.isComplete) return null;

    final baseUrl = (Env.apiBaseUrl ?? Env.defaultSplatIApiBaseUrl).replaceFirst(RegExp(r'/+$'), '');
    final response = await http.post(
      Uri.parse('$baseUrl/v1/portal-access'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': locked ? 'lock' : 'unlock',
        'phoneNumber': identity.phoneNumber,
        'phone_number': identity.phoneNumber,
        'deviceIdentifier': identity.deviceIdentifier,
        'device_identifier': identity.deviceIdentifier,
        'deviceIdentifierType': identity.deviceIdentifierType,
        'device_identifier_type': identity.deviceIdentifierType,
        'deviceName': defaultTargetPlatform.name,
      }),
    );

    Logger.debug('Portal access lock response: ${response.statusCode}');
    if (response.statusCode != 200) {
      Logger.debug('Portal access lock update failed: ${response.body}');
      return null;
    }

    return PortalAccessStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<bool> declinePortalPairingCode({
    required OmiAuthDeviceIdentity identity,
    required String pairingCode,
  }) async {
    return decidePortalPairingCode(identity: identity, pairingCode: pairingCode, approve: false);
  }

  Future<bool> decidePortalPairingCode({
    required OmiAuthDeviceIdentity identity,
    required String pairingCode,
    required bool approve,
  }) async {
    final normalizedCode = pairingCode.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
    if (normalizedCode.isEmpty || !identity.isComplete) {
      return false;
    }
    SharedPreferencesUtil().splatIAccountPhoneNumber = identity.phoneNumber.trim();

    final baseUrl = (Env.apiBaseUrl ?? Env.defaultSplatIApiBaseUrl).replaceFirst(RegExp(r'/+$'), '');
    final response = await http.post(
      Uri.parse('$baseUrl/v1/portal-pairing/${Uri.encodeComponent(normalizedCode)}/${approve ? 'approve' : 'decline'}'),
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

    Logger.debug('Portal pairing decision response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      Logger.debug('Portal pairing decision failed: ${response.body}');
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (PortalAccessStatus.fromJson(body).renewalRequired) {
          applyRegistrationRenewalHold();
        }
      } catch (_) {}
      return false;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (!approve) return body['status'] == 'declined';
    if (body['status'] != 'approved') return false;

    final portalToken = (body['portalToken'] as String?) ?? (body['portal_token'] as String?) ?? '';
    if (portalToken.isEmpty) {
      Logger.debug('Portal pairing approved without a portal token');
      return false;
    }

    _storePlatformSession(body: body, token: portalToken);
    SharedPreferencesUtil().splatIRegistrationRenewalRequired = false;
    return true;
  }

  void _storePlatformSession({
    required Map<String, dynamic> body,
    required String token,
  }) {
    final expiresAt = _parsePlatformTokenExpiry(body);
    SharedPreferencesUtil().authToken = token;
    SharedPreferencesUtil().tokenExpirationTime = expiresAt.millisecondsSinceEpoch;
    SharedPreferencesUtil().uid =
        (body['uid'] as String?) ?? (body['account_id'] as String?) ?? SharedPreferencesUtil().uid;
    SharedPreferencesUtil().email = '';
    final displayName = (body['displayName'] as String?) ?? '';
    if (displayName.isNotEmpty) {
      final parts = displayName.trim().split(RegExp(r'\s+'));
      SharedPreferencesUtil().givenName = parts.first;
      SharedPreferencesUtil().familyName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
  }

  DateTime _parsePlatformTokenExpiry(Map<String, dynamic> body) {
    final expiresAt = (body['expiresAt'] as String?) ??
        (body['portalTokenExpiresAt'] as String?) ??
        (body['portal_token_expires_at'] as String?);
    final parsedExpiresAt = expiresAt == null ? null : DateTime.tryParse(expiresAt);
    if (parsedExpiresAt != null) return parsedExpiresAt;

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

  Future<void> restoreProfileState() async {
    try {
      await refreshEditableUserProfilePreferences();
    } catch (e) {
      Logger.debug('DEBUG restoreProfileState: error=$e');
    }
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
      SharedPreferencesUtil().givenName = fullName.split(' ')[0];
      if (fullName.split(' ').length > 1) {
        SharedPreferencesUtil().familyName = fullName.split(' ').sublist(1).join(' ');
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
