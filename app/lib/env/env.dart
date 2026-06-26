abstract class Env {
  static late final EnvFields _instance;
  static const String _apiBaseUrlFromDefine = String.fromEnvironment('API_BASE_URL');
  static const String _stagingApiUrlFromDefine = String.fromEnvironment('STAGING_API_URL');
  static const String _liveTranscriptionWsBaseUrlFromDefine = String.fromEnvironment('LIVE_TRANSCRIPTION_WS_BASE_URL');
  static String? _apiBaseUrlOverride;
  static String? _agentProxyWsUrlOverride;
  static bool isTestFlight = false;

  static void init(EnvFields instance) {
    _instance = instance;
  }

  static void overrideApiBaseUrl(String url) {
    _apiBaseUrlOverride = url;
  }

  static void overrideAgentProxyWsUrl(String url) {
    _agentProxyWsUrlOverride = url;
  }

  static String? get openAIAPIKey => _instance.openAIAPIKey;

  static String? get posthogApiKey => _instance.posthogApiKey;

  static const String defaultSplatIApiBaseUrl = 'https://omi.splat-i.io/';

  static String? get apiBaseUrl =>
      _apiBaseUrlOverride ?? _nonEmpty(_apiBaseUrlFromDefine) ?? _instance.apiBaseUrl ?? defaultSplatIApiBaseUrl;

  /// Staging API URL from STAGING_API_URL env var. Null when not configured.
  static String? get stagingApiUrl {
    final url = _nonEmpty(_stagingApiUrlFromDefine) ?? _instance.stagingApiUrl;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;

  /// Optional WebSocket base dedicated to live transcription.
  ///
  /// This lets preproduction keep REST and portal auth on the public Omi host
  /// while routing `/v4/listen` streaming to the compatibility bridge.
  static String? get liveTranscriptionWsBaseUrl => _nonEmpty(_liveTranscriptionWsBaseUrlFromDefine);

  /// Whether STAGING_API_URL is configured in the environment.
  static bool get isStagingConfigured => stagingApiUrl != null;

  static bool get isUsingStagingApi {
    final effective = apiBaseUrl;
    final staging = stagingApiUrl;
    if (effective == null || staging == null) return false;
    return _normalizeUrl(effective) == _normalizeUrl(staging);
  }

  static String _normalizeUrl(String url) {
    var s = url.trim().toLowerCase();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// WebSocket URL for the agent proxy service.
  /// Derives from apiBaseUrl and defaults to the Splat-I Omi preproduction host.
  /// Can be overridden via Env.overrideAgentProxyWsUrl() for local testing.
  static String get agentProxyWsUrl {
    if (_agentProxyWsUrlOverride != null) return _agentProxyWsUrlOverride!;
    final base = apiBaseUrl ?? defaultSplatIApiBaseUrl;
    final host = Uri.parse(base).host.replaceFirst('api.', 'agent.');
    return 'wss://$host/v1/agent/ws';
  }

  static String? get googleMapsApiKey => _instance.googleMapsApiKey;

  static String? get intercomAppId => _instance.intercomAppId;

  static String? get intercomIOSApiKey => _instance.intercomIOSApiKey;

  static String? get intercomAndroidApiKey => _instance.intercomAndroidApiKey;

  static String? get googleClientId => _instance.googleClientId;

  static String? get googleClientSecret => _instance.googleClientSecret;

  static bool get useWebAuth => _instance.useWebAuth ?? false;

  static bool get useAuthCustomToken => _instance.useAuthCustomToken ?? false;
}

abstract class EnvFields {
  String? get openAIAPIKey;

  String? get posthogApiKey;

  String? get apiBaseUrl;

  String? get googleMapsApiKey;

  String? get intercomAppId;

  String? get intercomIOSApiKey;

  String? get intercomAndroidApiKey;

  String? get googleClientId;

  String? get googleClientSecret;

  bool? get useWebAuth;

  bool? get useAuthCustomToken;

  String? get stagingApiUrl;
}
